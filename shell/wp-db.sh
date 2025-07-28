# WordPress Database Sync Function
#
# pullprod() - Syncs a WordPress database from production to local environment
#
# This function performs the following operations:
# 1. Backs up the local database
# 2. Downloads the production database
# 3. Updates URLs to match local environment
# 4. Updates WordPress core, plugins, and themes
# 5. Configures plugins for local development
#
# Usage:
#   Run from either the WordPress root directory or theme directory
#   The site name is automatically detected from the directory structure
#   Requires WP-CLI and a configured @prod alias
#
# Example directory structures:
#   ~/Sites/sitename/              (WordPress root)
#   ~/Sites/sitename/wp-content/themes/sitename/  (Theme directory)
#
pullprod() {
    # Define colors for better readability
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local RED='\033[0;31m'
    local NC='\033[0m' # No Color

    # Helper functions for consistent message formatting
    message() {
        echo -e "${GREEN}==>${NC} $1"
    }

    warning() {
        echo -e "${YELLOW}Warning:${NC} $1"
    }

    error() {
        echo -e "${RED}Error:${NC} $1"
        return 1
    }

    # Prerequisite checks
    # Verify WP-CLI is installed and @prod alias is configured
    if ! command -v wp > /dev/null 2>&1; then
        error "WP-CLI is not installed. Please install it first: https://wp-cli.org/"
        return 1
    fi

    if ! wp cli alias get @prod > /dev/null 2>&1; then
        error "WP-CLI @prod alias not configured. Please configure it in ~/.wp-cli/config.yml"
        return 1
    fi

    # Directory and site name detection
    # Automatically determines site name and root directory from current path
    local CURRENT_DIR=$(pwd)
    local SITE_NAME=$(basename $(echo "$CURRENT_DIR" | sed -E "s|/wp-content/themes/.*||"))

    # Validation checks for site name
    if [ -z "$SITE_NAME" ]; then
        error "Could not determine site name from directory structure"
        return 1
    fi

    if ! [[ $SITE_NAME =~ ^[a-zA-Z0-9-]+$ ]]; then
        error "Site name contains invalid characters. Use only letters, numbers, and hyphens."
        return 1
    fi

    # Site root detection and validation
    # Works from either WordPress root or theme directory
    local SITE_ROOT
    if [[ "$CURRENT_DIR" == *"/wp-content/themes/"* ]]; then
        # We're in the theme directory
        SITE_ROOT=$(echo "$CURRENT_DIR" | sed -E "s|/wp-content/themes/.*||")
        cd "$SITE_ROOT" || error "Failed to change to site root directory"
        message "Changed to site root: $SITE_ROOT"
    else
        # Assume we're already in the site root
        SITE_ROOT="$CURRENT_DIR"
    fi

    # Verify this is actually a WordPress installation
    if [ ! -f "$SITE_ROOT/wp-config.php" ]; then
        error "WordPress installation not found in $SITE_ROOT"
        return 1
    fi

    # URL configuration
    local LOCAL_URL="https://${SITE_NAME}.localhost"
    message "Local URL: $LOCAL_URL"

    # Get production URL for search-replace operation
    message "Getting production site URL..."
    local PROD_URL=$(wp @prod option get siteurl) || error "Failed to connect to production site"

    if [ -z "$PROD_URL" ]; then
        error "Failed to get production site URL"
        return 1
    fi

    message "Production URL: $PROD_URL"

    # User confirmation to prevent accidental execution
    echo ""
    warning "You are about to reset your local database and import the production database."
    warning "This will overwrite all local data for site: $SITE_NAME"
    warning "Production URL: $PROD_URL"
    warning "Local URL: $LOCAL_URL"
    echo ""
    read "CONFIRM?Are you sure you want to continue? (y/n): "

    if [[ $CONFIRM != "y" && $CONFIRM != "Y" ]]; then
        message "Operation cancelled by user"
        return 0
    fi

    # Database operation files
    local BACKUP_FILE="${SITE_ROOT}/${SITE_NAME}-backup-$(date +%Y%m%d_%H%M%S).sql"
    local IMPORT_FILE="${SITE_ROOT}/${SITE_NAME}-prod-$(date +%Y%m%d).sql"

    # Backup local database for safety
    message "Creating backup of local database..."
    wp db export "$BACKUP_FILE" || error "Failed to backup local database"
    message "Local database backed up to: $BACKUP_FILE"

    # Reset local database to ensure clean import
    message "Resetting local database..."
    wp db reset --yes || error "Failed to reset local database"

    # Export and import production database
    message "Exporting database from production..."
    wp @prod db export - > "$IMPORT_FILE" || error "Failed to export production database"

    # Verify export success and handle failures
    if [ ! -s "$IMPORT_FILE" ]; then
        warning "Production database export failed or is empty"
        message "Restoring local database..."
        wp db reset --yes || error "Failed to reset database for restore"
        wp db import "$BACKUP_FILE" || error "Failed to restore local database backup"
        rm -f "$BACKUP_FILE" "$IMPORT_FILE"
        error "Database export failed - local database has been restored"
        return 1
    fi

    # Import production database to local
    message "Importing production database to local..."
    if ! wp db import "$IMPORT_FILE"; then
        warning "Failed to import production database"
        message "Restoring local database..."
        wp db reset --yes || error "Failed to reset database for restore"
        wp db import "$BACKUP_FILE" || error "Failed to restore local database backup"
        rm -f "$BACKUP_FILE" "$IMPORT_FILE"
        error "Database import failed - local database has been restored"
        return 1
    fi

    # Clean up temporary files
    rm -f "$BACKUP_FILE" "$IMPORT_FILE"

    # Update URLs in database
    message "Replacing production URL with local URL..."
    wp search-replace "$PROD_URL" "$LOCAL_URL" --all-tables --precise || warning "Search-replace operation may not have completed successfully"

    # Set local development credentials
    message "Updating admin user password..."
    wp user update admin --user_pass=dmcweb

    # Update WordPress components
    message "Updating WordPress core, plugins, themes and languages..."
    wp plugin update --all
    wp theme update --all
    wp core update
    wp core language update

    # Configure plugins for local development
    # Deactivate production-only plugins and activate development plugins
    message "Configuring plugins for local environment..."
    wp plugin deactivate worker wp-rocket passwords-evolved
    wp plugin activate query-monitor acf-theme-code-pro
    wp jetpack module deactivate protect
    wp jetpack module deactivate account-protection

    # Success messages
    message "Database sync completed successfully!"
    message "Production database imported to local environment."
    message "Admin password updated to: dmcweb"
    message "Login URL: $LOCAL_URL/wp-admin/"
}

# Pull a staging WP database to an existing local site
pullstage() {
   START=$(date +%s)
   current=${PWD##*/}
   cd ~/Sites/$current
   wp db export _db.sql
   wp db reset --yes
   wp @stage db export - > $current.sql
   echo "rsync of staging database to local $current database complete."
   wp db import
   rm -rf $current.sql
   wp plugin update --all
   wp theme update --all
   wp core update
   wp core language update
   wp plugin activate query-monitor acf-theme-code-pro
   wp plugin deactivate passwords-evolved
   staging_url=$(wp @stage option get siteurl)
   wp search-replace ${staging_url/$'\n'} https://$current.localhost --all-tables --precise
   dmcweb
   cd ~/Sites/$current/wp-content/themes/$current
   sed -i "" "s/dmcstarter/$current/g" README.md

   END=$(date +%s)
   DIFF=$(( $END - $START ))
   echo -e "\n$staging_url database now in use on https://$current.localhost site.\nIt took $DIFF seconds, enjoy!\n"
}

# Pull a testing WP database to an existing local site
pulltest() {
   START=$(date +%s)
   wp db export _db.sql
   wp db reset --yes
   current=${PWD##*/}
   wp @test db export - > $current.sql
   echo "rsync of test database to local $current database complete."
   wp db import
   rm -rf $current.sql
   wp plugin update --all
   wp theme update --all
   wp core update
   wp core language update
   wp plugin activate query-monitor acf-theme-code-pro
   wp plugin deactivate passwords-evolved
   test_url=$(wp @test option get siteurl)
   wp search-replace ${test_url/$'\n'} https://$current.localhost --all-tables --precise
   dmcweb
   cd ~/Sites/$current/wp-content/themes/$current
   END=$(date +%s)
   DIFF=$(( $END - $START ))
   echo -e "\n$test_url database now in use on https://$current.localhost site.\nIt took $DIFF seconds, enjoy!\n"
}

# Push a local WP database to an existing staging site
pushstage() {
   START=$(date +%s)
   current=${PWD##*/}
   cd ~/Sites/$current || return

   wp db export $current.sql
   rsync $current.sql $current-s:~/

   wp @stage db export backup.sql
   wp @stage db reset --yes

   wp @stage db import $current.sql
   wp @stage search-replace "https://$current.localhost" "https://$current.dmctest.com.au" --all-tables --precise

   wp @stage plugin deactivate query-monitor acf-theme-code-pro wordpress-seo
   wp @stage option update blog_public 0

   cd ~/Sites/$current/wp-content/themes/$current
   END=$(date +%s)
   DIFF=$(( $END - $START ))
   echo -e "\n$current.localhost database now in use on $push_staging_url site.\nIt took $DIFF seconds, enjoy!\n"
}

alias pulldb='wp @prod db export - > "$(basename $PWD)-$(date +%Y-%d-%m).sql"'