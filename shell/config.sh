# Global Configuration Management for Dotfiles
# 
# PURPOSE:
# This file centralizes all configuration for dotfiles shell functions, allowing
# personal customization without exposing sensitive values in the public repo.
#
# HOW IT WORKS:
# 1. Sets safe default values for all configuration variables
# 2. Loads user-specific overrides from .dotfiles-config (git-ignored)
# 3. Provides functions to create/edit/view the configuration file
#
# SECURITY:
# The .dotfiles-config file is git-ignored and contains sensitive values like:
# - DEV_WP_PASSWORD (WordPress development password)
# - SSH_PROXY_HOST (SSH proxy server hostname)
# - WC_HOSTS (list of production server aliases)
#
# This keeps personal credentials out of the public repository while
# maintaining full functionality for the original user.
#
# ============================================================================
# FUNCTION INDEX
# ============================================================================
#
# Configuration Management:
# • load_dotfiles_config       - Load configuration with defaults (auto-called)
# • create_default_config      - Create default .dotfiles-config file 
# • show_dotfiles_config       - Display current configuration settings
# • dotfiles_config            - Main config management function
#   - dotfiles_config --create   : Create default configuration file
#   - dotfiles_config --show     : Display current configuration settings  
#   - dotfiles_config --edit     : Edit configuration file with default editor
#   - dotfiles_config --help     : Show detailed configuration help
#
# Variables Set:
# • PLUGIN_SKIP_LIST           - Plugins to skip in wp_plugin_diags
# • WC_HOSTS                   - SSH hosts for update-wc-db function
# • UPLOAD_EXCLUDES            - File patterns to exclude in getups/pushups  
# • SSH_TIMEOUT                - SSH connection timeout in seconds
# • DEFAULT_MEMORY_LIMIT       - WordPress memory limit for optimization
# • DEFAULT_MAX_MEMORY_LIMIT   - WordPress max memory limit
# • DEV_WP_PASSWORD            - WordPress development password (override in config!)
# • SSH_PROXY_HOST             - SSH proxy host for SOCKS tunneling (override in config!)
#
# ============================================================================

# CONFIGURATION FILE LOCATION:
# The .dotfiles-config file is stored in the dotfiles repo root directory.
# Try multiple methods to find the script directory, with fallback to $HOME/dotfiles
if [[ -n "${(%):-%x}" ]] 2>/dev/null; then
    # zsh: use %x
    _SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"
elif [[ -n "${BASH_SOURCE[0]}" ]]; then
    # bash: use BASH_SOURCE
    _SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
    # Fallback: assume standard location
    _SCRIPT_DIR="$HOME/dotfiles/shell"
fi
DOTFILES_CONFIG_FILE="$(cd "$_SCRIPT_DIR/.." 2>/dev/null && pwd)/.dotfiles-config"

# If config file doesn't exist at detected location, try standard $HOME/dotfiles location
if [[ ! -f "$DOTFILES_CONFIG_FILE" ]] && [[ -f "$HOME/dotfiles/.dotfiles-config" ]]; then
    DOTFILES_CONFIG_FILE="$HOME/dotfiles/.dotfiles-config"
fi

# Function to load configuration with defaults

# MAIN CONFIGURATION LOADER
# 
# This function is called automatically when config.sh is sourced.
# It sets safe defaults for all variables, then overrides them with
# user-specific values from .dotfiles-config (if the file exists).
#
# USAGE:
#   load_dotfiles_config   # Called automatically, or manually reload config
#
# VARIABLES SET:
load_dotfiles_config() {
    # DEFAULT VALUES (safe for public repo):
    PLUGIN_SKIP_LIST="wordfence akismet updraftplus"          # Plugins to skip in wp_plugin_diags
    WC_HOSTS="aquacorp-l aussie-l registrars-l cem-l colac-l dpm-l pelican-l pricing-l toshiba-l"  # SSH hosts for update-wc-db  
    UPLOAD_EXCLUDES="*.pdf *.docx *.zip"                      # File patterns to exclude in getups/pushups
    SSH_TIMEOUT="10"                                           # SSH connection timeout in seconds
    DEFAULT_MEMORY_LIMIT="512M"                               # WordPress memory limit for wp_db_optimise
    DEFAULT_MAX_MEMORY_LIMIT="1024M"                          # WordPress max memory limit
    DEV_WP_PASSWORD="defaultpass"                             # Default WordPress dev password (OVERRIDE IN .dotfiles-config!)
    SSH_PROXY_HOST="localhost"                                 # Default SSH proxy host (OVERRIDE IN .dotfiles-config!)

    # LOAD USER OVERRIDES:
    # If .dotfiles-config exists, source it to override the defaults above
    if [[ -f "$DOTFILES_CONFIG_FILE" ]]; then
        source "$DOTFILES_CONFIG_FILE"
    fi
}

# Function to create default configuration file
create_default_config() {
    if [[ -f "$DOTFILES_CONFIG_FILE" ]]; then
        echo "Configuration file already exists at: $DOTFILES_CONFIG_FILE"
        return 0
    fi

    cat > "$DOTFILES_CONFIG_FILE" << 'EOF'
# Dotfiles Configuration File
# Generated: $(date)
#
# This file contains user-customizable settings for dotfiles functions.
# Uncomment and modify any settings you want to customize.

# WordPress Plugin Diagnostics Configuration
# List of plugins to skip during wp_plugin_diags testing
# PLUGIN_SKIP_LIST="wordfence akismet updraftplus"

# WooCommerce Update Hosts Configuration
# List of SSH host aliases for update-wc-db function
# WC_HOSTS="aquacorp-l aussie-l registrars-l cem-l colac-l dpm-l pelican-l pricing-l toshiba-l"

# Upload Sync Configuration
# File patterns to exclude during upload sync (getups/pushups)
# UPLOAD_EXCLUDES="*.pdf *.docx *.zip *.psd"

# SSH Connection Configuration
# Timeout in seconds for SSH connectivity tests
# SSH_TIMEOUT="10"

# WordPress Memory Configuration
# Default memory limits for wp_db_optimise
# DEFAULT_MEMORY_LIMIT="512M"
# DEFAULT_MAX_MEMORY_LIMIT="1024M"

# Development Environment Configuration
# Default local URL pattern (sitename will be substituted)
# LOCAL_URL_PATTERN="https://SITENAME.localhost"

# Database Optimization Configuration
# Skip plugin management during optimization
# DEFAULT_SKIP_PLUGINS=false

# Enable verbose output for all operations
# VERBOSE_OUTPUT=true

# Custom backup directory (defaults to site root)
# BACKUP_DIR="$HOME/backups/dotfiles"

# Security Configuration
# Default WordPress development password
# DEV_WP_PASSWORD="your-dev-password"

# SSH proxy host for SOCKS tunneling
# SSH_PROXY_HOST="your-proxy-host"
EOF

    echo "✅ Default configuration file created at: $DOTFILES_CONFIG_FILE"
    echo ""
    echo "Edit this file to customize your dotfiles behavior:"
    echo "  nano $DOTFILES_CONFIG_FILE"
    echo ""
}

# Function to show current configuration
show_dotfiles_config() {
    load_dotfiles_config

    echo "Current Dotfiles Configuration"
    echo "=============================="
    echo ""
    echo "Configuration file: $DOTFILES_CONFIG_FILE"
    if [[ -f "$DOTFILES_CONFIG_FILE" ]]; then
        echo "Status: ✅ Exists"
    else
        echo "Status: ❌ Not found (using defaults)"
    fi
    echo ""
    echo "Active Settings:"
    echo "  Plugin Skip List: $PLUGIN_SKIP_LIST"
    echo "  WC Hosts: $(echo $WC_HOSTS | tr ' ' '\n' | wc -w | tr -d ' ') hosts configured"
    echo "  Upload Excludes: $UPLOAD_EXCLUDES"
    echo "  SSH Timeout: ${SSH_TIMEOUT}s"
    echo "  Memory Limit: $DEFAULT_MEMORY_LIMIT"
    echo "  Max Memory Limit: $DEFAULT_MAX_MEMORY_LIMIT"
    echo ""

    if [[ ! -f "$DOTFILES_CONFIG_FILE" ]]; then
        echo "To create a configuration file:"
        echo "  dotfiles_config --create"
    else
        echo "To edit configuration:"
        echo "  nano $DOTFILES_CONFIG_FILE"
    fi
}

# Main configuration function
dotfiles_config() {
    case "$1" in
        --create|-c)
            create_default_config
            ;;
        --show|-s)
            show_dotfiles_config
            ;;
        --edit|-e)
            if [[ ! -f "$DOTFILES_CONFIG_FILE" ]]; then
                echo "Configuration file doesn't exist. Creating it first..."
                create_default_config
            fi
            ${EDITOR:-nano} "$DOTFILES_CONFIG_FILE"
            ;;
        --help|-h)
            echo "Dotfiles Configuration Management"
            echo ""
            echo "USAGE:"
            echo "  dotfiles_config --create        # Create default config file"
            echo "  dotfiles_config --show          # Show current configuration"
            echo "  dotfiles_config --edit          # Edit configuration file"
            echo "  dotfiles_config --help          # Show this help"
            echo ""
            echo "DESCRIPTION:"
            echo "  Manages global configuration for all dotfiles functions."
            echo "  Configuration is stored in $DOTFILES_CONFIG_FILE"
            echo ""
            echo "CUSTOMIZABLE SETTINGS:"
            echo "  • Plugin skip lists for diagnostics"
            echo "  • Host lists for bulk operations"
            echo "  • Upload exclusion patterns"
            echo "  • SSH timeouts and connection settings"
            echo "  • Memory limits and performance settings"
            echo ""
            ;;
        *)
            show_dotfiles_config
            ;;
    esac
}

# Automatically load configuration when this file is sourced
load_dotfiles_config