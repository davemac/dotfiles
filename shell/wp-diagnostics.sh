# WordPress Diagnostics & Troubleshooting Functions
#
# This file contains functions for diagnosing and troubleshooting
# WordPress issues, performance problems, and plugin conflicts.

# WordPress Plugin Fatal Error Diagnostic Function
#
# Purpose: Systematically test individual plugins to isolate fatal error issues
# Usage: wp_plugin_diags (run from WordPress root directory)
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
    # Check if we're in a WordPress directory first
    if [[ ! -f "wp-config.php" ]]; then
        echo -e "\033[0;31mError: This script must be run from the WordPress root directory\033[0m"
        return 1
    fi

    # Create output file with timestamp in current directory (site root)
    local output_file="$(pwd)/plugin_memory_test_$(date +%Y%m%d_%H%M%S).txt"

    # Function to output to both terminal and file
    output() {
        echo "$@" | tee -a "$output_file"
    }

    # Configuration - use absolute path for log file
    local log_file="$(pwd)/wp-content/debug.log"

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
    echo "Working directory: $(pwd)" >> "$output_file"
    echo "========================================" >> "$output_file"

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
            output "  • Use other diagnostic scripts"
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