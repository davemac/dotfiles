# WordPress Development Tools & Content Creation Functions
#
# Development utilities for WordPress theme and plugin development,
# content generation, scaffolding, and testing with different PHP versions.
#
# ============================================================================
# FUNCTION INDEX
# ============================================================================
#
# PHP Version Management:
# • wp74 [wp-cli-args]         - Execute WP-CLI commands using PHP 7.4
#   Uses specific PHP 7.4 binary for compatibility testing
#   Example: wp74 plugin list
#
# Content Generation:
# • genlorem <count> <post_type> - Generate lorem ipsum content posts
#   Parameters:
#   - count: Number of posts to generate
#   - post_type: WordPress post type (post, page, custom_post_type)
#   
#   Features:
#   - Fetches realistic lorem ipsum from loripsum.net API
#   - Includes medium-length paragraphs with links, lists, blockquotes, and headers
#   - Content is family-friendly (prude filter applied)
#   
#   Example: genlorem 10 post
#
# Theme Scaffolding:
# • gencpt <post_type> <label> - Scaffold custom post type
#   Parameters:
#   - post_type: Machine name for the post type
#   - label: Human-readable label for the post type
#   
#   Features:
#   - Generates PHP files in current theme
#   - Uses dmcstarter textdomain (customizable)
#   - Overwrites existing files (--force flag)
#   
#   Example: gencpt portfolio "Portfolio Items"
#
# • genctax <taxonomy> <post_types> <label> - Scaffold custom taxonomy  
#   Parameters:
#   - taxonomy: Machine name for the taxonomy
#   - post_types: Comma-separated post types to attach to
#   - label: Human-readable label for the taxonomy
#   
#   Features:
#   - Generates PHP files in current theme
#   - Associates with specified post types
#   - Uses dmcstarter textdomain (customizable)
#   - Overwrites existing files (--force flag)
#   
#   Example: genctax project_type "portfolio,project" "Project Types"
#
# Requirements:
# • WP-CLI installed and functional
# • Internet connection for lorem ipsum API
# • Write permissions in current theme directory for scaffolding
# • PHP 7.4 installed via Homebrew for wp74 function
#
# ============================================================================

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