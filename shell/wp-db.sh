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
    # Handle --help flag
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "WordPress Production Database Sync Tool"
        echo ""
        echo "USAGE:"
        echo "  pullprod                            # Sync production database to local"
        echo "  pullprod --help                     # Show this help message"
        echo ""
        echo "DESCRIPTION:"
        echo "  Syncs a WordPress database from production to local environment."
        echo "  Automatically detects site name from directory structure."
        echo ""
        echo "REQUIREMENTS:"
        echo "  • wp-cli installed and configured"
        echo "  • @prod alias configured in ~/.wp-cli/config.yml"
        echo "  • Run from WordPress root OR theme directory"
        echo "  • SSH access to production server"
        echo ""
        echo "OPERATIONS:"
        echo "  1. Backs up the local database"
        echo "  2. Downloads the production database"
        echo "  3. Updates URLs to match local environment"
        echo "  4. Updates WordPress core, plugins, and themes"
        echo "  5. Configures plugins for local development"
        echo ""
        echo "DIRECTORY STRUCTURES:"
        echo "  ~/Sites/sitename/                           # WordPress root"
        echo "  ~/Sites/sitename/wp-content/themes/sitename/ # Theme directory"
        echo ""
        echo "SAFETY FEATURES:"
        echo "  • Creates backup before importing"
        echo "  • Validates production connection"
        echo "  • Restores backup on failure"
        echo "  • User confirmation required"
        echo ""
        echo "WHAT CHANGES:"
        echo "  • Local database replaced with production data"
        echo "  • URLs updated to https://sitename.localhost"
        echo "  • Admin password set to 'dmcweb'"
        echo "  • Development plugins activated"
        echo "  • Production-only plugins deactivated"
        echo ""
        return 0
    fi

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

    # Pre-check: Test SSH connectivity to production
    message "Testing connectivity to production server..."
    if ! wp @prod core is-installed --quiet 2>/dev/null; then
        error "Cannot connect to production server. Please check:"
        echo "  • SSH connection to production server"
        echo "  • @prod alias configuration in ~/.wp-cli/config.yml"
        echo "  • wp-cli installation on production server"
        echo "  • Network connectivity"
        return 1
    fi
    message "Production server connection verified ✓"

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
   # Pre-check: Test SSH connectivity to staging
   echo "Testing connectivity to staging server..."
   if ! wp @stage core is-installed --quiet 2>/dev/null; then
       echo "❌ Cannot connect to staging server. Please check:"
       echo "  • SSH connection to staging server"
       echo "  • @stage alias configuration in ~/.wp-cli/config.yml"
       echo "  • wp-cli installation on staging server"
       echo "  • Network connectivity"
       return 1
   fi
   echo "✅ Staging server connection verified"

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

# Push Staging Dry-run Preview Function
pushstage_dry_run_preview() {
    local current=${PWD##*/}
    
    echo "📊 Analyzing local and staging environments..."
    echo ""
    
    # Basic environment info
    echo "🏠 LOCAL ENVIRONMENT:"
    if [[ -f "wp-config.php" ]]; then
        local local_url=$(wp option get siteurl 2>/dev/null || echo "https://$current.localhost")
        local local_db_size=$(wp db size 2>/dev/null | grep -o '[0-9.]* MB' || echo "unknown size")
        local local_posts=$(wp post list --format=count 2>/dev/null || echo "unknown")
        local local_plugins=$(wp plugin list --status=active --format=count 2>/dev/null || echo "unknown")
        
        echo "  • Site URL: $local_url"
        echo "  • Database size: $local_db_size"
        echo "  • Posts: $local_posts"
        echo "  • Active plugins: $local_plugins"
    else
        echo "  • Not in WordPress root directory"
        echo "  • Site: $current (detected from directory name)"
        echo "  • Expected path: ~/Sites/$current/"
    fi
    
    echo ""
    echo "🎭 STAGING ENVIRONMENT:"
    local staging_url="https://$current.dmctest.com.au"
    echo "  • Target URL: $staging_url"
    echo "  • SSH alias: $current-s"
    
    # Check if we can connect to staging (non-destructive check)
    if wp @stage core is-installed --quiet 2>/dev/null; then
        local staging_db_size=$(wp @stage db size 2>/dev/null | grep -o '[0-9.]* MB' || echo "unknown")
        local staging_posts=$(wp @stage post list --format=count 2>/dev/null || echo "unknown")
        echo "  • Current database size: $staging_db_size"
        echo "  • Current posts: $staging_posts"
        echo "  • Connection: ✅ Verified"
    else
        echo "  • Connection: ❌ Cannot connect (would fail in real execution)"
    fi
    
    echo ""
    echo "🔄 OPERATIONS THAT WOULD BE PERFORMED:"
    echo ""
    echo "1. 📤 DATABASE EXPORT (Local):"
    echo "   • Export local database → $current.sql"
    echo "   • Transfer file to staging server via rsync"
    echo ""
    
    echo "2. 🔒 STAGING BACKUP:"
    echo "   • Create backup: backup.sql (on staging server)"
    echo "   • Preserve current staging data for safety"
    echo ""
    
    echo "3. 🔄 DATABASE REPLACEMENT:"
    echo "   • Reset staging database (⚠️ destructive)"
    echo "   • Import local database to staging"
    echo ""
    
    echo "4. 🔗 URL REPLACEMENT:"
    local local_url_for_replace=$(wp option get siteurl 2>/dev/null || echo "https://$current.localhost")
    echo "   • Search-replace URLs in database:"
    echo "     $local_url_for_replace → $staging_url"
    echo ""
    
    echo "5. 🔌 PLUGIN CONFIGURATION:"
    echo "   • Plugins that would be DEACTIVATED:"
    echo "     - query-monitor (development tool)"
    echo "     - acf-theme-code-pro (development tool)"  
    echo "     - wordpress-seo (optional deactivation)"
    echo ""
    
    echo "6. ⚙️  STAGING SETTINGS:"
    echo "   • blog_public: 1 → 0 (hide from search engines)"
    echo ""
    
    echo "📈 ESTIMATED IMPACT:"
    if wp core is-installed --quiet 2>/dev/null; then
        local export_size=$(wp db size 2>/dev/null | grep -o '[0-9.]*' | head -1 || echo "unknown")
        if [[ "$export_size" != "unknown" ]]; then
            echo "  • Database export size: ~$export_size MB"
            echo "  • Transfer time: ~$((${export_size%.*} / 5)) seconds (depends on connection)"
        fi
        echo "  • Estimated total time: 2-4 minutes"
    else
        echo "  • Run from WordPress root for detailed estimates"
    fi
    
    echo ""
    echo "⚠️  IMPORTANT WARNINGS:"
    echo "  • This operation OVERWRITES the staging database completely"
    echo "  • Current staging content will be REPLACED with local content"
    echo "  • A backup is created, but staging data will be lost"
    echo "  • URL replacement affects ALL content (posts, options, metadata)"
    echo ""
    
    echo "💡 To execute this push, run:"
    echo "   pushstage"
    echo ""
    echo "🔍 To check staging before pushing:"
    echo "   wp @stage option get siteurl"
    echo "   wp @stage post list --format=count"
}

# Push a local WP database to an existing staging site
pushstage() {
   # Handle --help flag
   if [[ "$1" == "--help" || "$1" == "-h" ]]; then
       echo "WordPress Database Push to Staging Tool"
       echo ""
       echo "USAGE:"
       echo "  pushstage                    # Push local database to staging"
       echo "  pushstage --dry-run          # Preview what would be pushed"
       echo "  pushstage --help             # Show this help message"
       echo ""
       echo "DESCRIPTION:"
       echo "  Pushes local WordPress database to staging environment."
       echo "  Automatically handles URL replacement and plugin configuration."
       echo ""
       echo "OPTIONS:"
       echo "  --dry-run       Preview changes without executing them"
       echo "  --help, -h      Show this help message"
       echo ""
       echo "OPERATIONS:"
       echo "  1. Export local database"
       echo "  2. Transfer database file to staging server"
       echo "  3. Backup current staging database"
       echo "  4. Import local database to staging"
       echo "  5. Replace URLs: localhost → staging URLs"
       echo "  6. Configure plugins for staging environment"
       echo ""
       echo "REQUIREMENTS:"
       echo "  • @stage alias configured in ~/.wp-cli/config.yml"
       echo "  • SSH access to staging server"
       echo "  • Must be run from site directory under ~/Sites/"
       echo ""
       return 0
   fi

   # Handle --dry-run flag
   local dry_run=false
   if [[ "$1" == "--dry-run" ]]; then
       dry_run=true
   fi

   if [[ "$dry_run" == true ]]; then
       echo "🔍 DRY RUN MODE - No changes will be made"
       echo "============================================="
       echo "Previewing database push to staging..."
       echo ""
       
       # Generate dry-run preview
       pushstage_dry_run_preview
       return 0
   fi

   # Pre-check: Test SSH connectivity to staging
   echo "Testing connectivity to staging server..."
   if ! wp @stage core is-installed --quiet 2>/dev/null; then
       echo "❌ Cannot connect to staging server. Please check:"
       echo "  • SSH connection to staging server"
       echo "  • @stage alias configuration in ~/.wp-cli/config.yml"
       echo "  • wp-cli installation on staging server"
       echo "  • Network connectivity"
       return 1
   fi
   echo "✅ Staging server connection verified"

   START=$(date +%s)
   current=${PWD##*/}
   cd ~/Sites/$current || return

   # Additional pre-check: Test direct SSH connection for file transfer
   echo "Testing SSH file transfer connectivity..."
   if ! ssh -q "$current-s" exit 2>/dev/null; then
       echo "❌ Cannot establish SSH connection to $current-s. Please check:"
       echo "  • SSH config entry for $current-s"
       echo "  • SSH key authentication"
       echo "  • Network connectivity"
       return 1
   fi
   echo "✅ SSH file transfer connectivity verified"

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

# Check for missing featured images
check-featured-image() {
    wp db query "SELECT ID FROM $(wp db prefix)posts WHERE post_type='post' AND post_status='publish' AND ID NOT IN (SELECT post_id FROM $(wp db prefix)postmeta WHERE meta_key='_thumbnail_id');" --skip-column-names
}

# Update user password to 'dmcweb'. Defaults to 'admin' user ID.
dmcweb() {
    local user_id=${1:-admin}
    wp user update "$user_id" --user_pass=dmcweb
}

# Update WooCommerce on multiple hosts
#
# This function loops through an array of SSH config host aliases and runs the
# WP-CLI `wc update` command on each, updating the WooCommerce database tables.
# If a host cannot be connected to, the script will skip it and continue with
# the next host in the list.
#
# Parameters:
#   None
#
# Returns:
#   0 if all hosts were updated successfully, otherwise 1
 update-wc-db() {
    echo "🔍 Pre-flight connectivity checks..."
    
    # Load configuration for WooCommerce hosts
    load_dotfiles_config 2>/dev/null || true
    local hosts_string="${WC_HOSTS:-aquacorp-l aussie-l registrars-l cem-l colac-l dpm-l hisense-l pelican-l pricing-l rippercorp-l advocate-l toshiba-l}"
    # Convert space-separated string to array
    local -a hosts
    read -A hosts <<< "$hosts_string"
    local exit_status=0
    local unreachable_hosts=()
    local reachable_hosts=()

    # Pre-check all hosts before starting any operations
    echo "Testing connectivity to all hosts..."
    for host in "${hosts[@]}"; do
        echo -n "  Checking $host... "
        if ssh -q -o ConnectTimeout=5 "$host" exit 2>/dev/null; then
            echo "✅ Connected"
            reachable_hosts+=("$host")
        else
            echo "❌ Failed"
            unreachable_hosts+=("$host")
            exit_status=1
        fi
    done

    # Report unreachable hosts
    if [ ${#unreachable_hosts[@]} -gt 0 ]; then
        echo ""
        echo "⚠️  Warning: ${#unreachable_hosts[@]} host(s) unreachable:"
        for host in "${unreachable_hosts[@]}"; do
            echo "  • $host"
        done
        echo ""
        echo "Proceeding with ${#reachable_hosts[@]} reachable hosts..."
        read -p "Continue? (y/N): " confirm
        if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
            echo "Operation cancelled"
            return 1
        fi
    else
        echo "✅ All hosts reachable, proceeding with updates..."
    fi

    echo ""
    
    # Loop through each reachable host to run the WooCommerce update command
    for host in "${reachable_hosts[@]}"; do
        echo "Connecting to $host..."

        # Use SSH to connect to the host and execute the WP-CLI WooCommerce update commands
        echo "Running WooCommerce update on $host..."
        ssh "$host" "cd ~/www && wp wc update" 2>&1

        # Check if the command was successful
        if [ $? -eq 0 ]; then
            echo "✅ WooCommerce updated successfully on $host."
        else
            echo "❌ Failed to update WooCommerce on $host."
            exit_status=1
        fi
    done

    return $exit_status
}

# WordPress Database Optimization Dry-run Preview Function
wp_db_optimise_dry_run_preview() {
    local skip_plugins="$1"
    
    echo "📊 Analyzing database for cleanup opportunities..."
    echo ""
    
    # Database cleanup preview
    echo "🧹 DATABASE CLEANUP PREVIEW:"
    
    # Expired transients
    local expired_transients=$(wp db query "SELECT COUNT(*) FROM wp_options WHERE option_name LIKE '_transient_timeout_%' AND option_value < UNIX_TIMESTAMP();" --skip-column-names --silent 2>/dev/null || echo "0")
    echo "  • Expired transients: $expired_transients entries would be deleted"
    
    # Orphaned postmeta
    local orphaned_postmeta=$(wp db query "SELECT COUNT(*) FROM wp_postmeta pm LEFT JOIN wp_posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;" --skip-column-names --silent 2>/dev/null || echo "0")
    echo "  • Orphaned postmeta: $orphaned_postmeta entries would be removed"
    
    # Auto-draft posts
    local auto_drafts=$(wp db query "SELECT COUNT(*) FROM wp_posts WHERE post_status = 'auto-draft' AND post_date < DATE_SUB(NOW(), INTERVAL 7 DAY);" --skip-column-names --silent 2>/dev/null || echo "0")
    echo "  • Old auto-draft posts: $auto_drafts posts would be deleted"
    
    # Edit locks
    local edit_locks=$(wp db query "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key = '_edit_lock';" --skip-column-names --silent 2>/dev/null || echo "0")
    echo "  • Edit locks: $edit_locks entries would be cleaned"
    
    # Action Scheduler
    local failed_actions=$(wp db query "SELECT COUNT(*) FROM wp_actionscheduler_actions WHERE status = 'failed';" --skip-column-names --silent 2>/dev/null || echo "0")
    echo "  • Failed Action Scheduler jobs: $failed_actions entries would be deleted"
    
    # Plugin-specific cleanups
    echo ""
    echo "🧽 PLUGIN-SPECIFIC CLEANUP PREVIEW:"
    
    # SEOPress
    local seopress_meta=$(wp db query "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key LIKE '_seopress_%';" --skip-column-names --silent 2>/dev/null || echo "0")
    if [[ "$seopress_meta" -gt 0 ]]; then
        echo "  • SEOPress metadata: $seopress_meta entries would be cleaned"
    fi
    
    # Jetpack
    local jetpack_cache=$(wp db query "SELECT COUNT(*) FROM wp_postmeta WHERE meta_key = '_jetpack_related_posts_cache';" --skip-column-names --silent 2>/dev/null || echo "0")
    if [[ "$jetpack_cache" -gt 0 ]]; then
        echo "  • Jetpack cache entries: $jetpack_cache entries would be cleaned"
    fi
    
    # Check for large plugin tables
    local gravitysmtp_count=$(wp db query "SELECT COUNT(*) FROM wp_gravitysmtp_events;" --skip-column-names --silent 2>/dev/null || echo "0")
    if [[ "$gravitysmtp_count" -gt 0 ]]; then
        echo "  • GravitySmtp events: $gravitysmtp_count entries would be truncated"
    fi
    
    local ewww_count=$(wp db query "SELECT COUNT(*) FROM wp_ewwwio_images;" --skip-column-names --silent 2>/dev/null || echo "0")
    if [[ "$ewww_count" -gt 0 ]]; then
        echo "  • EWWW image entries: $ewww_count entries would be truncated"
    fi
    
    echo ""
    echo "⚙️  WORDPRESS CONFIGURATION CHANGES:"
    load_dotfiles_config 2>/dev/null || true
    
    # Show current vs new config values
    local current_memory=$(wp config get WP_MEMORY_LIMIT 2>/dev/null || echo "not set")
    local new_memory="${DEFAULT_MEMORY_LIMIT:-512M}"
    echo "  • WP_MEMORY_LIMIT: $current_memory → $new_memory"
    
    local current_max_memory=$(wp config get WP_MAX_MEMORY_LIMIT 2>/dev/null || echo "not set")
    local new_max_memory="${DEFAULT_MAX_MEMORY_LIMIT:-1024M}"
    echo "  • WP_MAX_MEMORY_LIMIT: $current_max_memory → $new_max_memory"
    
    local current_cron=$(wp config get DISABLE_WP_CRON 2>/dev/null || echo "false")
    echo "  • DISABLE_WP_CRON: $current_cron → true"
    
    local current_debug=$(wp config get WP_DEBUG 2>/dev/null || echo "false")
    echo "  • WP_DEBUG: $current_debug → true"
    
    local current_revisions=$(wp config get WP_POST_REVISIONS 2>/dev/null || echo "unlimited")
    echo "  • WP_POST_REVISIONS: $current_revisions → 3"
    
    # Plugin management preview
    if [[ "$skip_plugins" != true ]]; then
        echo ""
        echo "🔌 PLUGIN MANAGEMENT PREVIEW:"
        
        # Plugins that would be deactivated
        local heavy_plugins="jetpack google-listings-and-ads woocommerce-services official-mailerlite-sign-up-forms woo-mailerlite gravitysmtp wp-seopress wp-seopress-pro akismet instagram-feed feeds-for-youtube acf-theme-code-pro"
        local active_heavy=""
        for plugin in $heavy_plugins; do
            if wp plugin is-active "$plugin" 2>/dev/null; then
                active_heavy="$active_heavy $plugin"
            fi
        done
        
        if [[ -n "$active_heavy" ]]; then
            echo "  • Plugins that would be deactivated:$active_heavy"
        else
            echo "  • No heavy plugins currently active to deactivate"
        fi
        
        # Plugins that would be activated
        if ! wp plugin is-active query-monitor 2>/dev/null; then
            echo "  • Plugins that would be activated: query-monitor"
        else
            echo "  • query-monitor already active"
        fi
    else
        echo ""
        echo "🔌 PLUGIN MANAGEMENT: Skipped (--skip-plugins flag)"
    fi
    
    echo ""
    echo "📈 ESTIMATED IMPACT:"
    local current_db_size=$(wp db size --format=csv --fields=size 2>/dev/null | tail -1 | grep -o '[0-9]*' || echo "unknown")
    if [[ "$current_db_size" != "unknown" ]]; then
        local estimated_savings=$((orphaned_postmeta * 100 + auto_drafts * 50 + expired_transients * 20))
        echo "  • Current database size: $(numfmt --to=iec $current_db_size 2>/dev/null || echo $current_db_size) bytes"
        echo "  • Estimated space savings: ~$(numfmt --to=iec $estimated_savings 2>/dev/null || echo $estimated_savings) bytes"
    fi
    echo "  • Estimated execution time: 2-4 minutes"
    echo ""
    echo "💡 To execute these changes, run:"
    echo "   wp_db_optimise $site_name"
    if [[ "$skip_plugins" == true ]]; then
        echo "   wp_db_optimise $site_name --skip-plugins"
    fi
}

# Optimise WordPress localhost database and configuration for development
#
# Performs comprehensive database cleanup, removes plugin bloat, configures
# WordPress settings for development, and optionally manages plugins.
#
# Usage:
#   wp_db_optimise [site-name] [--skip-plugins]
#   wpopt [site-name] [--skip-plugins]           # Alias
#
# Arguments:
#   site-name       - Site directory name (optional if run from WordPress root)
#   --skip-plugins  - Skip plugin deactivation/activation
#
# Operations:
#   • Database cleanup (transients, orphaned data, plugin-specific tables)
#   • WordPress configuration optimisation for development
#   • Plugin management (deactivates heavy plugins, activates dev tools)
#   • Performance reporting and metrics
#
wp_db_optimise() {
   # Handle --help flag first
   if [[ "$1" == "--help" || "$1" == "-h" ]]; then
       echo "WordPress Database Optimization Tool"
       echo ""
       echo "USAGE:"
       echo "  wp_db_optimise [site-name] [options]"
       echo "  wpopt [site-name] [options]          # Alias"
       echo ""
       echo "ARGUMENTS:"
       echo "  site-name       Site directory name (optional if run from WordPress root)"
       echo ""
       echo "OPTIONS:"
       echo "  --skip-plugins  Skip plugin deactivation/activation"
       echo "  --dry-run       Preview changes without executing them"
       echo "  --help, -h      Show this help message"
       echo ""
       echo "DESCRIPTION:"
       echo "  Performs comprehensive database cleanup, removes plugin bloat,"
       echo "  configures WordPress settings for development, and manages plugins."
       echo ""
       echo "OPERATIONS:"
       echo "  • Database cleanup (transients, orphaned data, plugin-specific tables)"
       echo "  • WordPress configuration optimization for development"
       echo "  • Plugin management (deactivates heavy plugins, activates dev tools)"
       echo "  • Performance reporting and metrics"
       echo ""
       echo "EXAMPLES:"
       echo "  wp_db_optimise                      # Auto-detect site from current directory"
       echo "  wp_db_optimise mysite               # Optimize specific site"
       echo "  wp_db_optimise mysite --skip-plugins # Optimize without plugin changes"
       echo "  wpopt mysite                        # Using alias"
       echo ""
       echo "OUTPUT:"
       echo "  • Before/after database size comparison"
       echo "  • Postmeta entries cleanup report"
       echo "  • Plugin activation status"
       echo "  • Database health metrics"
       echo ""
       return 0
   fi

   local site_name="$1"
   local skip_plugins=false
   local dry_run=false

   # Parse options
   while [[ $# -gt 0 ]]; do
       case $1 in
           --skip-plugins)
               skip_plugins=true
               shift
               ;;
           --dry-run)
               dry_run=true
               shift
               ;;
           --help|-h)
               # Already handled above, but include for completeness
               shift
               ;;
           *)
               if [[ -z "$site_name" ]]; then
                   site_name="$1"
               fi
               shift
               ;;
       esac
   done

   # If no site name provided, try to detect from current directory
   if [[ -z "$site_name" ]]; then
       if [[ -f "wp-config.php" ]]; then
           site_name=$(basename "$PWD")
           echo "🔍 Detected site: $site_name"
       else
           echo "❌ Usage: wp_db_optimise [site-name] [--skip-plugins]"
           echo "   Or run from WordPress root directory"
           return 1
       fi
   fi

   # Navigate to site directory
   if [[ ! -f "wp-config.php" ]]; then
       if [[ -d ~/Sites/$site_name ]]; then
           cd ~/Sites/$site_name
           echo "📁 Changed to ~/Sites/$site_name"
       else
           echo "❌ Site directory not found: ~/Sites/$site_name"
           return 1
       fi
   fi

   if [[ "$dry_run" == true ]]; then
       echo "🔍 DRY RUN MODE - No changes will be made"
       echo "=================================================="
       echo "Previewing optimization for: $site_name"
       echo ""
       
       # Check if WP-CLI is available
       if ! command -v wp &> /dev/null; then
           echo "❌ WP-CLI not found. Please install WP-CLI first."
           return 1
       fi
       
       # Generate dry-run preview
       wp_db_optimise_dry_run_preview "$skip_plugins"
       return 0
   fi

   echo "🚀 Starting WordPress localhost optimization for: $site_name"
   echo "=================================================="

   # Check if WP-CLI is available
   if ! command -v wp &> /dev/null; then
       echo "❌ WP-CLI not found. Please install WP-CLI first."
       return 1
   fi

   # Function to convert bytes to human readable
   bytes_to_human() {
       local bytes="$1"
       if [[ "$bytes" =~ ^[0-9]+$ ]]; then
           if [ $bytes -ge 1073741824 ]; then
               echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}") GB"
           elif [ $bytes -ge 1048576 ]; then
               echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}") MB"
           elif [ $bytes -ge 1024 ]; then
               echo "$(awk "BEGIN {printf \"%.2f\", $bytes/1024}") KB"
           else
               echo "${bytes} B"
           fi
       else
           echo "$bytes"
       fi
   }

   # Capture BEFORE stats - simplified approach
   echo "📊 Capturing baseline metrics..."
   local before_db_raw=$(wp db size 2>/dev/null)
   local before_db_bytes=$(echo "$before_db_raw" | grep -o '[0-9]* B' | head -1 | tr -d ' B' || echo "0")
   local before_db_human=$(bytes_to_human "$before_db_bytes")
   local before_postmeta=$(wp db query "SELECT COUNT(*) as count FROM wp_postmeta;" --skip-column-names --silent 2>/dev/null || echo "0")
   local before_plugins=$(wp plugin list --status=active --format=count 2>/dev/null || echo "0")

   # Basic database cleanup
   echo "🧹 Cleaning up database..."
   wp transient delete --expired
   wp db optimize

   echo "📋 Cleaning Action Scheduler..."
   wp action-scheduler clean
   wp db query "DELETE FROM wp_actionscheduler_actions WHERE status = 'failed';" 2>/dev/null || echo "   No failed actions to clean"

   echo "🗑️  Removing orphaned data..."
   wp db query "DELETE pm FROM wp_postmeta pm LEFT JOIN wp_posts wp ON wp.ID = pm.post_id WHERE wp.ID IS NULL;"
   wp db query "DELETE FROM wp_posts WHERE post_status = 'auto-draft' AND post_date < DATE_SUB(NOW(), INTERVAL 7 DAY);"

   echo "🔄 Cleaning edit locks and metadata..."
   wp db query "DELETE FROM wp_postmeta WHERE meta_key = '_edit_lock' AND meta_value < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 7 DAY));"
   wp db query "DELETE FROM wp_postmeta WHERE meta_key = '_edit_last' AND meta_value < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 7 DAY));"
   wp db query "DELETE FROM wp_postmeta WHERE meta_key LIKE '_transient_%' OR meta_key LIKE '_site_transient_%';"

   echo "🧽 Plugin-specific cleanup..."
   # SEOPress cleanup
   wp db query "DELETE FROM wp_postmeta WHERE meta_key LIKE '_seopress_%';" 2>/dev/null
   wp db query "TRUNCATE TABLE wp_seopress_content_analysis;" 2>/dev/null || echo "   SEOPress content analysis table not found"
   wp db query "TRUNCATE TABLE wp_seopress_significant_keywords;" 2>/dev/null || echo "   SEOPress keywords table not found"

   # Jetpack cleanup
   wp db query "DELETE FROM wp_postmeta WHERE meta_key = '_jetpack_related_posts_cache';" 2>/dev/null
   wp db query "DELETE FROM wp_postmeta WHERE meta_key = '_last_editor_used_jetpack';" 2>/dev/null

   # GravitySmtp cleanup (major performance killer)
   wp db query "TRUNCATE TABLE wp_gravitysmtp_events;" 2>/dev/null || echo "   GravitySmtp events table not found"

   # EWWW Image Optimizer cleanup
   wp db query "TRUNCATE TABLE wp_ewwwio_images;" 2>/dev/null || echo "   EWWW images table not found"

   # Security plugin cleanup
   wp db query "TRUNCATE TABLE wp_aiowps_events;" 2>/dev/null || echo "   AIOWPS events table not found"

   # Miscellaneous cleanup
   wp db query "DELETE FROM wp_postmeta WHERE meta_key = '_wpas_done_all';" 2>/dev/null
   wp db query "DELETE FROM wp_postmeta WHERE meta_key = 'dmc_show_full_article';" 2>/dev/null
   wp db query "DELETE FROM wp_postmeta WHERE meta_key = '_dmc_show_full_article';" 2>/dev/null

   echo "⚙️  Updating WordPress configuration..."
   load_dotfiles_config 2>/dev/null || true
   wp config set DISABLE_WP_CRON true --type=constant 2>/dev/null
   wp config set WP_MEMORY_LIMIT "${DEFAULT_MEMORY_LIMIT:-512M}" --type=constant 2>/dev/null
   wp config set WP_MAX_MEMORY_LIMIT "${DEFAULT_MAX_MEMORY_LIMIT:-1024M}" --type=constant 2>/dev/null
   wp config set AUTOSAVE_INTERVAL 300 --type=constant 2>/dev/null
   wp config set WP_POST_REVISIONS 3 --type=constant 2>/dev/null
   wp config set WP_DEBUG true --type=constant 2>/dev/null
   wp config set WP_DEBUG_LOG true --type=constant 2>/dev/null
   wp config set WP_DEBUG_DISPLAY false --type=constant 2>/dev/null
   wp config set SAVEQUERIES false --type=constant 2>/dev/null

   # Plugin optimization (unless skipped)
   if [[ "$skip_plugins" != true ]]; then
       echo "🔌 Optimizing plugins for development..."

       # Deactivate performance-heavy plugins
       echo "   Deactivating heavy plugins..."
       wp plugin deactivate jetpack google-listings-and-ads woocommerce-services official-mailerlite-sign-up-forms woo-mailerlite gravitysmtp wp-seopress wp-seopress-pro akismet instagram-feed feeds-for-youtube acf-theme-code-pro 2>/dev/null || echo "   Some plugins not found or already inactive"

       # Activate essential development plugins
       echo "   Activating essential development plugins..."
       wp plugin activate query-monitor 2>/dev/null || echo "   Some essential plugins not found"
   else
       echo "🔌 Skipping plugin optimization (--skip-plugins flag set)"
   fi

   # Capture AFTER stats
   echo "📊 Capturing final metrics..."
   local after_db_raw=$(wp db size 2>/dev/null)
   local after_db_bytes=$(echo "$after_db_raw" | grep -o '[0-9]* B' | head -1 | tr -d ' B' || echo "0")
   local after_db_human=$(bytes_to_human "$after_db_bytes")
   local after_postmeta=$(wp db query "SELECT COUNT(*) as count FROM wp_postmeta;" --skip-column-names --silent 2>/dev/null || echo "0")
   local after_plugins=$(wp plugin list --status=active --format=count 2>/dev/null || echo "0")

   # Calculate savings
   local bytes_saved=0
   local saved_human=""
   if [[ "$before_db_bytes" =~ ^[0-9]+$ ]] && [[ "$after_db_bytes" =~ ^[0-9]+$ ]] && [[ $before_db_bytes -gt $after_db_bytes ]]; then
       bytes_saved=$((before_db_bytes - after_db_bytes))
       saved_human=$(bytes_to_human "$bytes_saved")
   fi

   # Display comparison
   echo ""
   echo "════════════════════════════════════════════════"
   echo "📊 OPTIMIZATION RESULTS COMPARISON"
   echo "════════════════════════════════════════════════"
   echo ""
   echo "💾 DATABASE SIZE:"
   echo "   Before: $before_db_human"
   echo "   After:  $after_db_human"
   if [[ $bytes_saved -gt 0 ]]; then
       echo "   Saved:  $saved_human"
   fi
   echo ""
   echo "📝 POSTMETA ENTRIES:"
   if [[ "$before_postmeta" =~ ^[0-9]+$ ]] && [[ "$after_postmeta" =~ ^[0-9]+$ ]]; then
       echo "   Before: $(printf "%'d" $before_postmeta) entries"
       echo "   After:  $(printf "%'d" $after_postmeta) entries"
       if [[ $before_postmeta -gt $after_postmeta ]]; then
           local postmeta_saved=$((before_postmeta - after_postmeta))
           echo "   Saved:  $(printf "%'d" $postmeta_saved) entries"
       fi
   else
       echo "   Before: $before_postmeta entries"
       echo "   After:  $after_postmeta entries"
   fi
   echo ""
   echo "🔌 ACTIVE PLUGINS:"
   echo "   Before: $before_plugins plugins"
   echo "   After:  $after_plugins plugins"
   echo ""

   # Show current database health
   echo "🏥 CURRENT DATABASE HEALTH:"
   wp db size
   echo ""
   echo "Largest tables:"
   wp db query "SELECT table_name, ROUND(((data_length + index_length) / 1024 / 1024), 2) AS 'Size (MB)' FROM information_schema.tables WHERE table_schema = DATABASE() ORDER BY (data_length + index_length) DESC LIMIT 5;"
   echo ""
   echo "Action Scheduler status:"
   wp action-scheduler status
   echo ""

   echo "✅ Optimization complete for $site_name!"
   echo "🌐 Test your site: https://$site_name.localhost"
   echo ""
   echo "📝 Quick performance test command:"
   echo "   time curl -s https://$site_name.localhost > /dev/null"
   echo ""
}

# Alias for quick access
alias wpopt='wp_db_optimise'

# Clean WordPress Database Table Cleanup Function
# Usage: wp_db_table_delete

wp_db_table_delete() {
    # Handle --help flag
    if [[ "$1" == "--help" || "$1" == "-h" ]]; then
        echo "WordPress Database Table Cleanup Tool"
        echo ""
        echo "USAGE:"
        echo "  wp_db_table_delete                  # Interactive table cleanup"
        echo "  wp_db_table_delete --dry-run        # Preview tables without deleting"
        echo "  wp_db_table_delete --help           # Show this help message"
        echo ""
        echo "DESCRIPTION:"
        echo "  Interactive tool for cleaning up WordPress database tables."
        echo "  Shows table sizes, safety levels, and allows selective deletion."
        echo ""
        echo "OPTIONS:"
        echo "  --dry-run       Preview tables and estimated cleanup without executing"
        echo "  --help, -h      Show this help message"
        echo ""
        echo "SAFETY LEVELS:"
        echo "  🟢 SAFE        Usually safe to delete (logs, cache, temporary data)"
        echo "  🟡 CAUTION     Review before deleting (plugin data, analytics)"
        echo "  🔴 DANGER      WordPress core tables - DO NOT DELETE"
        echo ""
        echo "FEATURES:"
        echo "  • Automatic backup creation before deletion"
        echo "  • Table size and row count analysis"
        echo "  • Safety classification system"
        echo "  • Detailed debug logging"
        echo ""
        return 0
    fi

    # Handle --dry-run flag
    local dry_run=false
    if [[ "$1" == "--dry-run" ]]; then
        dry_run=true
    fi

    # Colors (check if terminal supports colors)
    local RED=''
    local GREEN=''
    local YELLOW=''
    local BLUE=''
    local BOLD=''
    local RESET=''

    if [[ -t 1 ]] && [[ "${TERM:-}" != "dumb" ]] && command -v tput >/dev/null 2>&1; then
        RED='\033[31m'
        GREEN='\033[32m'
        YELLOW='\033[33m'
        BLUE='\033[34m'
        BOLD='\033[1m'
        RESET='\033[0m'
    fi

    # Safety dots
    local RED_DOT="${RED}●${RESET}"
    local GREEN_DOT="${GREEN}●${RESET}"
    local YELLOW_DOT="${YELLOW}●${RESET}"

    # Variables
    local debug_log="$(pwd)/wp_db_cleanup_debug.log"
    local wp_prefix=""
    local db_name=""
    local -A table_data
    local -a table_numbers

    # Debug logging function (skip in dry-run mode)
    debug_log() {
        if [[ "$dry_run" != true ]]; then
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$debug_log"
        fi
    }

    # Initialize debug log (skip in dry-run mode)
    if [[ "$dry_run" == true ]]; then
        echo "${BOLD}🔍 WordPress Database Table Cleanup - DRY RUN MODE${RESET}"
        echo "Preview mode: No changes will be made to your database"
    else
        echo "=== WordPress DB Cleanup Debug Log ===" > "$debug_log"
        debug_log "Starting wp_db_table_delete function"
        debug_log "Working directory: $(pwd)"
        echo "${BOLD}WordPress Database Table Cleanup${RESET}"
        echo "Debug log: ${BLUE}$debug_log${RESET}"
    fi

    # Check wp-cli
    debug_log "Checking wp-cli availability"
    if ! command -v wp &> /dev/null; then
        echo "${RED}Error: wp-cli not found${RESET}"
        debug_log "ERROR: wp-cli command not found"
        return 1
    fi
    debug_log "wp-cli found: $(which wp)"

    # Check WordPress installation
    debug_log "Checking WordPress installation"
    if ! wp core is-installed --quiet 2>/dev/null; then
        echo "${RED}Error: WordPress not found${RESET}"
        debug_log "ERROR: WordPress installation not found"
        return 1
    fi
    debug_log "WordPress installation confirmed"

    # Get database info
    debug_log "Getting database configuration"
    db_name=$(wp config get DB_NAME 2>/dev/null)
    wp_prefix=$(wp config get table_prefix 2>/dev/null)

    debug_log "Database name: $db_name"
    debug_log "Table prefix: $wp_prefix"

    if [[ -z "$db_name" ]]; then
        echo "${RED}Error: Could not get database name${RESET}"
        debug_log "ERROR: Failed to get database name"
        return 1
    fi

    echo "Database: $db_name"
    echo "Prefix: $wp_prefix"

    # Create backup (skip in dry-run mode)
    if [[ "$dry_run" != true ]]; then
        echo "\n${BOLD}STEP 1: CREATING BACKUP${RESET}"
        echo "$(printf '=%.0s' {1..60})"

        local backup_file="$(pwd)/backup-before-cleanup-$(date +%Y-%m-%d-%H-%M-%S).sql"
        debug_log "Creating backup: $backup_file"

        echo "Creating backup: $backup_file"
        if wp db export "$backup_file" --quiet 2>>"$debug_log"; then
            local backup_size=$(du -h "$backup_file" | cut -f1)
            echo "${GREEN}✅ Backup created: $backup_file ($backup_size)${RESET}"
            debug_log "Backup successful: $backup_file ($backup_size)"
        else
            echo "${RED}❌ Backup failed${RESET}"
            debug_log "ERROR: Backup failed"
            return 1
        fi
    else
        echo "\n${BOLD}📋 ANALYZING DATABASE TABLES${RESET}"
        echo "$(printf '=%.0s' {1..60})"
        echo "In dry-run mode - no backup needed"
    fi

    # Get table information
    echo "\n${BOLD}STEP 2: LOADING TABLE INFORMATION${RESET}"
    echo "$(printf '=%.0s' {1..60})"

    debug_log "Loading table information"
    local temp_file=$(mktemp)
    debug_log "Temp file: $temp_file"

    # Simple query to get tables with sizes
    local query="SELECT
        table_name,
        ROUND(((data_length + index_length) / 1024 / 1024), 2) as size_mb,
        table_rows,
        engine
    FROM information_schema.tables
    WHERE table_schema = '$db_name'
    AND table_type = 'BASE TABLE'
    ORDER BY (data_length + index_length) DESC;"

    debug_log "Executing query"

    if wp db query "$query" --skip-column-names --batch > "$temp_file" 2>>"$debug_log"; then
        debug_log "Query successful, temp file size: $(wc -l < $temp_file) lines"
    else
        echo "${RED}Database query failed${RESET}"
        debug_log "ERROR: Database query failed"
        rm -f "$temp_file"
        return 1
    fi

    # Check if we got results
    if [[ ! -s "$temp_file" ]]; then
        echo "${RED}No tables found${RESET}"
        debug_log "ERROR: No tables found in query result"
        rm -f "$temp_file"
        return 1
    fi

    # Display tables
    echo "\n${BOLD}DATABASE TABLES (LARGEST FIRST)${RESET}"
    echo "$(printf '=%.0s' {1..80})"
    printf "%-4s %-35s %-10s %-12s %-15s\n" "NUM" "TABLE NAME" "SIZE(MB)" "ROWS" "SAFETY"
    echo "$(printf -- '-%.0s' {1..80})"

    local counter=1

    # Read and display tables
    while IFS=$'\t' read -r table_name size_mb rows engine; do
        # Set defaults for empty fields
        [[ -z "$size_mb" ]] && size_mb="0.00"
        [[ -z "$rows" ]] && rows="0"
        [[ -z "$engine" ]] && engine="Unknown"

        # Determine safety level
        local safety="CAUTION"
        local safety_dot="$YELLOW_DOT"

        # Check if WordPress core table
        case "$table_name" in
            "${wp_prefix}posts"|"${wp_prefix}postmeta"|"${wp_prefix}comments"|"${wp_prefix}commentmeta"|"${wp_prefix}users"|"${wp_prefix}usermeta"|"${wp_prefix}options"|"${wp_prefix}terms"|"${wp_prefix}term_taxonomy"|"${wp_prefix}term_relationships"|"${wp_prefix}links")
                safety="DANGER"
                safety_dot="$RED_DOT"
                ;;
            "${wp_prefix}actionscheduler_actions"|"${wp_prefix}actionscheduler_logs"|"${wp_prefix}actionscheduler_groups"|"${wp_prefix}actionscheduler_claims")
                safety="CAUTION"
                safety_dot="$YELLOW_DOT"
                ;;
            *log*|*cache*|*backup*|*trash*|*transient*|*stats*|*analytics*|*sessions*|*temporary*)
                safety="SAFE"
                safety_dot="$GREEN_DOT"
                ;;
        esac

        # Store data
        table_data[$counter]="$table_name|$size_mb|$rows|$engine|$safety"
        table_numbers+=($counter)

        # Truncate long table names for display
        local display_name="$table_name"
        if [[ ${#table_name} -gt 35 ]]; then
            display_name="${table_name:0:32}..."
        fi

        # Display row
        printf "%-4d %-35s %-10s %-12s %b %-10s\n" \
            "$counter" "$display_name" "$size_mb" "$(printf "%'d" $rows)" "$safety_dot" "$safety"

        debug_log "Table $counter: $table_name ($size_mb MB, $rows rows, $safety)"
        counter=$((counter + 1))
    done < "$temp_file"

    rm -f "$temp_file"

    echo "\n🟢 SAFE: Usually safe to delete"
    echo "🟡 CAUTION: Review before deleting"
    echo "🔴 DANGER: WordPress core - DO NOT DELETE"

    # Get user selection
    echo "\n${BOLD}SELECT TABLES TO DELETE${RESET}"
    echo "$(printf '=%.0s' {1..60})"
    echo "Enter numbers (e.g., 1,3,5), 'all-safe', or 'q' to quit:"
    echo -n "Selection: "

    read selection
    debug_log "User selection: $selection"

    if [[ "$selection" == "q" ]]; then
        echo "Exiting without changes"
        debug_log "User quit"
        return 0
    fi

    # Parse selection
    local -a selected_nums
    if [[ "$selection" == "all-safe" ]]; then
        debug_log "Selecting all safe tables"
        for num in "${table_numbers[@]}"; do
            IFS='|' read -r name size_mb rows engine safety <<< "${table_data[$num]}"
            if [[ "$safety" == "SAFE" ]]; then
                selected_nums+=($num)
                debug_log "Selected safe table: $name"
            fi
        done
    else
        # Parse comma-separated numbers
        IFS=',' read -A selected_nums <<< "${selection// /}"
        debug_log "Parsed selection: ${selected_nums[*]}"
    fi

    if [[ ${#selected_nums[@]} -eq 0 ]]; then
        echo "No valid tables selected"
        debug_log "No valid tables selected"
        return 0
    fi

    # Handle dry-run vs real deletion
    if [[ "$dry_run" == true ]]; then
        # Dry-run mode: just show what would be deleted
        echo "\n${BOLD}🔍 DRY RUN PREVIEW - TABLES THAT WOULD BE DELETED${RESET}"
        echo "$(printf '=%.0s' {1..60})"
        echo "Tables selected for deletion:"

        local total_size=0
        local safe_count=0
        local caution_count=0
        local danger_count=0
        
        for num in "${selected_nums[@]}"; do
            if [[ -n "${table_data[$num]}" ]]; then
                IFS='|' read -r name size_mb rows engine safety <<< "${table_data[$num]}"
                local dot="$YELLOW_DOT"
                [[ "$safety" == "SAFE" ]] && dot="$GREEN_DOT" && ((safe_count++))
                [[ "$safety" == "CAUTION" ]] && dot="$YELLOW_DOT" && ((caution_count++))
                [[ "$safety" == "DANGER" ]] && dot="$RED_DOT" && ((danger_count++))

                echo "  $dot $name ($size_mb MB, $(printf "%'d" $rows) rows)"
                total_size=$(echo "$total_size + $size_mb" | bc -l 2>/dev/null || echo "$total_size")
            fi
        done

        echo ""
        echo "📊 DELETION SUMMARY:"
        echo "  • Tables selected: ${#selected_nums[@]}"
        echo "  • Safe tables: $safe_count"
        echo "  • Caution tables: $caution_count"
        [[ $danger_count -gt 0 ]] && echo "  • ${RED_DOT} DANGER tables: $danger_count${RESET}"  
        echo "  • Total space to free: $(printf "%.2f" $total_size) MB"
        echo ""
        echo "💡 To execute this deletion, run:"
        echo "   wp_db_table_delete"
        echo ""
        echo "⚠️  Remember: A backup would be created before deletion"
        return 0
    else
        # Real deletion mode: confirm and delete
        echo "\n${BOLD}CONFIRM DELETION${RESET}"
        echo "$(printf '=%.0s' {1..60})"
        echo "Tables to delete:"

        local total_size=0
        for num in "${selected_nums[@]}"; do
            if [[ -n "${table_data[$num]}" ]]; then
                IFS='|' read -r name size_mb rows engine safety <<< "${table_data[$num]}"
                local dot="$YELLOW_DOT"
                [[ "$safety" == "SAFE" ]] && dot="$GREEN_DOT"
                [[ "$safety" == "DANGER" ]] && dot="$RED_DOT"

                echo "  $dot $name ($size_mb MB)"
                total_size=$(echo "$total_size + $size_mb" | bc -l 2>/dev/null || echo "$total_size")
                debug_log "Will delete: $name ($size_mb MB)"
            fi
        done

        echo "\nTotal space to free: $(printf "%.2f" $total_size) MB"
        echo "\n${RED}⚠️  THIS CANNOT BE UNDONE! ⚠️${RESET}"
        echo -n "Type 'DELETE' to confirm: "

        read confirmation
        debug_log "Confirmation: $confirmation"

        if [[ "$confirmation" != "DELETE" ]]; then
            echo "Cancelled"
            debug_log "User cancelled deletion"
            return 0
        fi
    fi

    # Delete tables
    echo "\n${BOLD}DELETING TABLES${RESET}"
    echo "$(printf '=%.0s' {1..60})"

    local success=0
    local failed=0

    for num in "${selected_nums[@]}"; do
        if [[ -n "${table_data[$num]}" ]]; then
            IFS='|' read -r name size_mb rows engine safety <<< "${table_data[$num]}"
            echo -n "Deleting $name... "

            if wp db query "DROP TABLE IF EXISTS \`$name\`" --quiet 2>>"$debug_log"; then
                echo "${GREEN}✅ Success${RESET}"
                debug_log "Successfully deleted: $name"
                ((success++))
            else
                echo "${RED}❌ Failed${RESET}"
                debug_log "Failed to delete: $name"
                ((failed++))
            fi
        fi
    done

    echo "\n${BOLD}SUMMARY${RESET}"
    echo "Deleted: $success tables"
    echo "Failed: $failed tables"
    echo "Backup: $backup_file"
    echo "Debug log: $debug_log"

    debug_log "Cleanup completed - Success: $success, Failed: $failed"
}

# Alias for quick access
alias wpdel='wp_db_table_delete'