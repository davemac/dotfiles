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
# Information & Help:
# • listcmds                   - Display all available dotfiles commands organized by category
#
# ============================================================================

# Shared colour definitions — used across all shell function files.
# Terminal colour support is assumed; functions that need to check can test [[ -t 1 ]].
CLR_RED='\033[0;31m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[1;33m'
CLR_BLUE='\033[0;34m'
CLR_CYAN='\033[0;36m'
CLR_BOLD='\033[1m'
CLR_NC='\033[0m'

# File system utilities
alias showsize="du -sh ./*"
alias dsclean="find . -type f -name .DS_Store -delete"
alias ls="ls -Ghal"

# Homebrew utilities
alias brewup="brew update && brew upgrade"
alias brewupc="brew update && brew upgrade && brew cleanup"

# Network utilities
alias myip="curl ifconfig.co"
# SSH SOCKS proxy — evaluated at call time so config changes take effect
socksit() {
   load_dotfiles_config 2>/dev/null || true
   ssh -D 9090 "${SSH_PROXY_HOST:-localhost}"
}
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
   d=$(echo $d | /usr/bin/sed 's/^\///')
   if [ -z "$d" ]; then
       d=..
   fi
   cd $d || return
}

# Chrome with proxy — SSH tunnel runs in background, cleaned up on exit
chromeproxy() {
   load_dotfiles_config 2>/dev/null || true
   local proxy_port=9090

   ssh -N -D "$proxy_port" "${SSH_PROXY_HOST:-localhost}" &
   local ssh_pid=$!
   trap "kill $ssh_pid 2>/dev/null" EXIT INT TERM

   # Wait briefly for tunnel to establish
   sleep 1

   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
   --user-data-dir="$HOME/proxy-profile" \
   --proxy-server="socks5://localhost:$proxy_port"

   kill "$ssh_pid" 2>/dev/null
   trap - EXIT INT TERM
}

# VSCode helper
code () {
   VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;
}

# Send to termbin
alias tb="nc termbin.com 9999"

# List all available dotfiles commands and functions
listcmds() {
    local GREEN="$CLR_GREEN" YELLOW="$CLR_YELLOW" BLUE="$CLR_BLUE"
    local CYAN="$CLR_CYAN" NC="$CLR_NC" BOLD="$CLR_BOLD"

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
    echo -e "${GREEN}pullprod${NC}         Pull production database to local environment (--yes to skip prompt)"
    echo -e "${GREEN}pullstage${NC}        Pull staging database to local"
    echo -e "${GREEN}pushstage${NC}        Push local database to staging (--dry-run available)"
    echo -e "${GREEN}pushstage_dry_run_preview${NC} Preview pushstage operation changes"
    echo -e "${GREEN}dmcweb${NC}           Update admin password to configured dev password"
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
    echo ""

    # Cloudflare Management
    echo -e "${BOLD}${YELLOW}Cloudflare Management (cloudflare.sh)${NC}"
    echo -e "${GREEN}cf-opt${NC}           Apply Cloudflare performance and security optimisations"
    echo -e "${GREEN}cf-check${NC}         Check current Cloudflare settings for a zone"
    echo -e "${GREEN}cf-help${NC}          Show Cloudflare commands help"
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
