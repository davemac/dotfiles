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