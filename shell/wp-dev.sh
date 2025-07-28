# WordPress Development Tools & Content Creation Functions
#
# This file contains functions for WordPress development, scaffolding,
# and content generation utilities.

# WP-CLI with PHP 7.4
wp74() {
    /opt/homebrew/Cellar/php@7.4/7.4.33_5/bin/php /usr/local/bin/wp "$@"
}

# Generate lorem ipsum content
genlorem(){
    curl "https://loripsum.net/api/5/medium/link/ul/ol/bq/headers/prude" | wp post generate --post_type="$2" --count="$1" --post_content;
}

# Scaffold functions
gencpt(){
    wp scaffold post-type $1 --label="$2" --textdomain=dmcstarter --theme --force
}

genctax(){
    wp scaffold taxonomy $1 --post_types=$2 --label="$3" --textdomain=dmcstarter --theme --force
}