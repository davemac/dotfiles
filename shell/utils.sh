# File system utilities
alias showsize="du -sh ./*"
alias dsclean="find . -type f -name .DS_Store -delete"
alias ls="ls -Ghal"
alias rsync="rsync -avzW --progress"
alias gbb="grunt buildbower"

# Homebrew utilities
alias brewup="brew update && brew upgrade"
alias brewupc="brew update && brew upgrade && brew cleanup"

# Network utilities
alias myip="curl ifconfig.co"
alias socksit="ssh -D 8080 keith"
alias flushdns="sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder;say dns cache flushed"

# Quick access to config files
alias zp="cursor ~/.zprofile"
alias sshconfig="cursor ~/.ssh/config"

# YouTube download utility
ytaudio() {
   yt-dlp -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 "$1"
}

# Move up X directories
up() {
   local d=""
   limit=$1
   for ((i=1 ; i <= limit ; i++))
   do
       d=$d/..
   done
   d=$(echo $d | sed 's/^\///')
   if [ -z "$d" ]; then
       d=..
   fi
   cd $d || return
}

# Chrome with proxy
chromeproxy() {
   ssh -N -D 9090 keith

   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
   --user-data-dir="$HOME/proxy-profile" \
   --proxy-server="socks5://localhost:9090"
}

# VSCode helper
code () {
   VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;
}

# Send to termbin
alias tb="nc termbin.com 9999"


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
   local site_name="$1"
   local skip_plugins=false

   # Parse options
   while [[ $# -gt 0 ]]; do
       case $1 in
           --skip-plugins)
               skip_plugins=true
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
   wp config set DISABLE_WP_CRON true --type=constant 2>/dev/null
   wp config set WP_MEMORY_LIMIT '512M' --type=constant 2>/dev/null
   wp config set WP_MAX_MEMORY_LIMIT '1024M' --type=constant 2>/dev/null
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
    local debug_log="wp_db_cleanup_debug.log"
    local wp_prefix=""
    local db_name=""
    local -A table_data
    local -a table_numbers

    # Debug logging function
    debug_log() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$debug_log"
    }

    # Initialize debug log
    echo "=== WordPress DB Cleanup Debug Log ===" > "$debug_log"
    debug_log "Starting wp_db_table_delete function"
    debug_log "Working directory: $(pwd)"

    echo "${BOLD}WordPress Database Table Cleanup${RESET}"
    echo "Debug log: ${BLUE}$debug_log${RESET}"

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

    # Create backup
    echo "\n${BOLD}STEP 1: CREATING BACKUP${RESET}"
    echo "$(printf '=%.0s' {1..60})"

    local backup_file="backup-before-cleanup-$(date +%Y-%m-%d-%H-%M-%S).sql"
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

    # Confirm deletion
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
