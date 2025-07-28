# Download uploads from a specified environment (staging or live) for the current site.
#
# This function must be executed from within a site's subdirectory under '~/Sites'.
# It downloads uploads from the specified environment (staging or live) using an SSH alias.
# If the '-latest' option is provided, only the uploads from the current and previous months are downloaded.
#
# Usage:
#   getups s           # Download all uploads from staging
#   getups l           # Download all uploads from live
#   getups s -latest   # Download only last 2 months from staging
#   getups l -latest   # Download only last 2 months from live
# Arguments:
#   $1 - Environment specifier ('s' for staging, 'l' for live).
#   $2 - Optional '-latest' flag to download only the last 2 months of uploads.
#
# Returns:
#   1 - If an error occurs (e.g., directory not found, missing arguments, SSH alias not found).
#   0 - On successful completion.
#
# Errors:
#   Displays error messages for various failure conditions such as incorrect directory,
#   missing arguments, or SSH connection issues.
getups() {
    current=${PWD##*/}

    if [ -z "$current" ] || [ ! -d ~/Sites/"$current" ]; then
        echo "Error: Must be run from within a Sites subdirectory"
        return 1
    fi

    if ! cd ~/Sites/"$current"/wp-content/uploads 2>/dev/null; then
        echo "Error: Directory ~/Sites/$current/wp-content/uploads does not exist"
        return 1
    fi

    if [ -z "$1" ]; then
        echo "Error: Missing required argument (s for staging, l for live)"
        return 1
    fi

    ssh_alias="$current-$1"

    if ! grep -q "^Host $ssh_alias$" ~/.ssh/config; then
        echo "Error: SSH alias '$ssh_alias' not found in ~/.ssh/config"
        return 1
    fi

    if [ "$2" = "-latest" ]; then
        current_year=$(date +%Y)
        current_month=$(date +%m)
        prev_month=$((current_month - 1))
        prev_year=$current_year

        if [ $prev_month -eq 0 ]; then
            prev_month=12
            prev_year=$((current_year - 1))
        fi

        printf -v current_month "%02d" $current_month
        printf -v prev_month "%02d" $prev_month

        if ssh -q "$ssh_alias" exit; then
            echo "Syncing uploads from $ssh_alias for $current_year/$current_month..."
            rsync -av --progress \
                --exclude "*.pdf" \
                --exclude "*.docx" \
                "$ssh_alias:~/www/wp-content/uploads/$current_year/$current_month/" \
                "./$current_year/$current_month/"

            echo "Syncing uploads from $ssh_alias for $prev_year/$prev_month..."
            rsync -av --progress \
                --exclude "*.pdf" \
                --exclude "*.docx" \
                "$ssh_alias:~/www/wp-content/uploads/$prev_year/$prev_month/" \
                "./$prev_year/$prev_month/"
        else
            echo "Error: Could not connect to '$ssh_alias'. Please check your SSH configuration."
            return 1
        fi
    else
        if ssh -q "$ssh_alias" exit; then
            echo "Syncing all uploads from $ssh_alias..."
            rsync -av --progress \
                --exclude "*.pdf" \
                --exclude "*.docx" \
                "$ssh_alias:~/www/wp-content/uploads/" .
        else
            echo "Error: Could not connect to '$ssh_alias'. Please check your SSH configuration."
            return 1
        fi
    fi

    cd ~/Sites/"$current"/wp-content/themes/"$current" || return 1
}

# Push uploads to remote server (staging or production)
#
# Options:
#   -auto   : Automatically determine the SSH alias and site directory based on the current working directory.
#            Must be run from within a valid site directory (~/Sites/[site-directory])
#   -target : Specify the deployment target, either 'staging' (default) or 'production'
#
# Directory Structure:
#   ~/Sites/[site-directory]/wp-content/uploads
#
# Examples:
#   pushups              # Push to staging, prompts for SSH alias and site directory. Can be run from anywhere
#   pushups -auto        # Auto-push to staging using current directory name. Must be run from site directory
#   pushups -target l    # Push to production, prompts for SSH alias and site directory. Can be run from anywhere
#   pushups -auto -l     # Auto-push to production using current directory name. Must be run from site directory
pushups() {
    auto=false
    target="s"  # Default to staging

    while [ "$1" != "" ]; do
        case $1 in
            -auto )    auto=true
                      shift
                      ;;
            -target ) shift
                     if [ "l" = "$1" ] || [ "s" = "$1" ]; then
                         target="$1"
                     else
                         echo "Error: -target must be either 's' or 'l'"
                         return 1
                     fi
                     shift
                     ;;
            * )       shift
                     ;;
        esac
    done

    if [ true = "$auto" ]; then
        # Check if we're in a valid site directory when using -auto
        if [[ ! "$PWD" =~ ^"$HOME/Sites/" ]]; then
            echo "Error: -auto flag must be run from within a site directory (~/Sites/[site-directory])"
            return 1
        fi
        current=${PWD##*/}
        sshalias="${current}-${target}"
        sitedir="$current"
    else
        echo "Enter SSH alias to deploy to (without -s/-l suffix):"
        read -r sitename
        echo "Enter site directory name:"
        read -r sitedir
        sshalias="${sitename}-${target}"
    fi

    # Add confirmation for production deployments
    if [ "l" = "$target" ]; then
        echo "⚠️  WARNING: You are about to push to PRODUCTION for $sshalias"
        echo "Are you sure you want to continue? (y/N)"
        read -r confirm
        if [ ! "$confirm" = "y" ] && [ ! "$confirm" = "Y" ]; then
            echo "Deployment cancelled"
            return 1
        fi
    fi

    if [ ! -d ~/Sites/"${sitedir}"/wp-content/uploads ]; then
        echo "Error: Uploads directory not found at ~/Sites/${sitedir}/wp-content/uploads"
        return 1
    fi

    echo "Pushing uploads to $sshalias..."
    cd ~/Sites/"${sitedir}"/wp-content/uploads || return
    rsync -avzW --progress * "$sshalias:~/www/wp-content/uploads"
}

# WP-CLI with PHP 7.4
wp74() {
    /opt/homebrew/Cellar/php@7.4/7.4.33_5/bin/php /usr/local/bin/wp "$@"
}

# Check for missing featured images
check-featured-image() {
    wp db query "SELECT ID FROM $(wp db prefix)posts WHERE post_type='post' AND post_status='publish' AND ID NOT IN (SELECT post_id FROM $(wp db prefix)postmeta WHERE meta_key='_thumbnail_id');" --skip-column-names
}

# Generate lorem ipsum content
genlorem(){
    curl "https://loripsum.net/api/5/medium/link/ul/ol/bq/headers/prude" | wp post generate --post_type="$2" --count="$1" --post_content;
}

# Common WP-CLI aliases

# Update user password to 'dmcweb'. Defaults to 'admin' user ID.
dmcweb() {
    local user_id=${1:-admin}
    wp user update "$user_id" --user_pass=dmcweb
}
alias updatem="wp plugin update --all;wp theme update --all; wp core update"
alias siteurl="wp db query 'SELECT * FROM wp_options WHERE option_name=\"siteurl\"' --skip-column-names"
alias plugincheck="wp plugin list --field=name | xargs -n1 -I % wp --skip-plugins=% plugin get % --field=name"
alias onetimeinstall="wp @prod plugin install one-time-login --activate"
alias onetimeadmin="wp user one-time-login admin"

# Scaffold functions
gencpt(){
    wp scaffold post-type $1 --label="$2" --textdomain=dmcstarter --theme --force
}

genctax(){
    wp scaffold taxonomy $1 --post_types=$2 --label="$3" --textdomain=dmcstarter --theme --force
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
    # Define array of host entries matching SSH config aliases
    local hosts=("aquacorp-l" "aussie-l" "registrars-l" "cem-l" "colac-l" "dpm-l" "hisense-l" "pelican-l" "pricing-l" "rippercorp-l" "advocate-l" "toshiba-l")
    local exit_status=0

    # Loop through each host to run the WooCommerce update command
    for host in "${hosts[@]}"; do
        echo "Connecting to $host..."

        # First verify SSH connection
        if ! ssh -q "$host" exit; then
            echo "Error: Could not connect to '$host'. Skipping..."
            exit_status=1
            continue
        fi

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

# WordPress Plugin Fatal Error Diagnostic Function
#
# Purpose: Systematically test individual plugins to isolate fatal error issues
# Usage: wp_plugin_diagnostics (run from WordPress root directory)
#
# What it does:
# 1. Auto-detects site URL using wp-cli (wp option get home)
# 2. Auto-detects all currently active plugins using wp-cli
# 3. Tests each plugin individually by deactivating it
# 4. Clears debug log and makes a site request
# 5. Checks for fatal memory errors in wp-content/debug.log
# 6. Reactivates the plugin and moves to the next one
# 7. Saves detailed output to timestamped log file
#
# Key Features:
# - Fully automatic detection (site URL + active plugins)
# - Configurable skip list for critical plugins
# - Interactive mode - stops when culprit is found
# - Logging to both terminal and file
#
# Output: plugin_memory_test_YYYYMMDD_HHMMSS.txt with full test results
wp_plugin_diags() {
    # Create output file with timestamp
    local output_file="plugin_memory_test_$(date +%Y%m%d_%H%M%S).txt"

    # Function to output to both terminal and file
    output() {
        echo "$@" | tee -a "$output_file"
    }

    # Configuration
    local log_file="wp-content/debug.log"

    # Colours for output (only for terminal)
    local red='\033[0;31m'
    local green='\033[0;32m'
    local yellow='\033[1;33m'
    local nc='\033[0m'

    # Plugins to skip (add plugin names here that should never be tested)
    local skip_plugins="wordfence akismet updraftplus"

    # Function to print coloured output
    print_status() {
        local colour=$1
        local message=$2
        echo -e "${colour}${message}${nc}" | tee -a "$output_file"
    }

    # Initialize output file
    echo "WordPress Plugin Memory Error Testing Script Output" > "$output_file"
    echo "Generated: $(date)" >> "$output_file"
    echo "========================================" >> "$output_file"

    # Check if we're in a WordPress directory
    if [[ ! -f "wp-config.php" ]]; then
        print_status $red "Error: This script must be run from the WordPress root directory"
        return 1
    fi

    print_status $yellow "Starting WordPress plugin memory error testing..."
    output "Output will be saved to: $output_file"

    # Check wp-cli availability first
    if ! command -v wp &> /dev/null; then
        print_status $red "Error: wp-cli is not installed or not in PATH"
        print_status $yellow "Please install wp-cli: https://wp-cli.org/"
        return 1
    fi

    # Auto-detect site URL using wp-cli
    output "Detecting site URL..."
    local site_url
    site_url=$(wp option get home 2>/dev/null)
    if [[ -z "$site_url" ]]; then
        print_status $red "Error: Could not retrieve site URL"
        print_status $yellow "Make sure wp-cli is working: wp option get home"
        return 1
    fi

    print_status $yellow "Site URL: $site_url"
    print_status $yellow "Log file: $log_file"
    output ""

    # Auto-detect active plugins using wp-cli
    output "Detecting active plugins..."

    # Get list of active plugins
    local plugins
    plugins=$(wp plugin list --status=active --field=name 2>/dev/null)
    if [[ -z "$plugins" ]]; then
        print_status $red "Error: Could not retrieve active plugins list"
        print_status $yellow "Make sure wp-cli is working: wp plugin list"
        return 1
    fi

    # Convert to array and filter out skipped plugins
    local plugins_array=()
    local skip_array=(${=skip_plugins})

    # Convert newline-separated plugin list to array
    while IFS= read -r plugin; do
        [[ -n "$plugin" ]] || continue

        # Check if plugin should be skipped
        local skip_plugin=false
        for skip in "${skip_array[@]}"; do
            if [[ "$plugin" == "$skip" ]]; then
                output "⏭️  Skipping plugin: $plugin (in skip list)"
                skip_plugin=true
                break
            fi
        done

        if [[ "$skip_plugin" == false ]]; then
            plugins_array+=("$plugin")
        fi
    done <<< "$plugins"

    # Display detected plugins
    output "Found ${#plugins_array[@]} active plugins to test:"
    for plugin in "${plugins_array[@]}"; do
        output "  - $plugin"
    done
    output ""

    # Explain what we're looking for
    print_status $yellow "🔍 What this script detects:"
    output "  • Fatal memory errors: 'Allowed memory size of X bytes exhausted'"
    output "  • PHP fatal errors: 'PHP Fatal error' messages"
    output "  • Memory-related crashes that prevent site loading"
    output ""
    output "✅ Success criteria: Site loads without fatal errors when plugin is deactivated"
    output "❌ Problem identified: Fatal errors disappear when specific plugin is deactivated"
    output ""

    # Pre-check: Verify there's actually a fatal error to solve
    print_status $yellow "🔬 Pre-check: Testing site with all plugins active..."
    output "Clearing debug log..."
    rm "$log_file" 2>/dev/null && touch "$log_file"

    output "Making test request to site..."
    if curl -s --max-time 10 --connect-timeout 5 --insecure "$site_url" > /dev/null 2>&1; then
        output "Site request successful"

        # Wait for logs to be written
        sleep 1

        # Check for fatal errors
        if ! grep -q "Fatal error" "$log_file" 2>/dev/null; then
            print_status $green "✅ No fatal errors found!"
            output ""
            output "The site is currently working fine with all plugins active."
            output "This script is designed to isolate plugins causing fatal errors."
            output ""
            print_status $yellow "Possible reasons:"
            output "  • The issue has already been resolved"
            output "  • The error only occurs under specific conditions"
            output "  • The error is intermittent"
            output "  • The error is theme-related, not plugin-related"
            output ""
            output "If you're still experiencing issues, try:"
            output "  • Access different pages of your site"
            output "  • Check wp-content/debug.log manually"
            output "  • Use other diagnostic scripts in this directory"
            output ""
            output "Full output saved to: $output_file"
            return 0
        else
            print_status $red "❌ Fatal errors detected!"
            output "Error details:"
            grep "Fatal error" "$log_file" 2>/dev/null | head -3 | while read -r error_line; do
                output "  $error_line"
            done
            output ""
            print_status $yellow "Proceeding with plugin isolation testing..."
            output ""
        fi
    else
        print_status $red "⚠️  Could not reach site - proceeding with testing anyway"
        output "This might indicate a severe error that prevents site loading"
        output ""
    fi

    for plugin in "${plugins_array[@]}"; do
        output "Testing plugin: $plugin"

        # Deactivate plugin
        output "  → Deactivating plugin..."
        if wp plugin deactivate "$plugin" --quiet 2>/dev/null; then
            output "  → Plugin deactivated successfully"

            # Clear log file
            output "  → Clearing log file..."
            rm "$log_file" 2>/dev/null && touch "$log_file"
            output "  → Log file cleared successfully"

            # Wait a moment for any pending operations
            output "  → Waiting 2 seconds for changes to take effect..."
            sleep 2
            output "  → Wait complete"

            # Make request to site
            output "  → Making request to site ($site_url)..."

            if curl -s --max-time 10 --connect-timeout 5 --insecure "$site_url" > /dev/null 2>&1; then
                output "  → Site request successful"

                # Wait a moment for logs to be written
                sleep 1

                # Check for fatal errors in log
                output "  → Checking log file for fatal errors..."
                if ! grep -q "Fatal error" "$log_file" 2>/dev/null; then
                    print_status $green "✅ Fatal error GONE when $plugin is deactivated. This is the culprit!"

                    # Ask if user wants to stop here
                    print_status $yellow "Found the problematic plugin: $plugin"
                    echo "Would you like to stop testing here? (y/n): "
                    read -r response
                    output "User response: $response"
                    if [[ "$response" =~ ^[Yy]$ ]]; then
                        print_status $yellow "Testing stopped at user request"
                        output "Plugin causing issues: $plugin"
                        # Reactivate the plugin before exiting
                        output "Reactivating problematic plugin..."
                        wp plugin activate "$plugin" --quiet 2>/dev/null
                        output "Full output saved to: $output_file"
                        return 0
                    fi
                else
                    print_status $red "❌ Fatal error still present with $plugin deactivated"
                    output "  → Error details:"
                    grep "Fatal error" "$log_file" 2>/dev/null | head -2 | while read -r error_line; do
                        output "    $error_line"
                    done
                fi
            else
                print_status $yellow "⚠️  Could not reach site or request failed"
            fi

            # Reactivate plugin
            output "  → Reactivating plugin..."
            if wp plugin activate "$plugin" --quiet 2>/dev/null; then
                output "  → Plugin reactivated successfully"
            else
                print_status $red "Warning: Could not reactivate plugin '$plugin'"
            fi
        else
            print_status $red "Error: Could not deactivate plugin '$plugin'"
        fi

        output "---------------------------------"
    done

    print_status $yellow "Testing complete!"
    output "Full output saved to: $output_file"
}