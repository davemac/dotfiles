# WordPress MCP Integration Functions
#
# Helpers for managing WordPress sites that expose abilities to AI agents
# via the Model Context Protocol (MCP). Requires the wp-system-report and
# mcp-adapter WordPress plugins server-side, and Claude Code (or another
# MCP-capable client) on this machine.
#
# Architecture:
# - wp-system-report      - WordPress plugin: registers diagnostic abilities
# - mcp-adapter           - WordPress plugin: bridges abilities to MCP transport
# - Claude Code MCP entry - Client-side: tells Claude Code how to reach the site
#
# ============================================================================
# FUNCTION INDEX
# ============================================================================
#
# Site Management:
# - wp_mcp_add_site            - Install plugins + register MCP server for a local site
#   Features:
#   - Clones wp-system-report and mcp-adapter into a local site's plugins directory
#   - Runs composer install for mcp-adapter dependencies
#   - Activates both plugins via wp-cli (uses --network on multisite)
#   - Registers the site as a STDIO MCP server in Claude Code
#   - Multisite-aware: optional subsite-url arg registers a per-subsite entry
#   - Idempotent: skips clone steps if plugins already present
# - wp_mcp_add_remote_site     - Register a remote (prod/staging) WP site via Automattic STDIO proxy
# - wp_mcp_install_remote_plugins - SSH companion: clone + composer + activate the two MCP plugins on a remote host
# - wp_mcp_remove_site         - Unregister a wordpress-<sitename> entry from Claude Code (idempotent)
# - wp_mcp_list_sites          - List all wordpress-* MCP servers grouped by transport
#
# Configuration:
# - Assumes local sites live under ~/Sites/<sitename>
# - Assumes the WordPress admin user is named "admin"
# - Registers as "wordpress-<sitename>" so the wp-system-report skill auto-matches
#
# ============================================================================

# Internal: error out if jq is not on PATH. Shared by every function below
# that parses or builds JSON.
_wp_mcp_require_jq() {
  if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required (brew install jq)"
    return 1
  fi
}

# Internal: clone $repo into $plugins_dir/$name unless already present.
# Echoes a "skipping" line if the destination directory exists; otherwise
# performs a quiet clone and propagates git's exit status.
_wp_mcp_clone_plugin() {
  local name="$1" repo="$2" plugins_dir="$3"
  if [[ -d "$plugins_dir/$name" ]]; then
    echo "      already installed, skipping clone"
    return 0
  fi
  git clone --quiet "$repo" "$plugins_dir/$name"
}

# Internal: activate wp-system-report and mcp-adapter via wp-cli, network-wide
# on multisite. Takes the working directory to run from (needed for remote
# `wp @alias` invocations that resolve wp-cli.yml) plus the wp arguments that
# identify the target install (e.g. `--path=...` locally, `@prod` remotely).
# The caller owns the surrounding `[N/M] ...` step label.
_wp_mcp_activate_plugins() {
  local cwd="$1"
  shift
  local network_flag=""
  if ( cd "$cwd" && wp "$@" core is-installed --network 2>/dev/null ); then
    echo "      multisite detected — network-activating"
    network_flag="--network"
  fi
  ( cd "$cwd" && wp "$@" plugin activate wp-system-report mcp-adapter $network_flag )
}

# Add a Local WordPress Site to Claude Code MCP
#
# Purpose: One-command install of wp-system-report + mcp-adapter on a local
#          WordPress site, then register it as an MCP server in Claude Code.
#          Multisite-aware: detects networks and network-activates plugins;
#          can register one entry per subsite when given a subsite URL.
#
# Usage: wp_mcp_add_site <site-directory-name> [subsite-url] [server-suffix]
#
#   Single-site install:
#     wp_mcp_add_site colacnew
#       Installs into ~/Sites/colacnew, registers as wordpress-colacnew.
#
#   Multisite, expose the network's main site:
#     wp_mcp_add_site mynet
#       Network-activates plugins, registers wordpress-mynet pointing at the
#       network's main site (resolved by wp-cli from DOMAIN_CURRENT_SITE).
#
#   Multisite, expose a specific subsite (host-based subdomain):
#     wp_mcp_add_site mynet https://subsite-a.localhost
#       Registers wordpress-mynet-subsite-a with --url= baked in.
#       The suffix is auto-derived from the host's leading subdomain.
#
#   Multisite, expose a specific subsite (subdirectory) with explicit suffix:
#     wp_mcp_add_site mynet https://mynet.localhost/subdir-b/ subdir-b
#       Registers wordpress-mynet-subdir-b (auto-derivation would have collided
#       with the main site's slug, so pass an explicit third arg).
#
# What it does:
# 1. Validates the site directory exists and looks like a WordPress install
# 2. Clones wp-system-report into wp-content/plugins (skipped if present)
# 3. Clones mcp-adapter into wp-content/plugins (skipped if present)
# 4. Runs composer install in mcp-adapter for its dependencies
# 5. Activates both plugins via wp-cli (uses --network on multisite)
# 6. Registers a STDIO MCP server entry in Claude Code; on multisite with a
#    subsite URL, bakes --url=<subsite-url> into the registered command and
#    suffixes the server name to keep entries distinct
#
# Requirements:
# - wp-cli, composer, git, and the claude command must all be on PATH
# - Site must already exist at ~/Sites/<sitename>
# - WordPress admin user must be named "admin" (edit --user= below if not)
#
# After running:
# - Restart Claude Code to pick up the new MCP server
# - Ask Claude: "health check on wordpress-<sitename>" (or the suffixed name)
wp_mcp_add_site() {
  local site="$1" subsite_url="$2" suffix_override="$3"
  if [[ -z "$site" ]]; then
    echo "Usage: wp_mcp_add_site <site-directory-name> [subsite-url] [server-suffix]"
    echo ""
    echo "Examples:"
    echo "  wp_mcp_add_site colacnew                                         single-site"
    echo "  wp_mcp_add_site mynet                                            multisite, main site"
    echo "  wp_mcp_add_site mynet https://subsite-a.localhost                multisite, host-based subsite"
    echo "  wp_mcp_add_site mynet https://mynet.localhost/subdir-b/ subdir-b multisite, subdirectory subsite"
    return 1
  fi

  local path="$HOME/Sites/$site"
  local plugins="$path/wp-content/plugins"
  if [[ ! -d "$plugins" ]]; then
    echo "Error: $path does not look like a WordPress install (no wp-content/plugins)"
    return 1
  fi

  # Detect multisite by interrogating the install (not by grepping wp-config.php).
  local is_multisite=false
  if wp --path="$path" core is-installed --network 2>/dev/null; then
    is_multisite=true
  fi

  if [[ -n "$subsite_url" && "$is_multisite" == "false" ]]; then
    echo "Error: $path is not a multisite install — subsite-url cannot be used"
    return 1
  fi

  # Derive the registered server name. Default = wordpress-<site>; if a subsite
  # URL is provided, append a suffix so multiple subsites of one network can be
  # registered without collision.
  local server="wordpress-$site"
  if [[ -n "$subsite_url" ]]; then
    local subsite_slug="$suffix_override"
    if [[ -z "$subsite_slug" ]]; then
      # Strip protocol and trailing path, then take the host's leading dot-segment.
      local host="${subsite_url#*://}"
      host="${host%%/*}"
      subsite_slug="${host%%.*}"
    fi
    if [[ -z "$subsite_slug" ]]; then
      echo "Error: could not derive subsite slug from URL — pass an explicit suffix as the third arg"
      return 1
    fi
    server="wordpress-$site-$subsite_slug"
  fi

  echo "[1/4] wp-system-report..."
  _wp_mcp_clone_plugin wp-system-report https://github.com/chrisfromthelc/wp-system-report.git "$plugins" \
    || { echo "Error: failed to clone wp-system-report"; return 1; }

  echo "[2/4] mcp-adapter..."
  _wp_mcp_clone_plugin mcp-adapter https://github.com/WordPress/mcp-adapter.git "$plugins" \
    || { echo "Error: failed to clone mcp-adapter"; return 1; }
  ( cd "$plugins/mcp-adapter" && composer install --no-interaction --quiet ) \
    || { echo "Error: composer install failed for mcp-adapter"; return 1; }

  echo "[3/4] activating plugins..."
  _wp_mcp_activate_plugins "$path" --path="$path" \
    || { echo "Error: plugin activation failed"; return 1; }

  echo "[4/4] registering MCP server as $server..."
  local wp_args=( --path="$path" )
  [[ -n "$subsite_url" ]] && wp_args+=( --url="$subsite_url" )
  claude mcp add "$server" -- wp "${wp_args[@]}" mcp-adapter serve \
    --server=mcp-adapter-default-server --user=admin \
    || { echo "Error: claude mcp add failed (server may already be registered)"; return 1; }

  echo ""
  echo "Done. Restart Claude Code, then ask: 'health check on $server'"
}

# Add a Remote WordPress Site to Claude Code MCP
#
# Purpose: Register a remote (production or staging) WordPress site as an MCP
#          server in Claude Code, using the Automattic mcp-wordpress-remote
#          STDIO proxy. Unlike wp_mcp_add_site, this does NOT install plugins —
#          the remote site must already have wp-system-report and mcp-adapter
#          installed and active server-side (deploy them as part of your usual
#          mu-plugin or theme deploy).
#
# Usage: wp_mcp_add_remote_site <site-directory-name> <url> <username> <app-password>
#   Examples:
#     wp_mcp_add_remote_site myclient https://myclient.com.au admin xxxx-xxxx-xxxx-xxxx
#     wp_mcp_add_remote_site myclient https://myclient.com.au/wp-json/mcp/mcp-adapter-default-server admin xxxx
#
#   The <url> may be either:
#     - A site base URL (e.g. https://example.com.au) — the function appends
#       /wp-json/mcp/mcp-adapter-default-server
#     - A full MCP endpoint URL containing /wp-json/mcp/ — used as-is
#
# What it does:
# 1. Validates all four arguments
# 2. Builds the WP_API_URL (appends the MCP endpoint path if needed)
# 3. Constructs a JSON server config with env vars
#    (WP_API_URL, WP_API_USERNAME, WP_API_PASSWORD)
# 4. Registers via `claude mcp add-json` as wordpress-<sitename>
#
# Requirements:
# - jq, npx, and the claude command must all be on PATH
# - Remote site must have wp-system-report + mcp-adapter installed and active
# - Use a WordPress application password (Users -> Profile -> Application
#   Passwords), not the user's main login password
#
# After running:
# - Restart Claude Code to pick up the new MCP server
# - First call will trigger npx to download @automattic/mcp-wordpress-remote
# - Ask Claude: "health check on wordpress-<sitename>" to verify
wp_mcp_add_remote_site() {
  local site="$1" url="$2" username="$3" app_password="$4"

  if [[ -z "$site" || -z "$url" || -z "$username" || -z "$app_password" ]]; then
    echo "Usage: wp_mcp_add_remote_site <sitename> <url> <username> <app-password>"
    echo "Example: wp_mcp_add_remote_site myclient https://myclient.com.au admin xxxx-xxxx-xxxx-xxxx"
    return 1
  fi

  _wp_mcp_require_jq || return 1

  # Construct the MCP endpoint URL — accept either a base URL or a full endpoint.
  local api_url
  if [[ "$url" == *"/wp-json/mcp/"* ]]; then
    api_url="$url"
  else
    api_url="${url%/}/wp-json/mcp/mcp-adapter-default-server"
  fi

  echo "[1/2] building MCP server config for wordpress-$site..."
  echo "      endpoint: $api_url"
  echo "      user:     $username"
  # Password intentionally not echoed.

  local json
  json=$(jq -nc \
    --arg url "$api_url" \
    --arg user "$username" \
    --arg pass "$app_password" \
    '{
      type: "stdio",
      command: "npx",
      args: ["-y", "@automattic/mcp-wordpress-remote@latest"],
      env: {
        WP_API_URL: $url,
        WP_API_USERNAME: $user,
        WP_API_PASSWORD: $pass
      }
    }') || { echo "Error: failed to build server JSON"; return 1; }

  echo "[2/2] registering MCP server as wordpress-$site..."
  claude mcp add-json "wordpress-$site" "$json" \
    || { echo "Error: claude mcp add-json failed (server may already be registered — run wp_mcp_remove_site $site first)"; return 1; }

  echo ""
  echo "Done. Restart Claude Code, then ask: 'health check on wordpress-$site'"
}

# Install MCP Plugins on a Remote WordPress Site via SSH
#
# Purpose: Companion to wp_mcp_add_remote_site. Reads the SSH alias and remote
#          WP path from the site's wp-cli.yml (under ~/Sites/<sitename>),
#          then clones wp-system-report and mcp-adapter into the remote
#          wp-content/plugins, runs composer install for mcp-adapter
#          dependencies, and activates both plugins (network-wide on
#          multisite). Run this BEFORE wp_mcp_add_remote_site so the remote
#          endpoint actually responds.
#
# Usage: wp_mcp_install_remote_plugins <sitename> [alias]
#   Examples:
#     wp_mcp_install_remote_plugins colacnew
#         Reads ~/Sites/colacnew/wp-cli.yml, resolves @prod (default), uses
#         its ssh: and path: values to install + activate on the remote.
#     wp_mcp_install_remote_plugins colacnew @staging
#         Same, but resolves the @staging alias instead of @prod.
#
# Required wp-cli.yml shape (KnownHost / standard wp-cli aliases):
#   @prod:
#       ssh: colac-l        # SSH alias from ~/.ssh/config
#       path: www           # WP install path on the remote (relative to $HOME or absolute)
#
# What it does:
# 1. Resolves the alias by running `wp cli alias get` from the site root
# 2. Verifies the remote path looks like a WordPress install
# 3. Confirms git, composer, and wp are on the remote PATH (errors out if missing)
# 4. Clones both plugins (skipped if present) and runs composer install in mcp-adapter
# 5. Detects multisite via `wp core is-installed --network` on the remote and
#    activates accordingly (--network if multisite, else single-site activation)
#
# Requirements:
# - jq locally; ssh, git, composer, wp on the remote PATH
# - Local wp-cli.yml at ~/Sites/<sitename>/wp-cli.yml with the named alias
# - Remote shell user must have write access to wp-content/plugins
#
# Trust boundary:
# - The `path:` field from your local wp-cli.yml is interpolated into a remote
#   shell command. A malicious value (e.g. `path: $(rm -rf ~)`) would execute
#   on the remote. Safe for personal use where you author your own wp-cli.yml;
#   audit the file before running this against an unfamiliar site.
#
# After running:
# - Run wp_mcp_add_remote_site to register the site as an MCP server in Claude Code
wp_mcp_install_remote_plugins() {
  local site="$1" alias_name="${2:-@prod}"

  if [[ -z "$site" ]]; then
    echo "Usage: wp_mcp_install_remote_plugins <sitename> [alias]"
    echo ""
    echo "Examples:"
    echo "  wp_mcp_install_remote_plugins colacnew            # uses @prod from ~/Sites/colacnew/wp-cli.yml"
    echo "  wp_mcp_install_remote_plugins colacnew @staging   # uses @staging instead"
    return 1
  fi

  _wp_mcp_require_jq || return 1

  # Accept either "prod" or "@prod"; normalise to leading-@ form.
  [[ "$alias_name" != @* ]] && alias_name="@$alias_name"

  local site_path="$HOME/Sites/$site"
  if [[ ! -f "$site_path/wp-cli.yml" ]]; then
    echo "Error: $site_path/wp-cli.yml not found — cannot resolve $alias_name"
    return 1
  fi

  # wp-cli only finds wp-cli.yml when invoked from the site root, so cd in.
  local alias_json
  alias_json=$(cd "$site_path" && wp cli alias list --format=json 2>/dev/null) \
    || { echo "Error: failed to read aliases from $site_path/wp-cli.yml"; return 1; }

  # Pull both fields in a single jq call, tab-separated, and split locally.
  local ssh_alias remote_path alias_fields
  alias_fields=$(echo "$alias_json" | jq -r --arg a "$alias_name" '[.[$a].ssh // "", .[$a].path // ""] | @tsv')
  ssh_alias="${alias_fields%%	*}"
  remote_path="${alias_fields#*	}"

  if [[ -z "$ssh_alias" ]]; then
    echo "Error: $alias_name not found in $site_path/wp-cli.yml or has no 'ssh:' field"
    return 1
  fi
  if [[ -z "$remote_path" ]]; then
    echo "Error: $alias_name in $site_path/wp-cli.yml has no 'path:' field"
    return 1
  fi

  echo "[1/5] resolved $alias_name -> ssh=$ssh_alias path=$remote_path"

  echo "[2/5] verifying remote install at $ssh_alias:$remote_path..."
  if ! ssh "$ssh_alias" "test -d \"$remote_path/wp-content/plugins\"" 2>/dev/null; then
    echo "Error: $remote_path on $ssh_alias does not look like a WordPress install (no wp-content/plugins)"
    return 1
  fi

  echo "[3/5] checking remote tooling (git, composer, wp)..."
  local missing
  missing=$(ssh "$ssh_alias" 'for c in git composer wp; do command -v $c >/dev/null 2>&1 || echo $c; done' 2>/dev/null)
  if [[ -n "$missing" ]]; then
    echo "Error: missing on $ssh_alias: $(echo $missing | tr '\n' ' ')"
    echo "Install the missing tools first (composer: https://getcomposer.org/download/) and re-run."
    return 1
  fi

  local plugins="$remote_path/wp-content/plugins"

  echo "[4/5] cloning plugins + running composer install on $ssh_alias..."
  ssh "$ssh_alias" "
    clone_if_missing() {
      local name=\$1 repo=\$2 dest=\"$plugins/\$1\"
      if [[ -d \"\$dest\" ]]; then
        echo \"      \$name already installed, skipping clone\"
      else
        git clone --quiet \"\$repo\" \"\$dest\" || exit 1
        echo \"      \$name cloned\"
      fi
    }
    clone_if_missing wp-system-report https://github.com/chrisfromthelc/wp-system-report.git
    clone_if_missing mcp-adapter      https://github.com/WordPress/mcp-adapter.git
    cd \"$plugins/mcp-adapter\" && composer install --no-interaction --quiet
  " || { echo "Error: remote clone or composer install failed"; return 1; }

  echo "[5/5] activating plugins via $alias_name (wp-cli handles SSH)..."
  _wp_mcp_activate_plugins "$site_path" "$alias_name" \
    || { echo "Error: remote plugin activation failed"; return 1; }

  echo ""
  echo "Done. Now run: wp_mcp_add_remote_site $site <site-url> <username> <app-password>"
}

# Remove a WordPress Site from Claude Code MCP
#
# Purpose: Unregister a wordpress-<sitename> MCP server entry from Claude Code.
#          Does NOT delete the WordPress plugins server-side — that is left to
#          the user (run `wp plugin deactivate wp-system-report mcp-adapter`
#          if you want to disable it cleanly, or remove the plugin directories
#          manually).
#
# Usage: wp_mcp_remove_site <site-directory-name>
#   Example: wp_mcp_remove_site colacnew
#            (removes the wordpress-colacnew entry from Claude Code)
#
# What it does:
# 1. Validates the site name argument
# 2. Runs `claude mcp remove wordpress-<sitename>` (auto-detects scope)
# 3. Treats "not registered" as success (idempotent)
#
# Requirements:
# - The claude command must be on PATH
# - For project-scoped entries, run from inside the project directory so the
#   CLI can find the entry
#
# After running:
# - Restart Claude Code so it stops trying to connect to the removed server
wp_mcp_remove_site() {
  local site="$1"
  if [[ -z "$site" ]]; then
    echo "Usage: wp_mcp_remove_site <site-directory-name>"
    echo "Example: wp_mcp_remove_site colacnew  (removes wordpress-colacnew)"
    return 1
  fi

  local server="wordpress-$site"
  echo "[1/1] removing MCP server $server..."
  if claude mcp remove "$server" 2>/dev/null; then
    echo ""
    echo "Done. $server removed from Claude Code MCP config."
    echo "Restart Claude Code to drop the connection."
  else
    echo "      $server is not registered, nothing to do (idempotent)."
  fi
}

# List Registered WordPress MCP Sites
#
# Purpose: Show every wordpress-* MCP server known to Claude Code on this
#          machine, grouped by transport type. Reads ~/.claude.json directly
#          so it sees both user-scope and project-scope entries (unlike
#          `claude mcp list`, which is scoped to the current project context
#          and runs a slow per-server network health check).
#
# Usage: wp_mcp_list_sites
#
# What it does:
# 1. Reads ~/.claude.json with jq
# 2. Collects wordpress-* entries from user-scope .mcpServers and every
#    project-scope .projects[*].mcpServers
# 3. Classifies each as stdio-local (wp-cli) or http-proxy (Automattic remote)
# 4. Prints them grouped by transport with name, location (path or URL), and scope
#
# Requirements:
# - jq must be on PATH
# - ~/.claude.json must exist (Claude Code installed and configured)
#
# Output transports:
# - stdio-local : registered via wp_mcp_add_site (uses local wp-cli)
# - http-proxy  : registered via wp_mcp_add_remote_site (Automattic STDIO proxy)
wp_mcp_list_sites() {
  _wp_mcp_require_jq || return 1

  local config="$HOME/.claude.json"
  if [[ ! -f "$config" ]]; then
    echo "Error: $config not found — Claude Code may not be installed/configured"
    return 1
  fi

  local rows
  rows=$(jq -r '
    def transport(s):
      if (s.command == "npx") and ((s.args // []) | any(test("mcp-wordpress-remote")))
        then "http-proxy"
      elif s.command == "wp"
        then "stdio-local"
      else (s.type // "unknown") end;

    def location(s):
      if transport(s) == "http-proxy"
        then (s.env.WP_API_URL // "(no WP_API_URL set)")
      elif transport(s) == "stdio-local"
        then (((s.args // [])[] | select(startswith("--path="))) | sub("^--path="; ""))
      else "(unknown)" end;

    def collect(scope_label; servers):
      (servers // {}) | to_entries[]
      | select(.key | startswith("wordpress-"))
      | "\(transport(.value))\t\(.key)\t\(location(.value))\t\(scope_label)";

    [
      collect("user"; .mcpServers),
      ((.projects // {}) | to_entries[] | .key as $p | collect("project:" + $p; .value.mcpServers))
    ] | .[]
  ' "$config")

  if [[ -z "$rows" ]]; then
    echo "No wordpress-* MCP servers registered in $config."
    return 0
  fi

  echo "$rows" | sort | awk -F'\t' '
    $1 != prev {
      if (NR > 1) print ""
      printf "[%s]\n", $1
      prev = $1
    }
    {
      printf "  %s\n    location: %s\n    scope:    %s\n", $2, $3, $4
    }
  '
}
