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
    echo -e "${GREEN}pushstage${NC}        Push local database to staging"
    echo -e "${GREEN}dmcweb${NC}           Update admin password to 'dmcweb'"
    echo -e "${GREEN}check-featured-image${NC} Find posts missing featured images"
    echo -e "${GREEN}update-wc-db${NC}     Update WooCommerce on multiple hosts"
    echo -e "${GREEN}wp_db_optimise${NC}   Comprehensive database cleanup and optimization"
    echo -e "${GREEN}wpopt${NC}            Alias for wp_db_optimise"
    echo -e "${GREEN}wp_db_table_delete${NC} Interactive database table cleanup"
    echo -e "${GREEN}wpdel${NC}            Alias for wp_db_table_delete"
    echo -e "${GREEN}pulldb${NC}           Export production database to local file"
    echo ""
    
    # Upload Management
    echo -e "${BOLD}${YELLOW}Upload Management (wp-uploads.sh)${NC}"
    echo -e "${GREEN}getups${NC}           Sync WordPress uploads directory from remote"
    echo -e "${GREEN}pushups${NC}          Push uploads to remote server"
    echo -e "${GREEN}getrecentuploads${NC} Sync only recently modified uploads"
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
    
    # System Utilities
    echo -e "${BOLD}${YELLOW}System Utilities (utils.sh)${NC}"
    echo -e "${GREEN}showsize${NC}         Display directory sizes"
    echo -e "${GREEN}dsclean${NC}          Delete .DS_Store files"
    echo -e "${GREEN}ls${NC}               Enhanced ls with colors and details"
    echo -e "${GREEN}rsync${NC}            Enhanced rsync with progress"
    echo -e "${GREEN}brewup${NC}           Update Homebrew packages"
    echo -e "${GREEN}brewupc${NC}          Update and cleanup Homebrew"
    echo -e "${GREEN}myip${NC}             Display public IP address"
    echo -e "${GREEN}socksit${NC}          SSH SOCKS proxy to keith"
    echo -e "${GREEN}flushdns${NC}         Flush DNS cache"
    echo -e "${GREEN}zp${NC}               Edit ~/.zprofile in Cursor"
    echo -e "${GREEN}sshconfig${NC}        Edit ~/.ssh/config in Cursor"
    echo -e "${GREEN}ytaudio${NC}          Download YouTube audio as MP3"
    echo -e "${GREEN}up${NC}               Move up X directories"
    echo -e "${GREEN}chromeproxy${NC}      Launch Chrome with proxy"
    echo -e "${GREEN}code${NC}             Open files in VSCode"
    echo -e "${GREEN}tb${NC}               Send text to termbin.com"
    echo -e "${GREEN}listcmds${NC}         Display this command list"
    echo ""
    
    echo -e "${CYAN}Usage: Run any command directly in your terminal${NC}"
    echo -e "${CYAN}Example: ${GREEN}pullprod${CYAN}, ${GREEN}getups l${CYAN}, ${GREEN}wp_db_optimise${NC}"
}
