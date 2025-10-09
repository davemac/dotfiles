# System Utilities and Common Aliases
#
# A collection of useful system utilities, file operations, network tools,
# development helpers, and general productivity functions.
#
# ============================================================================
# FUNCTION INDEX
# ============================================================================
#
# File System Utilities:
# • showsize                   - Display directory sizes (alias: du -sh ./*)
# • dsclean                    - Delete all .DS_Store files recursively  
# • ls                         - Enhanced ls with colors and details (alias)
# • up [N]                     - Move up N directories in the filesystem
#
# Network Utilities:
# • myip                       - Display your public IP address
# • socksit                    - Create SSH SOCKS proxy (uses SSH_PROXY_HOST config)
# • chromeproxy                - Launch Chrome with SSH SOCKS proxy
# • flushdns                   - Flush DNS cache and announce completion
#
# Development Tools:
# • zp                         - Edit ~/.zprofile in Cursor (alias)
# • sshconfig                  - Edit ~/.ssh/config in Cursor (alias)  
# • code                       - Open files in VSCode with proper setup
# • tb                         - Send text to termbin.com (alias: nc termbin.com 9999)
#
# Homebrew Utilities:
# • brewup                     - Update Homebrew packages (alias)
# • brewupc                    - Update Homebrew packages and cleanup (alias)
#
# Media Download Tools:
# • ytaudio [URL]              - Download YouTube audio as MP3
# • download_vimeo_hd [URL]    - Download all Vimeo videos from page in HD with metadata
# • dlvimeo                    - Alias for download_vimeo_hd
#
# WordPress Utilities:
# • wp_download_images         - Download images from clipboard HTML to wp-content/uploads
# • wpdli                      - Alias for wp_download_images
#
# Information & Help:
# • listcmds                   - Display all available dotfiles commands organized by category
#
# ============================================================================

# File system utilities
alias showsize="du -sh ./*"
alias dsclean="find . -type f -name .DS_Store -delete"
alias ls="ls -Ghal"

# Homebrew utilities
alias brewup="brew update && brew upgrade"
alias brewupc="brew update && brew upgrade && brew cleanup"

# Network utilities
alias myip="curl ifconfig.co"
# Load config for SSH proxy host
load_dotfiles_config 2>/dev/null || true
alias socksit="ssh -D 8080 ${SSH_PROXY_HOST:-localhost}"
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
   load_dotfiles_config 2>/dev/null || true
   ssh -N -D 9090 "${SSH_PROXY_HOST:-localhost}"

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

# List all available dotfiles commands and functions
listcmds() {
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[0;34m'
    local CYAN='\033[0;36m'
    local NC='\033[0m' # No Color
    local BOLD='\033[1m'

    echo -e "${BOLD}${BLUE}Available Dotfiles Commands & Functions${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""

    # Configuration Management
    echo -e "${BOLD}${YELLOW}Configuration Management (config.sh)${NC}"
    echo -e "${GREEN}dotfiles_config${NC}  Manage dotfiles configuration"
    echo -e "${GREEN}show_dotfiles_config${NC} Display current configuration settings"
    echo -e "${GREEN}create_default_config${NC} Create default .dotfiles-config file"
    echo -e "${GREEN}load_dotfiles_config${NC} Load configuration with defaults (auto-called)"
    echo ""

    # WordPress Core Shortcuts
    echo -e "${BOLD}${YELLOW}WordPress Core Shortcuts (wp-core.sh)${NC}"
    echo -e "${GREEN}updatem${NC}          Update all plugins, themes, and WordPress core"
    echo -e "${GREEN}siteurl${NC}          Display current site URL from database"
    echo -e "${GREEN}plugincheck${NC}      Check for plugin conflicts"
    echo -e "${GREEN}onetimeinstall${NC}   Install one-time login plugin on production"
    echo -e "${GREEN}onetimeadmin${NC}     Generate one-time login link for admin"
    echo ""

    # Database Operations
    echo -e "${BOLD}${YELLOW}Database Operations (wp-db.sh)${NC}"
    echo -e "${GREEN}pullprod${NC}         Pull production database to local environment"
    echo -e "${GREEN}pullstage${NC}        Pull staging database to local"
    echo -e "${GREEN}pulltest${NC}         Pull testing database to local"
    echo -e "${GREEN}pushstage${NC}        Push local database to staging (--dry-run available)"
    echo -e "${GREEN}pushstage_dry_run_preview${NC} Preview pushstage operation changes"
    echo -e "${GREEN}dmcweb${NC}           Update admin password to configured dev password"
    echo -e "${GREEN}check-featured-image${NC} Find posts missing featured images"
    echo -e "${GREEN}update-wc-db${NC}     Update WooCommerce on multiple hosts"
    echo -e "${GREEN}wp_db_optimise${NC}   Comprehensive database cleanup and optimization"
    echo -e "${GREEN}wpopt${NC}            Alias for wp_db_optimise"
    echo -e "${GREEN}wp_db_optimise_dry_run_preview${NC} Preview optimization changes"
    echo -e "${GREEN}wp_db_table_delete${NC} Interactive database table cleanup"
    echo -e "${GREEN}wpdel${NC}            Alias for wp_db_table_delete"
    echo -e "${GREEN}pulldb${NC}           Export production database to local file"
    echo ""

    # Upload Management
    echo -e "${BOLD}${YELLOW}Upload Management (wp-uploads.sh)${NC}"
    echo -e "${GREEN}getups${NC}           Sync WordPress uploads directory from remote (l/s/-latest)"
    echo -e "${GREEN}pushups${NC}          Push uploads to remote server (-auto/-target)"
    echo -e "${GREEN}getrecentuploads${NC} Sync only recently modified uploads (last 60 days)"
    echo ""

    # Development Tools
    echo -e "${BOLD}${YELLOW}Development Tools (wp-dev.sh)${NC}"
    echo -e "${GREEN}wp74${NC}             Execute WP-CLI with PHP 7.4"
    echo -e "${GREEN}genlorem${NC}         Generate lorem ipsum content"
    echo -e "${GREEN}gencpt${NC}           Scaffold custom post types"
    echo -e "${GREEN}genctax${NC}          Scaffold custom taxonomies"
    echo ""

    # Diagnostics & Troubleshooting
    echo -e "${BOLD}${YELLOW}Diagnostics & Troubleshooting (wp-diagnostics.sh)${NC}"
    echo -e "${GREEN}wp_plugin_diags${NC}  Systematically test plugins to isolate fatal errors"
    echo ""

    # Theme Deployment
    echo -e "${BOLD}${YELLOW}Theme Deployment (deployment.sh)${NC}"
    echo -e "${GREEN}firstdeploy${NC}      Initial site deployment to staging"
    echo -e "${GREEN}firstdeploy-prod${NC} Initial site deployment to production"
    echo -e "${GREEN}depto${NC}            Deploy theme files to staging or production"
    echo ""

    # Git Utilities
    echo -e "${BOLD}${YELLOW}Git Utilities (git.sh)${NC}"
    echo -e "${GREEN}new_branch${NC}       Create new branch from ticket ID and title"
    echo -e "${GREEN}gs${NC}               Git status"
    echo -e "${GREEN}ga${NC}               Git add"
    echo -e "${GREEN}gca${NC}              Git commit -a"
    echo -e "${GREEN}gc${NC}               Git commit"
    echo -e "${GREEN}gl${NC}               Git log with nice formatting"
    echo -e "${GREEN}glcss${NC}            Git log for CSS files from last year"
    echo ""

    # File System & Navigation
    echo -e "${BOLD}${YELLOW}File System & Navigation (utils.sh)${NC}"
    echo -e "${GREEN}showsize${NC}         Display directory sizes"
    echo -e "${GREEN}dsclean${NC}          Delete .DS_Store files recursively"
    echo -e "${GREEN}ls${NC}               Enhanced ls with colors and details"
    echo -e "${GREEN}up [N]${NC}           Move up N directories"
    echo ""

    # Network & Connectivity
    echo -e "${BOLD}${YELLOW}Network & Connectivity (utils.sh)${NC}"
    echo -e "${GREEN}myip${NC}             Display public IP address"
    echo -e "${GREEN}socksit${NC}          SSH SOCKS proxy to configured host"
    echo -e "${GREEN}chromeproxy${NC}      Launch Chrome with SSH proxy"
    echo -e "${GREEN}flushdns${NC}         Flush DNS cache"
    echo -e "${GREEN}tb${NC}               Send text to termbin.com"
    echo ""

    # Development Environment
    echo -e "${BOLD}${YELLOW}Development Environment (utils.sh)${NC}"
    echo -e "${GREEN}zp${NC}               Edit ~/.zprofile in Cursor"
    echo -e "${GREEN}sshconfig${NC}        Edit ~/.ssh/config in Cursor"
    echo -e "${GREEN}code${NC}             Open files in VSCode"
    echo ""

    # Package Management
    echo -e "${BOLD}${YELLOW}Package Management (utils.sh)${NC}"
    echo -e "${GREEN}brewup${NC}           Update Homebrew packages"
    echo -e "${GREEN}brewupc${NC}          Update and cleanup Homebrew"
    echo ""

    # Media & Downloads
    echo -e "${BOLD}${YELLOW}Media & Downloads (utils.sh)${NC}"
    echo -e "${GREEN}ytaudio${NC}          Download YouTube audio as MP3"
    echo -e "${GREEN}download_vimeo_hd${NC} Download Vimeo videos in HD with metadata"
    echo -e "${GREEN}dlvimeo${NC}          Alias for download_vimeo_hd"
    echo -e "${GREEN}wp_download_images${NC} Download images from clipboard HTML to WordPress"
    echo -e "${GREEN}wpdli${NC}            Alias for wp_download_images"
    echo ""

    # Help & Documentation
    echo -e "${BOLD}${YELLOW}Help & Documentation${NC}"
    echo -e "${GREEN}listcmds${NC}         Display this command list"
    echo ""

    echo -e "${CYAN}Usage: Run any command directly in your terminal${NC}"
    echo -e "${CYAN}Example: ${GREEN}pullprod${CYAN}, ${GREEN}getups l${CYAN}, ${GREEN}wp_db_optimise${NC}"
}

# Download ALL Vimeo videos from pages with source URL metadata
# Usage: download_vimeo_hd <url>
download_vimeo_hd() {
    local url="$1"
    local vimeo_ids
    local success_count=0
    local total_count=0

    # Validate input
    if [[ -z "$url" ]]; then
        echo "Usage: download_vimeo_hd <URL>"
        return 1
    fi

    echo "🔍 Finding ALL Vimeo videos from: $url"

    # Find all unique Vimeo IDs from the webpage
    echo "🌐 Parsing webpage HTML for all Vimeo videos..."
    vimeo_ids=($(curl -s "$url" | grep -o 'player\.vimeo\.com/video/[0-9]\+' | grep -o '[0-9]\+' | sort -u))

    # Check if we found any vimeo IDs
    if [[ ${#vimeo_ids[@]} -eq 0 ]]; then
        echo "❌ Could not find any Vimeo videos from the provided URL"
        echo "💡 Check if the page contains Vimeo videos"
        return 1
    fi

    echo "✅ Found ${#vimeo_ids[@]} unique Vimeo video(s): ${vimeo_ids[*]}"

    # Array of format preferences (best to lowest HD quality)
    local formats=(
        "hls-fastly_skyfire-3888+hls-fastly_skyfire-audio-high-Original"  # 1080p
        "hls-akfire_interconnect_quic-3888+hls-akfire_interconnect_quic-audio-high-Original"  # 1080p alt
        "hls-fastly_skyfire-2173+hls-fastly_skyfire-audio-high-Original"  # 720p
        "hls-akfire_interconnect_quic-2173+hls-akfire_interconnect_quic-audio-high-Original"  # 720p alt
        "best[height<=1080]"  # Best up to 1080p
        "best[height<=720]"   # Best up to 720p
        "best"                # Best available
    )

    # Download each video
    for vimeo_id in "${vimeo_ids[@]}"; do
        total_count=$((total_count + 1))
        echo ""
        echo "📹 Downloading video $total_count of ${#vimeo_ids[@]} (ID: $vimeo_id)..."

        local video_success=false
        local direct_vimeo_url="https://vimeo.com/$vimeo_id"

        # Try each format in order for this video
        for format in "${formats[@]}"; do
            echo "🎯 Trying format: $format"

            # Download directly from vimeo.com URL instead of using match-filter
            if yt-dlp \
                -f "$format" \
                --add-metadata \
                --postprocessor-args "ffmpeg:-metadata comment=\"$url\"" \
                "$direct_vimeo_url" >/dev/null 2>&1; then

                video_success=true
                success_count=$((success_count + 1))
                echo "✅ Successfully downloaded video ID: $vimeo_id"
                break
            fi
        done

        if [[ "$video_success" == false ]]; then
            echo "❌ Failed to download video ID: $vimeo_id"
            echo "💡 Video may be private or have restricted access"
        fi
    done

    echo ""
    echo "🎸 Download summary: $success_count of $total_count videos downloaded successfully!"

    if [[ $success_count -gt 0 ]]; then
        echo "📝 All videos have source URL metadata: $url"
        return 0
    else
        echo "❌ No videos were downloaded successfully"
        echo "💡 These may be private/embedded-only videos that require the lesson page context"
        return 1
    fi
}

# Alias for shorter command
alias dlvimeo='download_vimeo_hd'


# Download images referenced in clipboard HTML into a WordPress site's wp-content directory.
#
# What it does:
# - Extracts all unique image URLs under wp-content from clipboard HTML
# - Recreates nested folders under wp-content locally
# - Skips existing valid images; replaces non-image files
# - Validates remote Content-Type is image; removes invalid/empty files
# - Shows an interactive confirmation with site, target, image count, and a clipboard preview (first 3 lines) before downloading
# - Prints a success/skip/fail summary
#
# Usage:
#   wp_download_images
#   wp_download_images -p ~/Sites/example-site
#   wpdli  # alias
#
# Options:
#   -p, --path SITE_PATH  Download into this site's root (overrides auto-detection from current directory)
#   -h, --help            Show usage
#
# Notes:
# - When run inside ~/Sites/<site>, the site path is auto-detected
# - Confirmation defaults to No; press 'y' to proceed
#
# Requirements: macOS (pbpaste), curl, file
# WordPress Image Downloader Function
# Add this to your ~/.zshrc or dotfiles

wp_download_images() {
    # Colours for output
    local RED='\033[0;31m'
    local GREEN='\033[0;32m'
    local YELLOW='\033[1;33m'
    local BLUE='\033[0;34m'
    local NC='\033[0m' # No Colour

    # Function to show usage
    local show_usage() {
        echo "Usage: wp_download_images [-p|--path SITE_PATH]"
        echo ""
        echo "Options:"
        echo "  -p, --path SITE_PATH    Override the auto-detected site path"
        echo "  -h, --help              Show this help message"
        echo ""
        echo "The function will automatically detect the site directory from your current location"
        echo "if you're within a ~/Sites/ directory structure."
        echo ""
        echo "Examples:"
        echo "  wp_download_images                           # Auto-detect from current directory"
        echo "  wp_download_images -p ~/Sites/my-site        # Use specific site path"
    }

    # Function to auto-detect site path
    local auto_detect_site_path() {
        local current_dir="$(pwd)"
        local sites_dir="$HOME/Sites"

        # Check if we're within the ~/Sites directory
        if [[ "$current_dir" == "$sites_dir"/* ]]; then
            # Extract the site directory (first subdirectory under ~/Sites)
            local relative_path="${current_dir#$sites_dir/}"
            local site_name="${relative_path%%/*}"
            echo "$sites_dir/$site_name"
        else
            return 1
        fi
    }

    # Parse command line arguments
    local SITE_PATH_OVERRIDE=""

    while [[ $# -gt 0 ]]; do
        case $1 in
            -p|--path)
                SITE_PATH_OVERRIDE="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                return 0
                ;;
            *)
                echo "Unknown option: $1"
                show_usage
                return 1
                ;;
        esac
    done

    # Determine the site path
    local LOCAL_SITE_PATH
    if [[ -n "$SITE_PATH_OVERRIDE" ]]; then
        LOCAL_SITE_PATH="$SITE_PATH_OVERRIDE"
        echo "${BLUE}Using override site path: ${LOCAL_SITE_PATH}${NC}"
    else
        LOCAL_SITE_PATH=$(auto_detect_site_path)
        if [[ $? -eq 0 ]]; then
            echo "${GREEN}Auto-detected site path: ${LOCAL_SITE_PATH}${NC}"
        else
            echo "${RED}Error: Could not auto-detect site path${NC}"
            echo "${YELLOW}You must be within a ~/Sites/ directory or use the -p option${NC}"
            echo ""
            show_usage
            return 1
        fi
    fi

    # Validate the site path
    if [[ ! -d "$LOCAL_SITE_PATH" ]]; then
        echo "${RED}Error: Site directory does not exist: $LOCAL_SITE_PATH${NC}"
        return 1
    fi

    local WP_CONTENT_DIR="$LOCAL_SITE_PATH/wp-content"

    echo "${BLUE}Reading HTML from clipboard...${NC}"

    # Get HTML content from clipboard
    local HTML_CONTENT=$(pbpaste)

    if [[ -z "$HTML_CONTENT" ]]; then
        echo "${RED}Error: Clipboard is empty or doesn't contain text${NC}"
        return 1
    fi

    echo "${GREEN}✓ HTML content retrieved from clipboard${NC}"

    # Function to extract image URLs from HTML
    local extract_image_urls() {
        local html="$1"
        local -a urls=()

        # Extract URLs from background-image: url() declarations
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                urls+=("$line")
            fi
        done < <(echo "$html" | grep -oE "background-image:\s*url\(['\"]?([^'\"]*wp-content/[^'\"]*)['\"]?\)" | sed -E "s/.*url\(['\"]?([^'\"]*)['\"]?\).*/\1/")

        # Extract URLs from <img> src attributes
        while IFS= read -r line; do
            if [[ -n "$line" ]]; then
                urls+=("$line")
            fi
        done < <(echo "$html" | grep -oE "<img[^>]*src=['\"]([^'\"]*wp-content/[^'\"]*)['\"]" | sed -E "s/.*src=['\"]([^'\"]*)['\"].*/\1/")

        # Remove duplicates and return unique URLs
        printf '%s\n' "${urls[@]}" | sort -u
    }

    # Extract image URLs from the HTML
    echo "${BLUE}Extracting image URLs from HTML...${NC}"
    local IMAGE_URLS_RAW=$(extract_image_urls "$HTML_CONTENT")

    if [[ -z "$IMAGE_URLS_RAW" ]]; then
        echo "${RED}Error: No image URLs found in the HTML content${NC}"
        echo "${YELLOW}Make sure the HTML contains images with wp-content paths${NC}"
        return 1
    fi

    # Convert to array
    local -a IMAGE_URLS=()
    while IFS= read -r url; do
        if [[ -n "$url" ]]; then
            IMAGE_URLS+=("$url")
        fi
    done <<< "$IMAGE_URLS_RAW"

    echo "${GREEN}✓ Found ${#IMAGE_URLS[@]} unique image URLs:${NC}"
    for url in "${IMAGE_URLS[@]}"; do
        echo "  ${BLUE}${url}${NC}"
    done
    echo ""

    # Safety check - show what will happen and ask for confirmation
    echo "${YELLOW}━━━ CONFIRMATION ━━━${NC}"
    echo "${BLUE}Site:${NC} ${LOCAL_SITE_PATH}"
    echo "${BLUE}Images to download:${NC} ${#IMAGE_URLS[@]}"
    echo "${BLUE}Target directory:${NC} ${WP_CONTENT_DIR}"
    echo ""

    # Show a preview of the clipboard content (first 3 lines)
    echo "${BLUE}Clipboard preview:${NC}"
    echo "$HTML_CONTENT" | head -3 | sed 's/^/  /'
    if [[ $(echo "$HTML_CONTENT" | wc -l) -gt 3 ]]; then
        echo "  ${YELLOW}... ($(echo "$HTML_CONTENT" | wc -l) total lines)${NC}"
    fi
    echo ""

    echo "${YELLOW}Do you want to proceed with downloading these images? [y/N]${NC}"
    read -r response

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        echo "${YELLOW}Download cancelled.${NC}"
        return 0
    fi

    echo "${BLUE}Starting image download process...${NC}"
    echo "Local site path: ${LOCAL_SITE_PATH}"
    echo "WP Content directory: ${WP_CONTENT_DIR}"
    echo ""

    # Check if the local site directory exists
    if [[ ! -d "$LOCAL_SITE_PATH" ]]; then
        echo "${RED}Error: Local site directory does not exist: $LOCAL_SITE_PATH${NC}"
        return 1
    fi

    # Create the wp-content directory if it doesn't exist
    if [[ ! -d "$WP_CONTENT_DIR" ]]; then
        echo "${YELLOW}Creating wp-content directory: $WP_CONTENT_DIR${NC}"
        mkdir -p "$WP_CONTENT_DIR"
    fi

    # Function to extract the relative path from the full URL
    local extract_relative_path() {
        local url="$1"
        # Remove everything up to and including "wp-content/"
        local path="${url#*wp-content/}"
        # Remove query parameters (everything after ?)
        local clean_path="${path%%\?*}"
        # Also remove WordPress size suffixes like -854x510, -690x400, etc.
        # This regex removes -NNNxNNN pattern before the file extension
        echo "$clean_path" | sed -E 's/-[0-9]+x[0-9]+(\.[^.]+)$/\1/'
    }

    # Function to URL encode for HTTP requests (pure shell solution)
    local url_encode() {
        local url="$1"
        # Only encode spaces to %20, keep the rest as-is for simplicity
        echo "$url" | sed 's/ /%20/g'
    }

    # Function to decode HTML entities
    local decode_html_entities() {
        echo "$1" | sed 's/&amp;/\&/g'
    }

    # Function to download a single image
    local download_image() {
        local url="$1"
        local decoded_url=$(decode_html_entities "$url")
        # Remove query parameters to get base image URL
        local base_url="${decoded_url%%\?*}"
        local encoded_url=$(url_encode "$base_url")
        local relative_path=$(extract_relative_path "$decoded_url")
        local local_file_path="$WP_CONTENT_DIR/$relative_path"
        local local_dir=$(dirname "$local_file_path")

        echo "${BLUE}Processing: $relative_path${NC}"
        echo "  ${YELLOW}Original:${NC}  $url"
        echo "  ${YELLOW}Base URL:${NC}  $base_url"
        echo "  ${YELLOW}Encoded:${NC}   $encoded_url"
        echo "  ${YELLOW}Local file:${NC} $local_file_path"

        # Create the directory structure if it doesn't exist
        if [[ ! -d "$local_dir" ]]; then
            echo "  ${YELLOW}Creating directory: $local_dir${NC}"
            mkdir -p "$local_dir"
            if [[ $? -ne 0 ]]; then
                echo "  ${RED}Failed to create directory: $local_dir${NC}"
                return 1
            fi
        fi

        # Check if file already exists and if it's a valid image
        if [[ -f "$local_file_path" ]]; then
            local existing_file_type=$(file -b --mime-type "$local_file_path" 2>/dev/null)
            if [[ "$existing_file_type" =~ ^image/ ]]; then
                echo "  ${YELLOW}Valid image already exists, skipping: $local_file_path${NC}"
                return 0
            else
                echo "  ${YELLOW}Existing file is not a valid image (${existing_file_type}), will replace${NC}"
                rm -f "$local_file_path"
            fi
        fi

        # First, check if the URL is accessible and returns an image
        echo "  ${BLUE}Checking URL accessibility...${NC}"
        local content_type=$(curl -I -L -s "$encoded_url" | grep -i "content-type:" | head -1 | cut -d: -f2 | tr -d ' \r')

        if [[ -z "$content_type" ]]; then
            echo "  ${RED}✗ Could not determine content type - server may not be responding${NC}"
            return 1
        fi

        # Check if content type indicates an image
        if [[ ! "$content_type" =~ ^image/ ]]; then
            echo "  ${RED}✗ URL does not serve an image (Content-Type: $content_type)${NC}"
            echo "  ${YELLOW}    This usually means the server returned an error page${NC}"
            return 1
        fi

        echo "  ${GREEN}  Content-Type: $content_type${NC}"

        # Download the image using curl
        echo "  ${BLUE}Downloading to: $local_file_path${NC}"
        curl -L -s -o "$local_file_path" "$encoded_url"

        # Check if download was successful
        if [[ $? -eq 0 ]] && [[ -f "$local_file_path" ]]; then
            # Check if the downloaded file is not empty
            if [[ -s "$local_file_path" ]]; then
                # Verify the downloaded file is actually an image
                local file_type=$(file -b --mime-type "$local_file_path" 2>/dev/null)
                if [[ "$file_type" =~ ^image/ ]]; then
                    echo "  ${GREEN}✓ Successfully downloaded valid image (${file_type})${NC}"
                    return 0
                else
                    echo "  ${RED}✗ Downloaded file is not a valid image (${file_type}), removing${NC}"
                    rm -f "$local_file_path"
                    return 1
                fi
            else
                echo "  ${RED}✗ Downloaded file is empty, removing${NC}"
                rm -f "$local_file_path"
                return 1
            fi
        else
            echo "  ${RED}✗ Failed to download${NC}"
            return 1
        fi
    }

    # Counter for statistics
    local total_images=${#IMAGE_URLS[@]}
    local successful_downloads=0
    local failed_downloads=0
    local skipped_downloads=0

    echo "Found $total_images images to process"
    echo ""

    # Process each image URL
    for url in "${IMAGE_URLS[@]}"; do
        download_image "$url"
        case $? in
            0)
                if [[ -f "$WP_CONTENT_DIR/$(extract_relative_path "$url")" ]]; then
                    if [[ $(stat -f%z "$WP_CONTENT_DIR/$(extract_relative_path "$url")" 2>/dev/null || stat -c%s "$WP_CONTENT_DIR/$(extract_relative_path "$url")" 2>/dev/null) -gt 0 ]]; then
                        ((successful_downloads++))
                    else
                        ((skipped_downloads++))
                    fi
                else
                    ((skipped_downloads++))
                fi
                ;;
            1)
                ((failed_downloads++))
                ;;
        esac
        echo ""
    done

    # Display summary
    echo "${BLUE}Download Summary:${NC}"
    echo "Total images: $total_images"
    echo "${GREEN}Successful downloads: $successful_downloads${NC}"
    echo "${YELLOW}Skipped (already existed): $skipped_downloads${NC}"
    echo "${RED}Failed downloads: $failed_downloads${NC}"

    if [[ $failed_downloads -gt 0 ]]; then
        echo ""
        echo "${YELLOW}Note: Some downloads failed. This could be due to:${NC}"
        echo "- Network connectivity issues"
        echo "- Remote server not responding"
        echo "- Images no longer available at the source"
        echo "- Permission issues with local directories"
    fi

    echo ""
    echo "${BLUE}Download process completed.${NC}"
}
# Alias for shorter command
alias wpdli='wp_download_images'