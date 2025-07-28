# WordPress Core WP-CLI Shortcuts & Aliases
#
# This file contains essential WP-CLI aliases and shortcuts for common WordPress tasks.
# All other WordPress functions have been organized into specialized files:
# - wp-uploads.sh: Upload/file sync operations
# - wp-dev.sh: Development tools and content creation
# - wp-diagnostics.sh: Troubleshooting and testing
# - wp-db.sh: Database operations and management

# Common WP-CLI aliases
alias updatem="wp plugin update --all;wp theme update --all; wp core update"
alias siteurl="wp db query 'SELECT * FROM wp_options WHERE option_name=\"siteurl\"' --skip-column-names"
alias plugincheck="wp plugin list --field=name | xargs -n1 -I % wp --skip-plugins=% plugin get % --field=name"
alias onetimeinstall="wp @prod plugin install one-time-login --activate"
alias onetimeadmin="wp user one-time-login admin"