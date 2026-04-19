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
#   - Activates both plugins via wp-cli
#   - Registers the site as a STDIO MCP server in Claude Code
#   - Idempotent: skips clone steps if plugins already present
#
# Configuration:
# - Assumes local sites live under ~/Sites/<sitename>
# - Assumes the WordPress admin user is named "admin"
# - Registers as "wordpress-<sitename>" so the wp-system-report skill auto-matches
#
# ============================================================================

# Add a Local WordPress Site to Claude Code MCP
#
# Purpose: One-command install of wp-system-report + mcp-adapter on a local
#          WordPress site, then register it as an MCP server in Claude Code.
#
# Usage: wp_mcp_add_site <site-directory-name>
#   Example: wp_mcp_add_site colacnew
#            (installs into ~/Sites/colacnew, registers as wordpress-colacnew)
#
# What it does:
# 1. Validates the site directory exists and looks like a WordPress install
# 2. Clones wp-system-report into wp-content/plugins (skipped if present)
# 3. Clones mcp-adapter into wp-content/plugins (skipped if present)
# 4. Runs composer install in mcp-adapter for its dependencies
# 5. Activates both plugins via wp-cli
# 6. Registers a STDIO MCP server entry in Claude Code as "wordpress-<sitename>"
#
# Requirements:
# - wp-cli, composer, git, and the claude command must all be on PATH
# - Site must already exist at ~/Sites/<sitename>
# - WordPress admin user must be named "admin" (edit --user= below if not)
#
# After running:
# - Restart Claude Code to pick up the new MCP server
# - Ask Claude: "health check on wordpress-<sitename>" to verify
wp_mcp_add_site() {
  local site="$1"
  if [[ -z "$site" ]]; then
    echo "Usage: wp_mcp_add_site <site-directory-name>"
    echo "Example: wp_mcp_add_site colacnew  (for ~/Sites/colacnew)"
    return 1
  fi

  local path="$HOME/Sites/$site"
  if [[ ! -d "$path/wp-content/plugins" ]]; then
    echo "Error: $path does not look like a WordPress install (no wp-content/plugins)"
    return 1
  fi

  local plugins="$path/wp-content/plugins"

  echo "[1/4] wp-system-report..."
  if [[ -d "$plugins/wp-system-report" ]]; then
    echo "      already installed, skipping clone"
  else
    git clone --quiet https://github.com/chrisfromthelc/wp-system-report.git "$plugins/wp-system-report" \
      || { echo "Error: failed to clone wp-system-report"; return 1; }
  fi

  echo "[2/4] mcp-adapter..."
  if [[ -d "$plugins/mcp-adapter" ]]; then
    echo "      already installed, skipping clone"
  else
    git clone --quiet https://github.com/WordPress/mcp-adapter.git "$plugins/mcp-adapter" \
      || { echo "Error: failed to clone mcp-adapter"; return 1; }
  fi
  ( cd "$plugins/mcp-adapter" && composer install --no-interaction --quiet ) \
    || { echo "Error: composer install failed for mcp-adapter"; return 1; }

  echo "[3/4] activating plugins..."
  wp --path="$path" plugin activate wp-system-report mcp-adapter \
    || { echo "Error: plugin activation failed"; return 1; }

  echo "[4/4] registering MCP server as wordpress-$site..."
  claude mcp add "wordpress-$site" -- wp --path="$path" mcp-adapter serve \
    --server=mcp-adapter-default-server --user=admin \
    || { echo "Error: claude mcp add failed (server may already be registered)"; return 1; }

  echo ""
  echo "Done. Restart Claude Code, then ask: 'health check on wordpress-$site'"
}
