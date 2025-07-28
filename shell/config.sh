# Global Configuration Management for Dotfiles
#
# This file provides configuration management functionality for all dotfiles functions.
# It loads user configurations from ~/.dotfiles-config and provides defaults.

# Configuration file path
DOTFILES_CONFIG_FILE="$HOME/.dotfiles-config"

# Function to load configuration with defaults
load_dotfiles_config() {
    # Set default values
    PLUGIN_SKIP_LIST="wordfence akismet updraftplus"
    WC_HOSTS="aquacorp-l aussie-l registrars-l cem-l colac-l dpm-l hisense-l pelican-l pricing-l rippercorp-l advocate-l toshiba-l"
    UPLOAD_EXCLUDES="*.pdf *.docx *.zip"
    SSH_TIMEOUT="10"
    DEFAULT_MEMORY_LIMIT="512M"
    DEFAULT_MAX_MEMORY_LIMIT="1024M"
    
    # Load user configuration if it exists
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
# PLUGIN_SKIP_LIST="wordfence akismet updraftplus custom-plugin"

# WooCommerce Update Hosts Configuration  
# List of SSH host aliases for update-wc-db function
# WC_HOSTS="site1-l site2-l site3-l"

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
            echo "  Configuration is stored in ~/.dotfiles-config"
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