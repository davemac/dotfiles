# =============================================================================
# Cloudflare Management Functions
#
# Tools for managing Cloudflare zone settings including performance
# optimisation and configuration verification.
#
# =============================================================================
# FUNCTION INDEX
# =============================================================================
#
# Main Functions:
# * cf-opt                       - Apply performance and security optimisations
# * cf-opt DOMAIN                - Batch mode (non-interactive)
# * cf-opt DOMAIN SITE_PATH      - Batch mode with logging
# * cf-check                     - Check current Cloudflare settings
# * cf-help                      - Show available Cloudflare commands
#
# Configuration:
# * API Token: Stored in .dotfiles-config as CF_API_TOKEN (or prompted)
# * Zone Selection: Lists all zones, select by number or domain name
# * Batch Mode: Pass domain as argument to skip all prompts
# * Token requires: Zone Settings, Cache Rules, Cache Purge, Argo Smart Routing
#
# Logging:
# * cf-opt writes a log file to the site's root directory
# * Log filename: cloudflare-optimisation-YYYY-MM-DD-HHMMSS.log
#
# Features:
# * Applies performance settings (HTTP/3, Early Hints, Tiered Cache, etc.)
# * Configures security (SSL Strict, TLS 1.3)
# * Sets up cache rules for static assets and WooCommerce bypass
# * Purges cache and tests cache headers with analysis
#
# Dependencies:
# * curl, jq, load_dotfiles_config (from config.sh)
#
# =============================================================================

# -----------------------------------------------------------------------------
# Helper: Auto-detect site path from current directory
# Returns the site root if within ~/Sites/, empty string otherwise
# -----------------------------------------------------------------------------
_cf_auto_detect_site_path() {
    local current_dir="$(pwd)"
    local sites_dir="$HOME/Sites"

    if [[ "$current_dir" == "$sites_dir"/* ]]; then
        local relative_path="${current_dir#$sites_dir/}"
        local site_name="${relative_path%%/*}"
        echo "$sites_dir/$site_name"
    else
        echo ""
    fi
}

# -----------------------------------------------------------------------------
# Helper: Get site path for logging
# Prompts user or auto-detects from current directory
# Usage: _cf_get_site_path [BATCH_MODE] [SITE_PATH]
#   BATCH_MODE: "batch" to skip prompts
#   SITE_PATH: Optional explicit path (batch mode only)
# -----------------------------------------------------------------------------
_cf_get_site_path() {
    local batch_mode="$1"
    local explicit_path="$2"
    local auto_path=$(_cf_auto_detect_site_path)

    if [[ "$batch_mode" == "batch" ]]; then
        # Batch mode: use explicit path, auto-detect, or skip
        if [[ -n "$explicit_path" ]]; then
            CF_SITE_PATH="${explicit_path/#\~/$HOME}"
            if [[ ! -d "$CF_SITE_PATH" ]]; then
                echo "Warning: Directory does not exist: $CF_SITE_PATH (skipping logging)"
                CF_SITE_PATH=""
            else
                echo "Using site path: $CF_SITE_PATH"
            fi
        elif [[ -n "$auto_path" ]]; then
            CF_SITE_PATH="$auto_path"
            echo "Auto-detected site path: $CF_SITE_PATH"
        else
            echo "No site path provided (skipping logging)"
            CF_SITE_PATH=""
        fi
        return 0
    fi

    # Interactive mode
    if [[ -n "$auto_path" ]]; then
        echo "Detected site directory: $auto_path"
        echo "Use this for logging? [Y/n]"
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            echo "Enter site directory path:"
            read -r CF_SITE_PATH
        else
            CF_SITE_PATH="$auto_path"
        fi
    else
        echo "Enter site directory path for logging (or press Enter to skip logging):"
        read -r CF_SITE_PATH
    fi

    # Expand tilde to home directory
    if [[ -n "$CF_SITE_PATH" ]]; then
        CF_SITE_PATH="${CF_SITE_PATH/#\~/$HOME}"
    fi

    if [[ -n "$CF_SITE_PATH" && ! -d "$CF_SITE_PATH" ]]; then
        echo "Warning: Directory does not exist: $CF_SITE_PATH"
        echo "Continue without logging? [Y/n]"
        read -r response
        if [[ "$response" =~ ^[Nn]$ ]]; then
            return 1
        fi
        CF_SITE_PATH=""
    fi

    return 0
}

# -----------------------------------------------------------------------------
# Helper: Write to log file and stdout
# Usage: _cf_log "message"
# -----------------------------------------------------------------------------
_cf_log() {
    local message="$1"
    echo "$message"
    if [[ -n "$CF_LOG_FILE" ]]; then
        echo "$message" >> "$CF_LOG_FILE"
    fi
}

# -----------------------------------------------------------------------------
# Helper: Test cache headers for a zone
# Usage: _cf_test_cache_headers ZONE_ID API_TOKEN [BATCH_MODE]
#   BATCH_MODE: "batch" to skip prompts and use domain homepage
# -----------------------------------------------------------------------------
_cf_test_cache_headers() {
    local zone_id="$1"
    local api_token="$2"
    local batch_mode="$3"

    # Track results for analysis
    local page_status1=""
    local page_status2=""
    local static_status1=""
    local static_status2=""

    # Get zone name for URL
    local zone_info=$(_cf_api GET "/zones/$zone_id" "" "$zone_id" "$api_token")
    local zone_name=$(echo "$zone_info" | jq -r '.result.name')
    local test_url="https://$zone_name"

    if [[ "$batch_mode" != "batch" ]]; then
        echo "Enter URL to test (press Enter for $test_url):"
        read -r custom_url
        if [[ -n "$custom_url" ]]; then
            test_url="$custom_url"
        fi
    fi

    _cf_log ""
    _cf_log "Testing cache headers for: $test_url"
    _cf_log ""

    # First request (should be MISS or DYNAMIC)
    _cf_log "  Request 1 (expecting MISS or DYNAMIC):"
    local headers1=$(curl -sI -L "$test_url" 2>/dev/null | grep -i "cf-cache-status")
    page_status1=$(echo "$headers1" | grep -oiE '(HIT|MISS|DYNAMIC|BYPASS|EXPIRED|STALE|REVALIDATED)' | head -1 | tr '[:lower:]' '[:upper:]')
    if [[ -n "$headers1" ]]; then
        _cf_log "    $headers1"
    else
        _cf_log "    No cf-cache-status header found (page may not be cacheable)"
    fi

    # Second request (should be HIT if cacheable)
    sleep 1
    _cf_log "  Request 2 (expecting HIT if cacheable):"
    local headers2=$(curl -sI -L "$test_url" 2>/dev/null | grep -i "cf-cache-status")
    page_status2=$(echo "$headers2" | grep -oiE '(HIT|MISS|DYNAMIC|BYPASS|EXPIRED|STALE|REVALIDATED)' | head -1 | tr '[:lower:]' '[:upper:]')
    if [[ -n "$headers2" ]]; then
        _cf_log "    $headers2"
    else
        _cf_log "    No cf-cache-status header found"
    fi

    # Check a static asset if available
    _cf_log ""
    _cf_log "  Testing static asset (CSS/JS/image):"

    # Try to find a static asset URL from the page
    local page_content=$(curl -sL "$test_url" 2>/dev/null)
    local static_url=$(echo "$page_content" | grep -oE 'href="[^"]+\.css[^"]*"' | head -1 | sed 's/href="//;s/"//')

    if [[ -z "$static_url" ]]; then
        static_url=$(echo "$page_content" | grep -oE 'src="[^"]+\.(js|png|jpg|jpeg|webp)[^"]*"' | head -1 | sed 's/src="//;s/"//')
    fi

    if [[ -n "$static_url" ]]; then
        # Make URL absolute if relative
        if [[ "$static_url" != http* ]]; then
            if [[ "$static_url" == /* ]]; then
                static_url="https://$zone_name$static_url"
            else
                static_url="https://$zone_name/$static_url"
            fi
        fi

        _cf_log "    URL: $static_url"

        # First request
        local static_headers1=$(curl -sI -L "$static_url" 2>/dev/null | grep -i "cf-cache-status")
        static_status1=$(echo "$static_headers1" | grep -oiE '(HIT|MISS|DYNAMIC|BYPASS|EXPIRED|STALE|REVALIDATED)' | head -1 | tr '[:lower:]' '[:upper:]')
        _cf_log "    Request 1: ${static_headers1:-No cf-cache-status header}"

        sleep 1

        # Second request
        local static_headers2=$(curl -sI -L "$static_url" 2>/dev/null | grep -i "cf-cache-status")
        static_status2=$(echo "$static_headers2" | grep -oiE '(HIT|MISS|DYNAMIC|BYPASS|EXPIRED|STALE|REVALIDATED)' | head -1 | tr '[:lower:]' '[:upper:]')
        _cf_log "    Request 2: ${static_headers2:-No cf-cache-status header}"
    else
        _cf_log "    Could not find static asset to test"
    fi

    # -------------------------------------------------------------------------
    # Analysis
    # -------------------------------------------------------------------------
    _cf_log ""
    _cf_log "=== ANALYSIS ==="
    _cf_log ""

    local issues_found=false

    # Analyse HTML page caching
    _cf_log "HTML Page:"
    if [[ "$page_status1" == "DYNAMIC" || "$page_status2" == "DYNAMIC" ]]; then
        _cf_log "  Status: DYNAMIC (not cached - this is normal for HTML)"
        _cf_log "  HTML pages are typically not cached to ensure fresh content."
    elif [[ "$page_status2" == "HIT" ]]; then
        _cf_log "  Status: CACHED (HIT on second request)"
        _cf_log "  Your HTML pages are being cached at the edge."
    elif [[ "$page_status1" == "MISS" && "$page_status2" == "MISS" ]]; then
        _cf_log "  Status: NOT CACHING (MISS on both requests)"
        _cf_log "  Page may have cache-control headers preventing caching."
        issues_found=true
    elif [[ -z "$page_status1" && -z "$page_status2" ]]; then
        _cf_log "  Status: UNKNOWN (no cf-cache-status header)"
        _cf_log "  Site may not be proxied through Cloudflare (DNS only?)."
        issues_found=true
    else
        _cf_log "  Status: $page_status1 -> $page_status2"
    fi

    _cf_log ""

    # Analyse static asset caching
    _cf_log "Static Assets:"
    if [[ -z "$static_status1" && -z "$static_status2" ]]; then
        if [[ -z "$static_url" ]]; then
            _cf_log "  Status: Could not test (no static assets found)"
        else
            _cf_log "  Status: UNKNOWN (no cf-cache-status header)"
            _cf_log "  Static assets may not be proxied through Cloudflare."
            issues_found=true
        fi
    elif [[ "$static_status2" == "HIT" ]]; then
        _cf_log "  Status: WORKING (HIT on second request)"
        _cf_log "  Static assets are being cached at the Cloudflare edge."
    elif [[ "$static_status1" == "MISS" && "$static_status2" == "HIT" ]]; then
        _cf_log "  Status: WORKING (MISS then HIT - cache warming)"
        _cf_log "  Static assets are being cached correctly."
    elif [[ "$static_status1" == "HIT" && "$static_status2" == "HIT" ]]; then
        _cf_log "  Status: WORKING (HIT on both requests)"
        _cf_log "  Static assets are already cached at the edge."
    elif [[ "$static_status2" == "BYPASS" ]]; then
        _cf_log "  Status: BYPASSED"
        _cf_log "  Cache is being bypassed - check for cookies or query strings."
        issues_found=true
    else
        _cf_log "  Status: $static_status1 -> $static_status2"
        if [[ "$static_status2" != "HIT" ]]; then
            issues_found=true
        fi
    fi

    _cf_log ""

    # Overall verdict
    if [[ "$issues_found" == true ]]; then
        _cf_log "VERDICT: Potential issues detected - review above"
    else
        _cf_log "VERDICT: Cloudflare caching appears to be working correctly"
    fi

    _cf_log ""
    _cf_log "Cache status reference:"
    _cf_log "  HIT     = Served from Cloudflare edge cache"
    _cf_log "  MISS    = Fetched from origin, now cached"
    _cf_log "  DYNAMIC = Not cacheable (HTML pages often show this)"
    _cf_log "  BYPASS  = Cache bypassed (cookies, query strings, etc.)"
}

# -----------------------------------------------------------------------------
# Helper function for Cloudflare API calls
# Usage: _cf_api METHOD ENDPOINT [DATA]
# -----------------------------------------------------------------------------
_cf_api() {
    local method=$1
    local endpoint=$2
    local data=$3
    local zone_id=$4
    local api_token=$5

    if [[ -n "$data" ]]; then
        curl -s -X "$method" \
            "https://api.cloudflare.com/client/v4$endpoint" \
            -H "Authorization: Bearer $api_token" \
            -H "Content-Type: application/json" \
            -d "$data"
    else
        curl -s -X "$method" \
            "https://api.cloudflare.com/client/v4$endpoint" \
            -H "Authorization: Bearer $api_token" \
            -H "Content-Type: application/json"
    fi
}

# -----------------------------------------------------------------------------
# Prompt for Cloudflare credentials
# Uses CF_API_TOKEN from .dotfiles-config if available
# Lists zones and lets user select by domain name or number
# Returns zone_id and api_token via global variables
# -----------------------------------------------------------------------------
_cf_get_credentials() {
    # Load config to get API token if available
    load_dotfiles_config 2>/dev/null || true

    # Check if API token is in config
    if [[ -n "$CF_API_TOKEN" ]]; then
        echo "Using API token from .dotfiles-config"
    else
        echo "Cloudflare API Token:"
        read -s CF_API_TOKEN
        echo ""

        if [[ -z "$CF_API_TOKEN" ]]; then
            echo "Error: API Token is required"
            return 1
        fi
    fi

    # Fetch list of zones
    echo "Fetching zones..."
    local zones_result=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones?per_page=50" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    if ! echo "$zones_result" | jq -e '.success == true' > /dev/null 2>&1; then
        local error_msg=$(echo "$zones_result" | jq -r '.errors[0].message // "Unknown error"')
        echo "Error: Failed to fetch zones - $error_msg"
        return 1
    fi

    # Parse zones into arrays
    local -a zone_ids
    local -a zone_names
    local i=1

    while IFS= read -r line; do
        local zid=$(echo "$line" | cut -d'|' -f1)
        local zname=$(echo "$line" | cut -d'|' -f2)
        zone_ids+=("$zid")
        zone_names+=("$zname")
    done < <(echo "$zones_result" | jq -r '.result[] | "\(.id)|\(.name)"')

    local zone_count=${#zone_names[@]}

    if [[ $zone_count -eq 0 ]]; then
        echo "Error: No zones found for this API token"
        return 1
    fi

    # Display zones
    echo ""
    echo "Available zones:"
    for ((i=1; i<=zone_count; i++)); do
        echo "  $i) ${zone_names[$i]}"
    done
    echo ""

    # Let user select
    echo "Enter zone number or domain name:"
    read -r zone_selection

    # Check if it's a number
    if [[ "$zone_selection" =~ ^[0-9]+$ ]]; then
        if [[ $zone_selection -ge 1 && $zone_selection -le $zone_count ]]; then
            CF_ZONE_ID="${zone_ids[$zone_selection]}"
            echo "Selected: ${zone_names[$zone_selection]}"
        else
            echo "Error: Invalid zone number"
            return 1
        fi
    else
        # Search by domain name
        local found=false
        for ((i=1; i<=zone_count; i++)); do
            if [[ "${zone_names[$i]}" == "$zone_selection" ]]; then
                CF_ZONE_ID="${zone_ids[$i]}"
                echo "Selected: ${zone_names[$i]}"
                found=true
                break
            fi
        done

        if [[ "$found" == false ]]; then
            # Try partial match
            for ((i=1; i<=zone_count; i++)); do
                if [[ "${zone_names[$i]}" == *"$zone_selection"* ]]; then
                    CF_ZONE_ID="${zone_ids[$i]}"
                    echo "Selected: ${zone_names[$i]}"
                    found=true
                    break
                fi
            done
        fi

        if [[ "$found" == false ]]; then
            echo "Error: Zone not found: $zone_selection"
            return 1
        fi
    fi

    echo ""
    return 0
}

# -----------------------------------------------------------------------------
# Batch mode: Get credentials using domain name (non-interactive)
# Usage: _cf_get_credentials_batch DOMAIN_NAME
# Returns 0 on success, sets CF_ZONE_ID and CF_API_TOKEN
# -----------------------------------------------------------------------------
_cf_get_credentials_batch() {
    local domain_name="$1"

    # Load config to get API token
    load_dotfiles_config 2>/dev/null || true

    if [[ -z "$CF_API_TOKEN" ]]; then
        echo "Error: CF_API_TOKEN not found in .dotfiles-config"
        echo "Add it with: echo 'CF_API_TOKEN=\"your-token\"' >> ~/.dotfiles-config"
        return 1
    fi

    echo "Using API token from .dotfiles-config"

    # Fetch list of zones
    echo "Fetching zones..."
    local zones_result=$(curl -s -X GET \
        "https://api.cloudflare.com/client/v4/zones?per_page=50" \
        -H "Authorization: Bearer $CF_API_TOKEN" \
        -H "Content-Type: application/json")

    if ! echo "$zones_result" | jq -e '.success == true' > /dev/null 2>&1; then
        local error_msg=$(echo "$zones_result" | jq -r '.errors[0].message // "Unknown error"')
        echo "Error: Failed to fetch zones - $error_msg"
        return 1
    fi

    # Find zone by exact match first, then partial match
    CF_ZONE_ID=$(echo "$zones_result" | jq -r --arg domain "$domain_name" \
        '.result[] | select(.name == $domain) | .id // empty')

    if [[ -z "$CF_ZONE_ID" ]]; then
        # Try partial match
        CF_ZONE_ID=$(echo "$zones_result" | jq -r --arg domain "$domain_name" \
            '.result[] | select(.name | contains($domain)) | .id' | head -1)
    fi

    if [[ -z "$CF_ZONE_ID" ]]; then
        echo "Error: Zone not found for domain: $domain_name"
        echo "Available zones:"
        echo "$zones_result" | jq -r '.result[] | "  - \(.name)"'
        return 1
    fi

    local zone_name=$(echo "$zones_result" | jq -r --arg id "$CF_ZONE_ID" \
        '.result[] | select(.id == $id) | .name')
    echo "Selected zone: $zone_name"
    echo ""

    return 0
}

# -----------------------------------------------------------------------------
# cf-opt: Apply Cloudflare performance and security optimisations
#
# Usage:
#   cf-opt                           # Interactive mode
#   cf-opt DOMAIN                    # Batch mode (non-interactive)
#   cf-opt DOMAIN SITE_PATH          # Batch mode with logging
#
# Batch mode auto-defaults:
#   - Proceed confirmation → Yes
#   - Purge cache → Yes
#   - Test cache headers → Yes
#   - Test URL → Domain homepage
#
# Configures:
# - Performance: HTTP/3, 0-RTT, Early Hints, Auto Minify, Always Online
# - Security: SSL Strict, TLS 1.3, Min TLS 1.2, HTTPS Rewrites
# - Caching: Static assets, WooCommerce bypass, images, CSS/JS/fonts
#
# Logging:
# - Writes a timestamped log to the site's root directory
# -----------------------------------------------------------------------------
cf-opt() {
    # Reset global variables
    CF_LOG_FILE=""
    CF_SITE_PATH=""

    # Check for batch mode (domain passed as argument)
    local batch_mode=""
    local batch_domain=""
    local batch_site_path=""

    if [[ -n "$1" ]]; then
        batch_mode="batch"
        batch_domain="$1"
        batch_site_path="$2"
        echo "Cloudflare Performance Optimisation (Batch Mode)"
        echo "================================================="
        echo ""
        echo "Domain: $batch_domain"
        if [[ -n "$batch_site_path" ]]; then
            echo "Site path: $batch_site_path"
        fi
        echo ""
    else
        echo "Cloudflare Performance Optimisation"
        echo "===================================="
        echo ""
        echo "This script will apply the following settings to your Cloudflare zone:"
        echo ""
        echo "PERFORMANCE SETTINGS:"
        echo "  - HTTP/3 (QUIC)              -> ON"
        echo "  - 0-RTT Connection Resumption -> ON (Pro plan required)"
        echo "  - Early Hints                -> ON"
        echo "  - Auto Minify (CSS/HTML/JS)  -> ON"
        echo "  - Always Online              -> ON"
        echo "  - WebSockets                 -> ON"
        echo "  - Opportunistic Encryption   -> ON"
        echo "  - Browser Cache TTL          -> Respect existing headers"
        echo "  - Tiered Cache               -> ON (improves TTFB)"
        echo ""
        echo "SECURITY SETTINGS:"
        echo "  - SSL Mode                   -> Full (Strict)"
        echo "  - TLS 1.3                    -> ON"
        echo "  - Minimum TLS Version        -> 1.2"
        echo "  - Automatic HTTPS Rewrites   -> ON"
        echo ""
        echo "CACHE RULES (will create/update):"
        echo "  - Static assets (uploads/themes/includes) -> 1 month edge, 1 week browser"
        echo "  - CSS, JS, fonts                          -> 1 month edge, 1 week browser"
        echo "  - Images (jpg/png/gif/webp/avif/svg/ico)  -> 1 month edge & browser"
        echo "  - WooCommerce (cart/checkout/my-account)  -> Bypass cache"
        echo ""
        echo "===================================="
        echo ""
        echo "Do you want to proceed? [y/N]"
        read -r response

        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            echo "Cancelled."
            return 0
        fi

        echo ""
    fi

    # Get site path for logging
    if ! _cf_get_site_path "$batch_mode" "$batch_site_path"; then
        return 1
    fi

    # Initialize log file if site path provided
    if [[ -n "$CF_SITE_PATH" ]]; then
        local timestamp=$(date +"%Y-%m-%d-%H%M%S")
        CF_LOG_FILE="$CF_SITE_PATH/cloudflare-optimisation-$timestamp.log"
        echo "Log file: $CF_LOG_FILE"
        echo ""

        # Write log header
        echo "# Cloudflare Optimisation Log" > "$CF_LOG_FILE"
        echo "# Date: $(date)" >> "$CF_LOG_FILE"
        echo "# Site: $CF_SITE_PATH" >> "$CF_LOG_FILE"
        echo "#" >> "$CF_LOG_FILE"
        echo "" >> "$CF_LOG_FILE"
    fi

    # Get credentials
    if [[ "$batch_mode" == "batch" ]]; then
        if ! _cf_get_credentials_batch "$batch_domain"; then
            return 1
        fi
    else
        if ! _cf_get_credentials; then
            return 1
        fi
    fi

    local zone_id="$CF_ZONE_ID"
    local api_token="$CF_API_TOKEN"

    # Log zone info
    if [[ -n "$CF_LOG_FILE" ]]; then
        echo "Zone ID: $zone_id" >> "$CF_LOG_FILE"
        echo "" >> "$CF_LOG_FILE"
    fi

    # -------------------------------------------------------------------------
    # 1. ZONE SETTINGS - Speed & Performance
    # -------------------------------------------------------------------------
    _cf_log "Configuring Zone Settings..."
    _cf_log ""

    # Helper to apply setting and log result
    _cf_apply_setting() {
        local name="$1"
        local endpoint="$2"
        local value="$3"

        _cf_log "  -> $name..."
        local result=$(_cf_api PATCH "/zones/$zone_id/settings/$endpoint" "$value" "$zone_id" "$api_token")
        local success=$(echo "$result" | jq -r '.success')

        if [[ "$success" == "true" ]]; then
            _cf_log "     OK"
        else
            local error=$(echo "$result" | jq -r '.errors[0].message // "Unknown error"')
            _cf_log "     FAILED: $error"
        fi
    }

    # Enable HTTP/3 (QUIC)
    _cf_apply_setting "Enabling HTTP/3" "http3" '{"value": "on"}'

    # Enable 0-RTT Connection Resumption
    _cf_apply_setting "Enabling 0-RTT" "0rtt" '{"value": "on"}'

    # Enable Early Hints
    _cf_apply_setting "Enabling Early Hints" "early_hints" '{"value": "on"}'

    # Enable Auto Minify (CSS, JS, HTML)
    _cf_apply_setting "Enabling Auto Minify" "minify" '{"value": {"css": "on", "html": "on", "js": "on"}}'

    # Enable Always Online
    _cf_apply_setting "Enabling Always Online" "always_online" '{"value": "on"}'

    # Set Browser Cache TTL to respect existing headers
    _cf_apply_setting "Setting Browser Cache TTL" "browser_cache_ttl" '{"value": 0}'

    # Enable Opportunistic Encryption
    _cf_apply_setting "Enabling Opportunistic Encryption" "opportunistic_encryption" '{"value": "on"}'

    # Enable WebSockets
    _cf_apply_setting "Enabling WebSockets" "websockets" '{"value": "on"}'

    # Enable Tiered Cache (uses Argo endpoint but is free)
    _cf_log "  -> Enabling Tiered Cache..."
    local tiered_result=$(_cf_api PATCH "/zones/$zone_id/argo/tiered_caching" '{"value": "on"}' "$zone_id" "$api_token")
    local tiered_success=$(echo "$tiered_result" | jq -r '.success')
    if [[ "$tiered_success" == "true" ]]; then
        _cf_log "     OK"
    else
        local tiered_error=$(echo "$tiered_result" | jq -r '.errors[0].message // "Unknown error"')
        _cf_log "     FAILED: $tiered_error"
        _cf_log "     (May need 'Zone > Argo Smart Routing > Edit' permission)"
    fi

    _cf_log ""

    # -------------------------------------------------------------------------
    # 2. CACHE RULES - Static Assets & WooCommerce Bypass
    # -------------------------------------------------------------------------
    _cf_log "Setting up Cache Rules..."

    # Check for existing cache rules ruleset
    _cf_log "  -> Checking for existing cache ruleset..."
    local existing_rulesets=$(_cf_api GET "/zones/$zone_id/rulesets" "" "$zone_id" "$api_token")
    local cache_ruleset_id=$(echo "$existing_rulesets" | jq -r '.result[] | select(.phase == "http_request_cache_settings") | .id // empty')

    # Cache rules payload
    local cache_rules='{
        "name": "Performance Cache Rules",
        "kind": "zone",
        "phase": "http_request_cache_settings",
        "rules": [
            {
                "expression": "(http.request.uri.path contains \"/wp-content/uploads/\") or (http.request.uri.path contains \"/wp-content/themes/\") or (http.request.uri.path contains \"/wp-includes/\")",
                "description": "Cache static assets (uploads, themes, includes) for 1 month",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": true,
                    "edge_ttl": {
                        "mode": "override_origin",
                        "default": 2592000
                    },
                    "browser_ttl": {
                        "mode": "override_origin",
                        "default": 604800
                    }
                }
            },
            {
                "expression": "(http.request.uri.path contains \"/cart\") or (http.request.uri.path contains \"/checkout\") or (http.request.uri.path contains \"/my-account\") or (http.cookie contains \"woocommerce_cart_hash\") or (http.cookie contains \"woocommerce_items_in_cart\")",
                "description": "Bypass cache for WooCommerce dynamic pages",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": false
                }
            },
            {
                "expression": "(http.request.uri.path.extension eq \"css\") or (http.request.uri.path.extension eq \"js\") or (http.request.uri.path.extension eq \"woff2\") or (http.request.uri.path.extension eq \"woff\") or (http.request.uri.path.extension eq \"ttf\")",
                "description": "Cache CSS, JS, and fonts for 1 month",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": true,
                    "edge_ttl": {
                        "mode": "override_origin",
                        "default": 2592000
                    },
                    "browser_ttl": {
                        "mode": "override_origin",
                        "default": 604800
                    }
                }
            },
            {
                "expression": "(http.request.uri.path.extension eq \"jpg\") or (http.request.uri.path.extension eq \"jpeg\") or (http.request.uri.path.extension eq \"png\") or (http.request.uri.path.extension eq \"gif\") or (http.request.uri.path.extension eq \"webp\") or (http.request.uri.path.extension eq \"avif\") or (http.request.uri.path.extension eq \"svg\") or (http.request.uri.path.extension eq \"ico\")",
                "description": "Cache images for 1 month",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": true,
                    "edge_ttl": {
                        "mode": "override_origin",
                        "default": 2592000
                    },
                    "browser_ttl": {
                        "mode": "override_origin",
                        "default": 2592000
                    }
                }
            }
        ]
    }'

    # Update rules payload (without name/kind/phase for PUT)
    local update_rules='{
        "rules": [
            {
                "expression": "(http.request.uri.path contains \"/wp-content/uploads/\") or (http.request.uri.path contains \"/wp-content/themes/\") or (http.request.uri.path contains \"/wp-includes/\")",
                "description": "Cache static assets (uploads, themes, includes) for 1 month",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": true,
                    "edge_ttl": {
                        "mode": "override_origin",
                        "default": 2592000
                    },
                    "browser_ttl": {
                        "mode": "override_origin",
                        "default": 604800
                    }
                }
            },
            {
                "expression": "(http.request.uri.path contains \"/cart\") or (http.request.uri.path contains \"/checkout\") or (http.request.uri.path contains \"/my-account\") or (http.cookie contains \"woocommerce_cart_hash\") or (http.cookie contains \"woocommerce_items_in_cart\")",
                "description": "Bypass cache for WooCommerce dynamic pages",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": false
                }
            },
            {
                "expression": "(http.request.uri.path.extension eq \"css\") or (http.request.uri.path.extension eq \"js\") or (http.request.uri.path.extension eq \"woff2\") or (http.request.uri.path.extension eq \"woff\") or (http.request.uri.path.extension eq \"ttf\")",
                "description": "Cache CSS, JS, and fonts for 1 month",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": true,
                    "edge_ttl": {
                        "mode": "override_origin",
                        "default": 2592000
                    },
                    "browser_ttl": {
                        "mode": "override_origin",
                        "default": 604800
                    }
                }
            },
            {
                "expression": "(http.request.uri.path.extension eq \"jpg\") or (http.request.uri.path.extension eq \"jpeg\") or (http.request.uri.path.extension eq \"png\") or (http.request.uri.path.extension eq \"gif\") or (http.request.uri.path.extension eq \"webp\") or (http.request.uri.path.extension eq \"avif\") or (http.request.uri.path.extension eq \"svg\") or (http.request.uri.path.extension eq \"ico\")",
                "description": "Cache images for 1 month",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": true,
                    "edge_ttl": {
                        "mode": "override_origin",
                        "default": 2592000
                    },
                    "browser_ttl": {
                        "mode": "override_origin",
                        "default": 2592000
                    }
                }
            }
        ]
    }'

    if [[ -z "$cache_ruleset_id" ]]; then
        _cf_log "  -> Creating new cache rules ruleset..."
        local cache_result=$(_cf_api POST "/zones/$zone_id/rulesets" "$cache_rules" "$zone_id" "$api_token")
        local cache_success=$(echo "$cache_result" | jq -r '.success')
        if [[ "$cache_success" == "true" ]]; then
            _cf_log "     OK - Cache rules created"
        else
            local cache_error=$(echo "$cache_result" | jq -r '.errors[0].message // "Unknown error"')
            _cf_log "     FAILED: $cache_error"
        fi
    else
        _cf_log "  -> Updating existing cache ruleset ($cache_ruleset_id)..."
        local cache_result=$(_cf_api PUT "/zones/$zone_id/rulesets/$cache_ruleset_id" "$update_rules" "$zone_id" "$api_token")
        local cache_success=$(echo "$cache_result" | jq -r '.success')
        if [[ "$cache_success" == "true" ]]; then
            _cf_log "     OK - Cache rules updated"
        else
            local cache_error=$(echo "$cache_result" | jq -r '.errors[0].message // "Unknown error"')
            _cf_log "     FAILED: $cache_error"
        fi
    fi

    _cf_log ""

    # -------------------------------------------------------------------------
    # 3. SECURITY SETTINGS
    # -------------------------------------------------------------------------
    _cf_log "Configuring Security Settings..."
    _cf_log ""

    # Set SSL to Full (Strict)
    _cf_apply_setting "Setting SSL to Full (Strict)" "ssl" '{"value": "strict"}'

    # Enable Automatic HTTPS Rewrites
    _cf_apply_setting "Enabling Automatic HTTPS Rewrites" "automatic_https_rewrites" '{"value": "on"}'

    # Enable TLS 1.3
    _cf_apply_setting "Enabling TLS 1.3" "tls_1_3" '{"value": "on"}'

    # Set minimum TLS version to 1.2
    _cf_apply_setting "Setting minimum TLS to 1.2" "min_tls_version" '{"value": "1.2"}'

    _cf_log ""

    # -------------------------------------------------------------------------
    # 4. VERIFY CONFIGURATION
    # -------------------------------------------------------------------------
    _cf_log "Verifying Configuration..."
    _cf_log ""

    # Get current settings
    local settings=$(_cf_api GET "/zones/$zone_id/settings" "" "$zone_id" "$api_token")

    # Get Tiered Cache status (separate endpoint)
    local tiered_status=$(_cf_api GET "/zones/$zone_id/argo/tiered_caching" "" "$zone_id" "$api_token")
    local tiered_value=$(echo "$tiered_status" | jq -r '.result.value // "unknown"')

    _cf_log "Final Settings:"
    _cf_log "  HTTP/3:        $(echo $settings | jq -r '.result[] | select(.id == "http3") | .value')"
    _cf_log "  Early Hints:   $(echo $settings | jq -r '.result[] | select(.id == "early_hints") | .value')"
    _cf_log "  0-RTT:         $(echo $settings | jq -r '.result[] | select(.id == "0rtt") | .value') (Pro plan required)"
    _cf_log "  Always Online: $(echo $settings | jq -r '.result[] | select(.id == "always_online") | .value')"
    _cf_log "  Tiered Cache:  $tiered_value"
    _cf_log "  SSL Mode:      $(echo $settings | jq -r '.result[] | select(.id == "ssl") | .value')"
    _cf_log "  TLS 1.3:       $(echo $settings | jq -r '.result[] | select(.id == "tls_1_3") | .value')"
    _cf_log "  Min TLS:       $(echo $settings | jq -r '.result[] | select(.id == "min_tls_version") | .value')"

    _cf_log ""

    # -------------------------------------------------------------------------
    # 5. PURGE CACHE
    # -------------------------------------------------------------------------
    local do_purge="n"
    if [[ "$batch_mode" == "batch" ]]; then
        do_purge="y"
    else
        echo ""
        echo "Purge Cloudflare cache now? [Y/n]"
        read -r purge_response
        if [[ ! "$purge_response" =~ ^[Nn]$ ]]; then
            do_purge="y"
        fi
    fi

    if [[ "$do_purge" == "y" ]]; then
        _cf_log "Purging cache..."
        local purge_result=$(_cf_api POST "/zones/$zone_id/purge_cache" '{"purge_everything": true}' "$zone_id" "$api_token")
        local purge_success=$(echo "$purge_result" | jq -r '.success')

        if [[ "$purge_success" == "true" ]]; then
            _cf_log "  Cache purged successfully"
        else
            local purge_error=$(echo "$purge_result" | jq -r '.errors[0].message // "Unknown error"')
            _cf_log "  Cache purge FAILED: $purge_error"
            _cf_log "  (You may need to add 'Zone > Cache Purge > Purge' permission to your API token)"
        fi
    fi

    # -------------------------------------------------------------------------
    # 6. VERIFY CACHING WITH CURL
    # -------------------------------------------------------------------------
    local do_test="n"
    if [[ "$batch_mode" == "batch" ]]; then
        do_test="y"
    else
        echo ""
        echo "Test cache headers now? [Y/n]"
        read -r test_response
        if [[ ! "$test_response" =~ ^[Nn]$ ]]; then
            do_test="y"
        fi
    fi

    if [[ "$do_test" == "y" ]]; then
        # Wait a moment for cache purge to propagate
        echo "  Waiting 2 seconds for cache purge to propagate..."
        sleep 2
        _cf_test_cache_headers "$zone_id" "$api_token" "$batch_mode"
    fi

    _cf_log ""
    _cf_log "===================================="
    _cf_log "Cloudflare optimisation complete!"
    _cf_log ""

    if [[ -n "$CF_LOG_FILE" ]]; then
        echo "Log saved to: $CF_LOG_FILE"
        echo ""
    fi

    # Clear credentials and log file path from memory
    unset CF_ZONE_ID CF_API_TOKEN CF_LOG_FILE CF_SITE_PATH
}

# -----------------------------------------------------------------------------
# cf-check: Check current Cloudflare settings for a zone
#
# Displays:
# - Performance settings (HTTP/3, Early Hints, 0-RTT, etc.)
# - Minification settings
# - Security settings (SSL, TLS)
# - Cache rules
# -----------------------------------------------------------------------------
cf-check() {
    echo "Cloudflare Settings Checker"
    echo "==========================="
    echo ""

    # Get credentials
    if ! _cf_get_credentials; then
        return 1
    fi

    local zone_id="$CF_ZONE_ID"
    local api_token="$CF_API_TOKEN"

    # Get all settings
    local settings=$(_cf_api GET "/zones/$zone_id/settings" "" "$zone_id" "$api_token")

    # Get Tiered Cache status (separate endpoint)
    local tiered_status=$(_cf_api GET "/zones/$zone_id/argo/tiered_caching" "" "$zone_id" "$api_token")
    local tiered_value=$(echo "$tiered_status" | jq -r '.result.value // "unknown"')

    # Performance Settings
    echo "Performance Settings:"
    echo "  HTTP/3 (QUIC):           $(echo $settings | jq -r '.result[] | select(.id == "http3") | .value')"
    echo "  Early Hints:             $(echo $settings | jq -r '.result[] | select(.id == "early_hints") | .value')"
    echo "  0-RTT:                   $(echo $settings | jq -r '.result[] | select(.id == "0rtt") | .value') (Pro plan required)"
    echo "  WebSockets:              $(echo $settings | jq -r '.result[] | select(.id == "websockets") | .value')"
    echo "  Always Online:           $(echo $settings | jq -r '.result[] | select(.id == "always_online") | .value')"
    echo "  Tiered Cache:            $tiered_value"
    echo "  Browser Cache TTL:       $(echo $settings | jq -r '.result[] | select(.id == "browser_cache_ttl") | .value') seconds"
    echo ""

    # Minification
    echo "Minification:"
    local minify=$(echo $settings | jq -r '.result[] | select(.id == "minify") | .value')
    echo "  CSS:  $(echo $minify | jq -r '.css')"
    echo "  HTML: $(echo $minify | jq -r '.html')"
    echo "  JS:   $(echo $minify | jq -r '.js')"
    echo ""

    # Security Settings
    echo "Security Settings:"
    echo "  SSL Mode:                $(echo $settings | jq -r '.result[] | select(.id == "ssl") | .value')"
    echo "  TLS 1.3:                 $(echo $settings | jq -r '.result[] | select(.id == "tls_1_3") | .value')"
    echo "  Min TLS Version:         $(echo $settings | jq -r '.result[] | select(.id == "min_tls_version") | .value')"
    echo "  HTTPS Rewrites:          $(echo $settings | jq -r '.result[] | select(.id == "automatic_https_rewrites") | .value')"
    echo "  Opportunistic Encryption:$(echo $settings | jq -r '.result[] | select(.id == "opportunistic_encryption") | .value')"
    echo ""

    # Cache Rules
    echo "Cache Rules:"
    local rulesets=$(_cf_api GET "/zones/$zone_id/rulesets" "" "$zone_id" "$api_token")
    local cache_ruleset_id=$(echo "$rulesets" | jq -r '.result[] | select(.phase == "http_request_cache_settings") | .id // empty')

    if [[ -n "$cache_ruleset_id" ]]; then
        local cache_rules=$(_cf_api GET "/zones/$zone_id/rulesets/$cache_ruleset_id" "" "$zone_id" "$api_token")
        echo "$cache_rules" | jq -r '.result.rules[] | "  - \(.description)"'
    else
        echo "  No cache rules configured"
    fi

    # -------------------------------------------------------------------------
    # Test Cache Headers
    # -------------------------------------------------------------------------
    echo ""
    echo "Test cache headers now? [Y/n]"
    read -r test_response

    if [[ ! "$test_response" =~ ^[Nn]$ ]]; then
        _cf_test_cache_headers "$zone_id" "$api_token"
    fi

    echo ""
    echo "==========================="
    echo "Check complete"

    # Clear credentials from memory
    unset CF_ZONE_ID CF_API_TOKEN
}

# -----------------------------------------------------------------------------
# cf-help: Display available Cloudflare commands
# -----------------------------------------------------------------------------
cf-help() {
    cat << 'EOF'
Cloudflare Management Commands
==============================

Commands:
  cf-opt                   Interactive mode - apply optimisations with prompts
  cf-opt DOMAIN            Batch mode - non-interactive, uses defaults
  cf-opt DOMAIN SITE_PATH  Batch mode with logging to specified path
  cf-check                 Check current settings and test cache headers
  cf-help                  Show this help message

Batch Mode (cf-opt only):
  Pass a domain name to skip all prompts and use defaults:
    cf-opt example.com.au                    # No logging
    cf-opt example.com.au ~/Sites/example    # With logging

  Batch mode auto-defaults:
    - Proceed confirmation → Yes
    - Purge cache → Yes
    - Test cache headers → Yes (uses domain homepage)
    - Site path → Auto-detect from current directory, or use provided path

Configuration:
  API Token is loaded from .dotfiles-config (CF_API_TOKEN).
  If not configured, you'll be prompted to enter it (interactive mode only).

  To add your token to config:
    echo 'CF_API_TOKEN="your-token-here"' >> ~/.dotfiles-config

Zone Selection (interactive mode):
  Lists all available zones and lets you select by:
  - Number (e.g., "2")
  - Full domain (e.g., "example.com.au")
  - Partial match (e.g., "example")

  In batch mode, the domain is matched automatically.

Logging (cf-opt only):
  Writes a timestamped log to the site root directory:
    cloudflare-optimisation-YYYY-MM-DD-HHMMSS.log

  Auto-detects site path if run from within ~/Sites/<sitename>/

Creating an API Token:
  1. Go to https://dash.cloudflare.com/profile/api-tokens
  2. Click "Create Token"
  3. Add these permissions (set to "All Zones" for convenience):
     - Zone > Zone Settings > Edit
     - Zone > Cache Rules > Edit
     - Zone > Cache Purge > Purge
     - Zone > Argo Smart Routing > Edit
  4. Create and copy the token

What cf-opt does:
  1. Applies Performance Settings:
     - HTTP/3 (QUIC), Early Hints, Tiered Cache
     - Auto Minify (CSS, HTML, JS)
     - Always Online, WebSockets, Opportunistic Encryption
     - 0-RTT (Pro plan required)

  2. Sets up Cache Rules:
     - Static assets (uploads, themes, includes) - 1 month edge
     - CSS, JS, fonts - 1 month edge, 1 week browser
     - Images - 1 month edge and browser
     - WooCommerce bypass (cart, checkout, my-account)

  3. Configures Security:
     - SSL Full (Strict), TLS 1.3, Min TLS 1.2
     - Automatic HTTPS Rewrites

  4. Purges Cache (optional)

  5. Tests Cache Headers:
     - Makes requests to verify caching is working
     - Provides analysis and verdict

What cf-check does:
  - Displays all current Cloudflare settings
  - Shows cache rules
  - Tests cache headers with analysis

EOF
}
