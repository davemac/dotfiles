# Pull a production WP database to an existing local site
#
# Usage: pullprod
#
# This function does the following:
# 1. Resets the local database
# 2. Pulls the production database
# 3. Imports the production database
# 4. Searches and replaces the production URL with the local URL
# 5. Updates plugins, themes, and core
# 6. Deactivates worker and WP Rocket
# 7. Activates Query Monitor and acf-theme-code-pro
# 8. Updates siteurl option
# 9. Sets blog_public to 0
# 10. Opens the site in a browser
pullprod() {
   START=$(date +%s)
   current=${PWD##*/}
   cd ~/Sites/$current
   wp db export _db.sql
   wp db reset --yes
   wp @prod db export - > $current.sql
   echo "rsync of remote database to $current directory complete."
   wp db import
   rm -rf $current.sql
   wp plugin update --all
   wp theme update --all
   wp core update
   wp core language update
   wp plugin deactivate worker wp-rocket passwords-evolved
   wp plugin activate query-monitor acf-theme-code-pro

   production_url=$(wp @prod option get siteurl 2>&1 | tr -d '\n')
   echo "Production URL is: $production_url"

   wp search-replace "${production_url}" "https://${current}.localhost" --all-tables --precise

   wp option update blog_public 0
   dmcweb
   cd ~/Sites/$current/wp-content/themes/$current
   sed -i "" "s/dmcstarter/$current/g" README.md
   wp login install --activate --yes
   wp login as admin --launch

   END=$(date +%s)
   DIFF=$(( $END - $START ))
   echo -e "\n$production_url database now in use on $current.localhost site.\nIt took $DIFF seconds, enjoy!\n"
}

# Pull a staging WP database to an existing local site
pullstage() {
   START=$(date +%s)
   current=${PWD##*/}
   cd ~/Sites/$current
   wp db export _db.sql
   wp db reset --yes
   wp @stage db export - > $current.sql
   echo "rsync of staging database to local $current database complete."
   wp db import
   rm -rf $current.sql
   wp plugin update --all
   wp theme update --all
   wp core update
   wp core language update
   wp plugin activate query-monitor acf-theme-code-pro
   wp plugin deactivate passwords-evolved
   staging_url=$(wp @stage option get siteurl)
   wp search-replace ${staging_url/$'\n'} https://$current.localhost --all-tables --precise
   dmcweb
   cd ~/Sites/$current/wp-content/themes/$current
   sed -i "" "s/dmcstarter/$current/g" README.md

   END=$(date +%s)
   DIFF=$(( $END - $START ))
   echo -e "\n$staging_url database now in use on https://$current.localhost site.\nIt took $DIFF seconds, enjoy!\n"
}

# Pull a testing WP database to an existing local site
pulltest() {
   START=$(date +%s)
   wp db export _db.sql
   wp db reset --yes
   current=${PWD##*/}
   wp @test db export - > $current.sql
   echo "rsync of test database to local $current database complete."
   wp db import
   rm -rf $current.sql
   wp plugin update --all
   wp theme update --all
   wp core update
   wp core language update
   wp plugin activate query-monitor acf-theme-code-pro
   wp plugin deactivate passwords-evolved
   test_url=$(wp @test option get siteurl)
   wp search-replace ${test_url/$'\n'} https://$current.localhost --all-tables --precise
   dmcweb
   cd ~/Sites/$current/wp-content/themes/$current
   END=$(date +%s)
   DIFF=$(( $END - $START ))
   echo -e "\n$test_url database now in use on https://$current.localhost site.\nIt took $DIFF seconds, enjoy!\n"
}

# Push a local WP database to an existing staging site
pushstage() {
   START=$(date +%s)
   current=${PWD##*/}
   cd ~/Sites/$current || return

   wp db export $current.sql
   rsync $current.sql $current-s:~/

   wp @stage db export backup.sql
   wp @stage db reset --yes

   wp @stage db import $current.sql
   wp @stage search-replace "https://$current.localhost" "https://$current.dmctest.com.au" --all-tables --precise

   wp @stage plugin deactivate query-monitor acf-theme-code-pro wordpress-seo
   wp @stage option update blog_public 0

   cd ~/Sites/$current/wp-content/themes/$current
   END=$(date +%s)
   DIFF=$(( $END - $START ))
   echo -e "\n$current.localhost database now in use on $push_staging_url site.\nIt took $DIFF seconds, enjoy!\n"
}
