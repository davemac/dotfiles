# WordPress Core WP-CLI Shortcuts & Aliases
#
# Essential WP-CLI aliases and shortcuts for common WordPress maintenance tasks.
# Provides quick access to the most frequently used WordPress operations.
#
# ============================================================================
# FUNCTION INDEX
# ============================================================================
#
# WordPress Maintenance:
# • updatem                    - Update all plugins, themes, and WordPress core
#   Equivalent to: wp plugin update --all; wp theme update --all; wp core update
#
# Site Information:
# • siteurl                    - Display current site URL from database
#   Queries wp_options table for siteurl option
#
# Plugin Management:
# • plugincheck                - Check for plugin conflicts by testing each plugin individually
#   Tests each plugin by temporarily skipping it during activation
#
# Production Utilities:
# • onetimeinstall             - Install one-time login plugin on production server
#   Uses @prod wp-cli alias to install and activate on remote production site
#
# • onetimeadmin               - Generate one-time login link for admin user
#   Creates secure temporary login URL for admin access
#
# Note: This file focuses on core WordPress operations. Other specialized functions
# are organized into dedicated files:
# • wp-uploads.sh    - Upload/file sync operations  
# • wp-dev.sh        - Development tools and content creation
# • wp-diagnostics.sh - Troubleshooting and testing
# • wp-db.sh         - Database operations and management
#
# ============================================================================

# Common WP-CLI aliases
alias updatem="wp plugin update --all;wp theme update --all; wp core update"
alias siteurl="wp db query 'SELECT * FROM wp_options WHERE option_name=\"siteurl\"' --skip-column-names"
alias plugincheck="wp plugin list --field=name | xargs -n1 -I % wp --skip-plugins=% plugin get % --field=name"
alias onetimeinstall="wp @prod plugin install one-time-login --activate"
alias onetimeadmin="wp user one-time-login admin"