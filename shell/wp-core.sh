# Download the current site's uploads
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

# Push uploads to remote
pushups() {
    current=${PWD##*/}
    cd ~/Sites/$current/wp-content/uploads || return
    rsync -avzW --progress * "$current-$1:~/www/wp-content/uploads"
    cd ~/Sites/$current/wp-content/themes/$current
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
alias dmcweb="wp user update admin --user_pass=dmcweb"
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
