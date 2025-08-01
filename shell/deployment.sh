# For initial site deployment to staging server
firstdeploy() {
   current=${PWD##*/}
   cd ~/Sites/$current || return

   echo "Staging url fragment (eg dmcweb):"
   read surl
   echo "Staging database name:"
   read dbname
   echo "Staging database user:"
   read dbuser
   echo "Staging database password:"
   read dbpass

   wp db export $current.sql
   rsync $current.sql $current-s:~/

   wp @stage core download --path=www --skip-content

   wp @stage config create --dbname="$dbname" --dbuser="$dbuser" --dbpass="$dbpass" --skip-check --extra-php <<PHP
   define( 'WP_DEBUG', false );
   define('SAVEQUERIES', false);
   define( 'DISALLOW_FILE_EDIT', true );
   define( 'WP_POST_REVISIONS', 5 );
   define( 'JETPACK_STAGING_MODE', true);
   define( 'WP_ENVIRONMENT_TYPE', 'staging' );
   define( 'ACF_PRO_LICENSE', getenv('WP_ACF_PRO_LICENSE') );
   define( 'GOOGLE_API_KEY', getenv('WP_GOOGLE_API_KEY') );
PHP

   wp @stage db import $current.sql
   wp @stage search-replace "$current.localhost" "$surl.dmctest.com.au" --all-tables --precise

   # Create wp-content directory if it doesn't exist
   ssh $current-s "mkdir -p ~/www/wp-content"

   # Rsync theme and mu-plugins, including vendor directories
   rsync --exclude-from "rsync-exclude.txt" wp-content/themes $current-s:~/www/wp-content/
   rsync --exclude-from "rsync-exclude.txt" wp-content/mu-plugins $current-s:~/www/wp-content/
   rsync --exclude-from "rsync-exclude.txt" wp-content/plugins $current-s:~/www/wp-content/

    # rsync --exclude-from "rsync-exclude.txt" wp-content $current-s:~/www

   wp @stage plugin deactivate query-monitor acf-theme-code-pro wp-seopress
   wp @stage plugin delete query-monitor acf-theme-code-pro wp-seopress
   wp @stage option update blog_public 0
   wp rewrite flush

   cd ~/www/wp-content
   find . -type d -exec chmod 755 {} \;
   find . -type f -exec chmod 644 {} \;
}

# For initial site deployment to production server
firstdeploy-prod() {
   current=${PWD##*/}
   cd ~/Sites/$current || return

   echo "Database name:"
   read dbname
   echo "Database user:"
   read dbuser
   echo "Database password:"
   read dbpass
   echo "Live URL (no https://):"
   read liveurl

   wp db export $current.sql
   rsync $current.sql $current-l:~/

   wp @prod core download --path=www --skip-content

   wp @prod config create --dbname="$dbname" --dbuser="$dbuser" --dbpass="$dbpass" --skip-check --extra-php <<PHP
   define( 'WP_DEBUG', false );
   define('SAVEQUERIES', false);
   define( 'DISALLOW_FILE_EDIT', true );
   define( 'WP_POST_REVISIONS', 5 );
   define( 'JETPACK_STAGING_MODE', true);
PHP

   wp @prod db import $current.sql
   wp @prod search-replace "https://$current.localhost" "https://$liveurl" --all-tables --precise

   rsync --exclude-from "rsync-exclude.txt" wp-content $current-l:~/www

   wp @prod plugin deactivate query-monitor acf-theme-code-pro
   wp @prod plugin delete query-monitor acf-theme-code-pro
}

# Deploys the current theme to a specified remote server, either staging or production.
#
# Options:
#   -auto   : Automatically determine the theme directory and SSH alias based on the current working directory.
#   -target : Specify the deployment target, either 'staging' (default) or 'production'.
#
# Examples:
#   depto                           # Deploy to staging, prompts for SSH alias and theme
#   depto -auto                     # Auto-deploy current theme to staging
#   depto -target staging           # Deploy to staging, prompts for SSH alias and theme
#   depto -auto -target production  # Auto-deploy current theme to production
#
# The function uses rsync to transfer theme files to the specified remote server.
# If -auto is not used, the user is prompted to enter the SSH alias and theme directory.
depto() {
   auto=false
   target="staging"  # Default to staging

   while [ "$1" != "" ]; do
       case $1 in
           -auto )    auto=true
                     shift
                     ;;
           -target ) shift
                    if [ "production" = "$1" ]; then
                        target="production"
                    elif [ "staging" = "$1" ]; then
                        target="staging"
                    else
                        echo "Error: -target must be either 'staging' or 'production'"
                        return 1
                    fi
                    shift
                    ;;
           * )       shift
                    ;;
       esac
   done

   env_suffix="-s"
   if [ "production" = "$target" ]; then
       env_suffix="-l"
   fi

   if [ true = "$auto" ]; then
       current_dir=$(pwd)
       theme=$(basename "$current_dir")
       sshalias="${theme}${env_suffix}"
   else
       echo "ssh alias to deploy to eg street${env_suffix}"
       read sshalias
       echo "$sshalias is the alias"
       echo "theme directory eg street"
       read theme
       echo "$theme is the theme"
   fi

   rsync dist *.php blocks acf-json lib page-templates post-types taxonomies template-parts wp-cli woocommerce "$sshalias":~/www/wp-content/themes/"$theme"
   rsync source/php "$sshalias":~/www/wp-content/themes/"$theme"/source
   rsync source/images "$sshalias":~/www/wp-content/themes/"$theme"/source
   rsync vendor/autoload.php "$sshalias":~/www/wp-content/themes/"$theme"/vendor
   rsync vendor/composer "$sshalias":~/www/wp-content/themes/"$theme"/vendor
}
