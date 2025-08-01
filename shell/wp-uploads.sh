# WordPress Upload Management Functions
#
# This file contains all functions related to uploading, downloading, and syncing
# WordPress uploads directory between different environments (local, staging, production).

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
    # Handle --help flag (check all arguments)
    for arg in "$@"; do
        if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
        echo "WordPress Uploads Download Tool"
        echo ""
        echo "USAGE:"
        echo "  getups s                            # Download all uploads from staging"
        echo "  getups l                            # Download all uploads from live"
        echo "  getups s -latest                    # Download only last 2 months from staging"
        echo "  getups l -latest                    # Download only last 2 months from live"
        echo "  getups --help                       # Show this help message"
        echo ""
        echo "ARGUMENTS:"
        echo "  s                   Staging environment"
        echo "  l                   Live/production environment"
        echo ""
        echo "OPTIONS:"
        echo "  -latest             Download only current and previous month uploads"
        echo "  --help, -h          Show this help message"
        echo ""
        echo "DESCRIPTION:"
        echo "  Downloads uploads from specified environment (staging or live) using SSH."
        echo "  Must be executed from within a site's subdirectory under '~/Sites'."
        echo ""
        echo "REQUIREMENTS:"
        echo "  • Must be run from within ~/Sites/[sitename]/ directory"
        echo "  • SSH alias configured: [sitename]-s or [sitename]-l"
        echo "  • rsync installed"
        echo "  • SSH access to remote server"
        echo ""
        echo "EXCLUSIONS:"
        echo "  • *.pdf files (excluded by default)"
        echo "  • *.docx files (excluded by default)"
        echo ""
        echo "EXAMPLES:"
        echo "  cd ~/Sites/mysite && getups s       # Download all staging uploads"
        echo "  cd ~/Sites/mysite && getups l -latest # Download recent live uploads"
        echo ""
        echo "SSH CONFIG:"
        echo "  Requires entries in ~/.ssh/config like:"
        echo "  Host mysite-s"
        echo "    HostName staging.example.com"
        echo "    User username"
        echo ""
        return 0
        fi
    done

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

    # Pre-check: Validate SSH configuration exists
    if ! grep -q "^Host $ssh_alias$" ~/.ssh/config; then
        echo "❌ Error: SSH alias '$ssh_alias' not found in ~/.ssh/config"
        echo ""
        echo "Please add an entry like:"
        echo "Host $ssh_alias"
        echo "  HostName your-server.com"
        echo "  User your-username"
        echo "  IdentityFile ~/.ssh/your-key"
        echo ""
        return 1
    fi

    # Load configuration for SSH timeout
    load_dotfiles_config 2>/dev/null || true
    local ssh_timeout="${SSH_TIMEOUT:-10}"
    
    # Pre-check: Test SSH connectivity before starting transfer
    echo "🔍 Testing SSH connectivity to $ssh_alias..."
    if ! ssh -q -o ConnectTimeout="$ssh_timeout" "$ssh_alias" exit 2>/dev/null; then
        echo "❌ Error: Cannot establish SSH connection to '$ssh_alias'"
        echo ""
        echo "Please check:"
        echo "  • SSH server is running and accessible"
        echo "  • SSH key authentication is working"
        echo "  • Network connectivity to remote server"
        echo "  • SSH config entry is correct"
        echo ""
        echo "Test with: ssh $ssh_alias"
        return 1
    fi
    echo "✅ SSH connectivity verified"

    # Pre-check: Verify remote uploads directory exists
    echo "🔍 Verifying remote uploads directory..."
    if ! ssh -q "$ssh_alias" "test -d ~/www/wp-content/uploads" 2>/dev/null; then
        echo "❌ Error: Remote uploads directory not found at ~/www/wp-content/uploads"
        echo ""
        echo "Please verify:"
        echo "  • WordPress is installed on remote server"
        echo "  • Path ~/www/wp-content/uploads exists"
        echo "  • You have read permissions"
        echo ""
        return 1
    fi
    echo "✅ Remote uploads directory verified"

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

        # Build exclude options from configuration
        local -a exclude_opts=()
        for pattern in ${UPLOAD_EXCLUDES:-*.pdf *.docx}; do
            exclude_opts+=(--exclude "$pattern")
        done

        echo "📁 Syncing uploads from $ssh_alias for $current_year/$current_month..."
        rsync -av --progress \
            "${exclude_opts[@]}" \
            "$ssh_alias:~/www/wp-content/uploads/$current_year/$current_month/" \
            "./$current_year/$current_month/"

        echo "📁 Syncing uploads from $ssh_alias for $prev_year/$prev_month..."
        rsync -av --progress \
            "${exclude_opts[@]}" \
            "$ssh_alias:~/www/wp-content/uploads/$prev_year/$prev_month/" \
            "./$prev_year/$prev_month/"
    else
        # Build exclude options from configuration
        local -a exclude_opts=()
        for pattern in ${UPLOAD_EXCLUDES:-*.pdf *.docx}; do
            exclude_opts+=(--exclude "$pattern")
        done

        echo "📁 Syncing all uploads from $ssh_alias..."
        rsync -av --progress \
            "${exclude_opts[@]}" \
            "$ssh_alias:~/www/wp-content/uploads/" .
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
        echo "❌ Error: Uploads directory not found at ~/Sites/${sitedir}/wp-content/uploads"
        return 1
    fi

    # Load configuration for SSH timeout and excludes
    load_dotfiles_config 2>/dev/null || true
    local ssh_timeout="${SSH_TIMEOUT:-10}"
    
    # Pre-check: Test SSH connectivity before uploading
    echo "🔍 Testing SSH connectivity to $sshalias..."
    if ! ssh -q -o ConnectTimeout="$ssh_timeout" "$sshalias" exit 2>/dev/null; then
        echo "❌ Error: Cannot establish SSH connection to '$sshalias'"
        echo ""
        echo "Please check:"
        echo "  • SSH server is running and accessible"
        echo "  • SSH key authentication is working"
        echo "  • Network connectivity to remote server"
        echo "  • SSH config entry for $sshalias exists"
        echo ""
        return 1
    fi
    echo "✅ SSH connectivity verified"

    # Pre-check: Verify remote uploads directory exists and is writable
    echo "🔍 Verifying remote uploads directory..."
    if ! ssh -q "$sshalias" "test -d ~/www/wp-content/uploads && test -w ~/www/wp-content/uploads" 2>/dev/null; then
        echo "❌ Error: Remote uploads directory not found or not writable at ~/www/wp-content/uploads"
        echo ""
        echo "Please verify:"
        echo "  • WordPress is installed on remote server"
        echo "  • Path ~/www/wp-content/uploads exists"
        echo "  • You have write permissions to the directory"
        echo ""
        return 1
    fi
    echo "✅ Remote uploads directory verified"

    echo "📤 Pushing uploads to $sshalias..."
    cd ~/Sites/"${sitedir}"/wp-content/uploads || return
    rsync -avzW --progress * "$sshalias:~/www/wp-content/uploads"
}

# Get recent uploads
getrecentuploads() {
   current=${PWD##*/}
   cd ~/Sites/$current/wp-content/uploads || return

   TARGET=~/Sites/$current/wp-content/uploads
   HOST=$current-l
   SOURCE=/home/djerriwa/www/wp-content/uploads

   touch $TARGET/last_sync

   rsync \
       -ahrv \
       --update \
       --files-from=<(ssh $HOST "find $SOURCE -type f -newer $SOURCE/last_sync -exec realpath --relative-to=$SOURCE '{}' \;") \
       $HOST:$SOURCE \
       $TARGET

   rsync $TARGET/last_sync $HOST:$SOURCE
}