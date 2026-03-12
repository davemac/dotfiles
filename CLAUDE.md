# Dotfiles - Claude Code Context

## What This Is

A collection of zsh shell functions for WordPress development workflows. Used daily on macOS by a single developer working with WordPress sites hosted on remote servers.

## Architecture

### Symlink Pattern

`~/.shell-functions` is a symlink to `~/dotfiles/shell/`. The user's `~/.zshrc` sources all `*.sh` files from `~/.shell-functions/`. This means the files in `shell/` are the canonical source — there are no copies.

### Configuration System

- `shell/config.sh` — sets safe defaults, then loads user overrides from `.dotfiles-config`
- `.dotfiles-config` — lives in the repo root (git-ignored), contains sensitive values (API keys, passwords, SSH hosts)
- `config.sh` uses `pwd -P` to resolve the symlink and find `.dotfiles-config` relative to the real script directory (i.e. `~/dotfiles/.dotfiles-config`, not `~/.dotfiles-config`)

### Loading Pattern

Every function that needs configuration calls `load_dotfiles_config 2>/dev/null || true` at the top. This sets defaults first, then overlays the user's `.dotfiles-config` values.

## Key Variables in .dotfiles-config

- `WC_HOSTS` — space-separated SSH aliases for WooCommerce sites (used by `update-wc-db`)
- `CF_API_TOKEN` — Cloudflare API token (used by `cf-opt`, `cf-check`)
- `DEV_WP_PASSWORD` — local dev password (used by `dmcweb`)
- `SSH_PROXY_HOST` — SSH proxy server name (used by `socksit`, `chromeproxy`)

## SSH Aliases

Remote servers use short SSH aliases (e.g. `aquacorp-l`, `toshiba-l`, `pelican-l`). These are defined in `~/.ssh/config`, not in this repo. The `-l` suffix typically indicates a live/production server.

## Conventions

- All shell scripts are zsh, not bash
- Functions use kebab-case for public commands (e.g. `update-wc-db`, `cf-opt`)
- Functions use snake_case for internal/utility functions (e.g. `load_dotfiles_config`)
- Australian English in comments and output
- Security: sensitive values stay in `.dotfiles-config`, never hardcoded in committed files
