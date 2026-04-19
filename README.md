# Dotfiles

My collection of shell functions and configuration files for WordPress development.

## Directory Structure

```
dotfiles/
├── shell/
│   ├── cloudflare.sh     # Cloudflare zone management (cf-opt, cf-check)
│   ├── config.sh         # Global configuration management
│   ├── deployment.sh      # Theme deployment (firstdeploy, depto)
│   ├── git.sh            # Git utilities and branch management
│   ├── utils.sh          # System utilities and common aliases
│   ├── wp-core.sh        # WordPress WP-CLI shortcuts and aliases
│   ├── wp-db.sh          # All database operations (pullprod, dmcweb, wp_db_optimise, etc.)
│   ├── wp-diagnostics.sh # Troubleshooting (wp_plugin_diags)
│   ├── wp-mcp.sh         # AI integration via Model Context Protocol (wp_mcp_add_site, wp_mcp_add_remote_site, wp_mcp_install_remote_plugins, wp_mcp_remove_site, wp_mcp_list_sites)
│   ├── wp-fleet.sh       # Fleet operations across registered MCP sites (wp_fleet_update, wp_fleet_db_optimise)
│   └── wp-uploads.sh     # Upload/file sync operations (getups, pushups)
├── .gitignore
└── README.md
```

## How It Works

This dotfiles system uses a **centralized configuration approach** that keeps sensitive information secure while maintaining full functionality:

### Configuration System
- **`shell/config.sh`** - Central configuration manager with safe defaults
- **`.dotfiles-config`** - Your personal settings file (git-ignored for security)
- **Automatic loading** - Functions load config when needed, no manual setup required

### Security Model
- All sensitive values (passwords, hostnames, API keys) are stored in `.dotfiles-config`
- This file is **git-ignored** so it never gets committed to the public repository
- Other users get safe defaults and can create their own personal configuration
- You keep full functionality with your actual credentials

### Loading Pattern
Each function automatically loads configuration when called:
```bash
load_dotfiles_config 2>/dev/null || true  # Safe loading pattern
```

## Installation

1. **Clone this repository:**
    ```bash
    cd ~
    git clone git@github.com:davemac/dotfiles.git
    ```

2. **Create symbolic link to your home directory:**
    ```bash
    ln -s ~/dotfiles/shell ~/.shell-functions
    ```

3. **Add loading code to your shell config** (choose your shell):

    **For zsh (~/.zshrc):**
    ```bash
    # Load shell functions (interactive features)
    for file in ~/.shell-functions/*.sh; do
        source "$file"
    done
    ```

    **For bash (~/.bashrc):**
    ```bash
    # Load shell functions
    for file in ~/.shell-functions/*.sh; do
        source "$file"
    done
    ```

4. **Reload your shell:**
    ```bash
    source ~/.zshrc  # or ~/.bashrc
    ```

5. **Create your personal configuration:**
    ```bash
    dotfiles_config --create  # Creates .dotfiles-config in repo root
    dotfiles_config --edit    # Edit your personal settings
    ```

6. **Get started:**
    ```bash
    listcmds  # View all available commands organised by category
    ```

### First-Time Setup
After installation, you'll want to customise your `.dotfiles-config` file with your actual values:
- `DEV_WP_PASSWORD` - Your preferred WordPress development password
- `SSH_PROXY_HOST` - Your SSH proxy server hostname
- `WC_HOSTS` - Your WooCommerce production server aliases
- `DEV_PLUGINS_ACTIVATE` - Plugins to activate locally after DB pull
- `PROD_PLUGINS_DEACTIVATE` - Production-only plugins to deactivate locally
- `STAGING_PLUGINS_DELETE` - Dev plugins to remove on staging deploys
- `STAGING_DOMAIN` - Staging domain suffix (default: dmctest.com.au)
- And other personal settings...

## Function Groups

### Configuration Management (config.sh)
Central configuration system that manages all dotfiles settings securely:
- `dotfiles_config --create`: Create your personal configuration file
- `dotfiles_config --show`: Display current configuration settings and values
- `dotfiles_config --edit`: Edit configuration file with your default editor
- `dotfiles_config --help`: Show detailed configuration help
- `load_dotfiles_config`: Load configuration (used automatically by functions)

### Cloudflare Management (cloudflare.sh)
Tools for managing Cloudflare zone settings:

**Optimisation:**
- `cf-opt`: Apply performance and security optimisations (interactive)
- `cf-opt DOMAIN`: Non-interactive batch mode
- `cf-opt DOMAIN SITE_PATH`: Batch mode with logging

**Verification:**
- `cf-check`: Check current Cloudflare settings and test cache headers
- `cf-help`: Show detailed help and usage examples

**What cf-opt configures:**
- Performance: HTTP/3, Early Hints, Tiered Cache, Auto Minify, 0-RTT
- Security: SSL Full (Strict), TLS 1.3, Min TLS 1.2, HTTPS Rewrites
- Cache Rules: Static assets, CSS/JS/fonts, images, WooCommerce bypass

**Configuration:**
- Requires `CF_API_TOKEN` in `.dotfiles-config`
- Token needs: Zone Settings, Cache Rules, Cache Purge, Argo Smart Routing permissions

### WordPress Core Shortcuts (wp-core.sh)
Essential WP-CLI aliases and shortcuts:
- `updatem`: Update all plugins, themes, and WordPress core
- `siteurl`: Display current site URL from database
- `plugincheck`: Check for plugin conflicts
- `onetimeinstall`: Install one-time login plugin on production
- `onetimeadmin`: Generate one-time login link for admin

### Database Operations (wp-db.sh)
All database-related functions consolidated:

**Database Sync Functions:**
- `pullprod`: Pull production database to local environment (full sync with `--yes`/`-y` flag)
- `pullstage`: Pull staging database to local environment
- `pushstage`: Push local database to staging environment
- `pulldb`: Export production database to timestamped local file

**User Management:**
- `dmcweb [user]`: Update user password to configured dev password (defaults to first admin)

**Multi-Host Operations:**
- `update-wc-db`: Update WooCommerce database on multiple configured hosts

**Database Optimisation:**
- `wp_db_optimise [options]` / `wpopt`: Comprehensive database cleanup and optimisation
- `wp_db_table_delete [options]` / `wpdel`: Interactive database table cleanup

### Upload Management (wp-uploads.sh)
File sync operations between environments:
- `getups`: Sync WordPress uploads directory from remote (`l`/`s`, `-week`/`-latest`)
- `pushups`: Push uploads to remote server (`-auto`, `-target`)

### Diagnostics and Troubleshooting (wp-diagnostics.sh)
Tools for debugging WordPress issues:
- `wp_plugin_diags`: Systematically test plugins to isolate fatal errors

### AI Integration (wp-mcp.sh)
Helpers for exposing WordPress sites to AI agents via the Model Context Protocol (MCP):
- `wp_mcp_add_site SITENAME [SUBSITE_URL] [SERVER_SUFFIX]`: Install the `wp-system-report` and `mcp-adapter` plugins on a local site (under `~/Sites/SITENAME`), activate them, and register the site as a STDIO MCP server in Claude Code as `wordpress-SITENAME`. Multisite-aware: detects networks via `wp core is-installed --network` and uses `--network` activation. Pass an optional `SUBSITE_URL` to register a per-subsite entry (registered as `wordpress-SITENAME-<slug>`, with `--url=` baked into the wp-cli args); pass an explicit `SERVER_SUFFIX` to override the auto-derived slug when subsite hosts collide (e.g. subdirectory installs). Idempotent — safe to re-run.
- `wp_mcp_add_remote_site SITENAME URL USERNAME APP_PASSWORD`: Register a remote (production or staging) WordPress site as `wordpress-SITENAME`, using the Automattic `mcp-wordpress-remote` STDIO proxy. Client-side only — the remote site must already have `wp-system-report` and `mcp-adapter` installed and active. The URL may be a base URL (e.g. `https://example.com.au`) or a full MCP endpoint URL.
- `wp_mcp_install_remote_plugins SITENAME [ALIAS]`: Companion to the above. Reads `~/Sites/SITENAME/wp-cli.yml`, resolves the named alias (defaults to `@prod`), and uses its `ssh:` + `path:` values to SSH into the host, clone both plugins into `wp-content/plugins`, run `composer install` on `mcp-adapter`, and activate them. Activation is invoked as `wp @prod plugin activate ...` so wp-cli handles the SSH plumbing; multisite is detected via `wp @prod core is-installed --network` and triggers `--network` activation. Pre-flight checks confirm `git`, `composer`, and `wp` are on the remote PATH.
- `wp_mcp_remove_site SITENAME`: Unregister a `wordpress-SITENAME` entry from Claude Code. Idempotent — does not delete the WordPress plugins server-side.
- `wp_mcp_list_sites`: List every `wordpress-*` MCP server known to Claude Code (across user and project scopes), grouped by transport (`stdio-local` vs `http-proxy`).

**Requirements:** wp-cli, composer, git, jq, npx, and the `claude` command on PATH. The local WordPress admin user must be named `admin` (otherwise edit the `--user=` flag in `wp_mcp_add_site`). For remote sites, use a WordPress application password (Users → Profile → Application Passwords), not the user's main login password.

### Fleet Operations (wp-fleet.sh)
Multi-site bulk operations that iterate every `wordpress-*` MCP server registered in Claude Code (read directly from `~/.claude.json`, same source as `wp_mcp_list_sites`). Failures on individual sites are aggregated, never abort the run.

- `wp_fleet_update [options]`: Run `wp plugin update --all`, `wp theme update --all`, and `wp core update` against every local registered site, in that order. Equivalent to `updatem` applied across the fleet.
- `wp_fleet_db_optimise [options]`: Run a **safe subset** of `wp_db_optimise` across every local registered site — delete expired transients, orphaned postmeta, stale auto-drafts, stale edit locks, and run `wp db optimize`. Deliberately does NOT rewrite wp-config constants or deactivate/activate plugins (those are `wp_db_optimise`'s dev-focused steps and would be dangerous on production).

**Shared flags:**
- `--dry-run`, `-n` — preview pending operations; execute nothing
- `--yes`, `-y` — skip the interactive confirmation prompt
- `--json` — emit machine-readable JSON (suppresses all decorative output; stable contract for a future web-app dashboard)
- `--only=<pattern>` — glob filter over server names (`--only=colacnew` or `--only=wordpress-colac*`)
- `--exclude=<pattern>` — inverse glob filter
- `--help`, `-h` — per-function help

**Design decisions** (documented in full in the `wp-fleet.sh` header):
- Remote (`http-proxy`) sites are **skipped in v1** — the MCP registry stores HTTP credentials for diagnostics but not the SSH details wp-cli needs. They are recorded in the JSON summary with `status: "skipped"`. v2 plan: a `WP_FLEET_SSH_MAP` in `.dotfiles-config`.
- JSON shape is a stable contract documented at the top of `wp-fleet.sh`.

### Theme Deployment (deployment.sh)
Deployment automation:
- `firstdeploy`: Initial site deployment to staging
- `firstdeploy-prod`: Initial site deployment to production
- `depto`: Deploy theme files to staging or production

### Git Utilities (git.sh)
Version control workflow and convenient aliases:
- `new_branch`: Create new branch from ticket ID and title
- `gs`: Git status (alias)
- `ga`: Git add (alias)
- `gca`: Git commit all (alias)
- `gc`: Git commit (alias)
- `gl`: Formatted git log with graph, dates, and decoration

### System Utilities (utils.sh)
General system tools and productivity functions:
- `listcmds`: Display all available commands and functions in a neat table

**File System Utilities:**
- `showsize`: Display directory sizes (alias: du -sh ./*)
- `dsclean`: Delete all .DS_Store files recursively
- `ls`: Enhanced ls with colours and details (alias)
- `up [N]`: Move up N directories in the filesystem

**Network Utilities:**
- `myip`: Display your public IP address
- `socksit`: Create SSH SOCKS proxy (uses configured SSH_PROXY_HOST)
- `chromeproxy`: Launch Chrome with SSH SOCKS proxy
- `flushdns`: Flush DNS cache and announce completion

**Development Tools:**
- `zp`: Edit ~/.zprofile in Cursor (alias)
- `sshconfig`: Edit ~/.ssh/config in Cursor (alias)
- `code`: Open files in VSCode with proper setup
- `tb`: Send text to termbin.com (alias)

**Homebrew Utilities:**
- `brewup`: Update Homebrew packages (alias)
- `brewupc`: Update Homebrew packages and cleanup (alias)

**Media Download Tools:**
- `ytaudio [URL]`: Download YouTube audio as MP3
- `download_vimeo_hd` / `dlvimeo`: Download all Vimeo videos from a page in HD with metadata

## Usage Examples

### Upload Management
Sync uploads from live site:
```bash
cd ~/Sites/yoursite
getups l          # Sync all uploads
getups l -latest  # Sync only last 2 months
getups l -week    # Sync only last 7 days
```

Push uploads to staging:
```bash
pushups -auto -target s  # Auto-detect site and push to staging
```

### Database Operations
Pull production database:
```bash
cd ~/Sites/yoursite
pullprod          # Interactive confirmation
pullprod --yes    # Skip confirmation
```

Optimise local database:
```bash
wp_db_optimise    # Or use alias: wpopt
```

Clean up database tables:
```bash
wp_db_table_delete  # Or use alias: wpdel
```

### Media Downloads
Download Vimeo videos from a lesson page (HD with source URL metadata):
```bash
dlvimeo https://example.com/lesson-page/
```

### Diagnostics
Test for plugin conflicts:
```bash
cd ~/Sites/yoursite
wp_plugin_diags  # Systematically test each plugin
```

### AI Integration (MCP)
Set up a local WordPress site for AI-driven diagnostics via Claude Code:
```bash
wp_mcp_add_site colacnew  # Installs plugins + registers wordpress-colacnew with Claude Code
```

Multisite — expose the network's main site, or one entry per subsite:
```bash
wp_mcp_add_site mynet                                       # Network-activates, registers wordpress-mynet (main site)
wp_mcp_add_site mynet https://subsite-a.localhost   # Registers wordpress-mynet-subsite-a
wp_mcp_add_site mynet https://mynet.localhost/subdir-b/ subdir-b # Subdirectory subsite, explicit suffix to avoid collision
```

Install the MCP plugins on a remote site over SSH (resolves SSH alias + remote path from the site's `wp-cli.yml`):
```bash
wp_mcp_install_remote_plugins colacnew            # uses @prod by default
wp_mcp_install_remote_plugins colacnew @staging   # override with a different alias
```

Register a remote (production or staging) site that already has the plugins deployed:
```bash
wp_mcp_add_remote_site myclient https://myclient.com.au admin xxxx-xxxx-xxxx-xxxx
```

List every registered WordPress MCP server (grouped by transport):
```bash
wp_mcp_list_sites
```

Unregister a site (does not touch the WordPress plugins themselves):
```bash
wp_mcp_remove_site colacnew
```

After adding or removing, restart Claude Code and ask: *"health check on wordpress-colacnew"*.

### Fleet Operations
Bulk-iterate every registered WordPress MCP site. Use `--dry-run` first; the real run will prompt unless `--yes` is given.
```bash
wp_fleet_update --dry-run                 # preview pending updates across all sites
wp_fleet_update --only=colacnew --dry-run # preview for a single site
wp_fleet_update --yes                     # apply updates across the fleet
wp_fleet_update --json --yes | jq .       # machine-readable output for tooling

wp_fleet_db_optimise --dry-run            # preview cleanup counts across all sites
wp_fleet_db_optimise --only=colacnew --yes
wp_fleet_db_optimise --json --yes | jq '.sites[] | {name, details}'
```

### Deployment
Deploy theme to staging:
```bash
cd ~/Sites/yoursite/wp-content/themes/yoursite
depto -auto -target staging
```

### Cloudflare Management
Optimise a Cloudflare zone interactively:
```bash
cf-opt  # Prompts for zone selection and confirmations
```

Optimise in batch mode (non-interactive):
```bash
cf-opt example.com.au                    # No logging
cf-opt example.com.au ~/Sites/example    # With logging to site directory
```

Check current settings:
```bash
cf-check  # View settings and test cache headers
```

### Git Workflow
Create new feature branch:
```bash
new_branch IR-123 "add new feature"  # Creates feature/IR-123-add-new-feature
```

### Command Reference
List all available commands:
```bash
listcmds  # Display comprehensive list of all functions and aliases
```

## Requirements

- macOS
- Homebrew
- WP-CLI
- Git
- SSH access to deployment servers
- jq (for Cloudflare and MCP functions: `brew install jq`)
- Composer, Node.js/npx, and Claude Code CLI (for `wp-mcp.sh` functions)

## File Structure After Installation

```
~/
├── .shell-functions -> ~/dotfiles/shell/     # Symlink to shell functions
└── dotfiles/
    ├── shell/
    │   ├── cloudflare.sh                    # Cloudflare zone management
    │   ├── config.sh                        # Central configuration system
    │   ├── deployment.sh                    # Theme deployment functions
    │   ├── git.sh                           # Git utilities
    │   ├── utils.sh                         # System utilities
    │   ├── wp-core.sh                       # WordPress shortcuts
    │   ├── wp-db.sh                         # Database operations
    │   ├── wp-diagnostics.sh                # Troubleshooting
    │   ├── wp-mcp.sh                        # AI integration (MCP)
    │   ├── wp-fleet.sh                      # Fleet operations across MCP sites
    │   └── wp-uploads.sh                    # File sync operations
    ├── .dotfiles-config                     # Your personal settings (git-ignored)
    ├── .gitignore                           # Includes .dotfiles-config
    └── README.md
```

### Important Files:
- **`~/.shell-functions/`** - Symlink that makes all functions available in your shell
- **`.dotfiles-config`** - Contains your personal/sensitive configuration values
- **`.gitignore`** - Ensures `.dotfiles-config` is never committed to git

## Updating

To update the functions:

```bash
cd ~/dotfiles
git pull
```

**No additional steps needed!** The symbolic link ensures you always use the latest files.

### Important Notes:
- Your `.dotfiles-config` file will never be overwritten during updates
- New configuration options may be added - run `dotfiles_config --show` to see available settings
- Functions automatically load the latest configuration when called

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request
