# Dotfiles

My collection of shell functions and configuration files for WordPress development.

## Directory Structure

```
dotfiles/
├── shell/
│   ├── deployment.sh      # Theme deployment (firstdeploy, depto)
│   ├── git.sh            # Git utilities and branch management
│   ├── utils.sh          # System utilities and common aliases
│   ├── wp-core.sh        # WordPress WP-CLI shortcuts and aliases
│   ├── wp-db.sh          # All database operations (pullprod, dmcweb, wp_db_optimise, etc.)
│   ├── wp-dev.sh         # Development tools (wp74, genlorem, scaffolding)
│   ├── wp-diagnostics.sh # Troubleshooting (wp_plugin_diags)
│   └── wp-uploads.sh     # Upload/file sync operations (getups, pushups)
├── .gitignore
└── README.md
```

## Installation

1. Clone this repository:
    ```bash
    cd ~
    git clone git@github.com:davemac/dotfiles.git
    ```

2. Create a symbolic link to your home directory:
    ```bash
    ln -s ~/dotfiles/shell ~/.shell-functions
    ```

3. Add the following to your `~/.zprofile`:
    ```bash

    # Load shell functions
    for file in ~/.shell-functions/*.sh; do
        source "$file"
        # Force reload of aliases
        alias -g
    done
    ```

4. Reload your profile:
    ```bash
    source ~/.zprofile
    ```

5. Get started by viewing all available commands:
    ```bash
    listcmds
    ```
    This will display a comprehensive list of all functions and aliases organized by category.

## Function Groups

### WordPress Core Shortcuts (wp-core.sh)
Essential WP-CLI aliases and shortcuts:
- `updatem`: Update all plugins, themes, and WordPress core
- `siteurl`: Display current site URL from database
- `plugincheck`: Check for plugin conflicts
- `onetimeinstall`: Install one-time login plugin on production
- `onetimeadmin`: Generate one-time login link for admin

### Database Operations (wp-db.sh)
All database-related functions consolidated:
- `pullprod`: Pull production database to local environment
- `pullstage`: Pull staging database to local
- `pulltest`: Pull testing database to local
- `pushstage`: Push local database to staging
- `dmcweb`: Update admin password to 'dmcweb'
- `check-featured-image`: Find posts missing featured images
- `update-wc-db`: Update WooCommerce on multiple hosts
- `wp_db_optimise` / `wpopt`: Comprehensive database cleanup and optimization
- `wp_db_table_delete` / `wpdel`: Interactive database table cleanup

### Upload Management (wp-uploads.sh)
File sync operations between environments:
- `getups`: Sync WordPress uploads directory from remote
- `pushups`: Push uploads to remote server
- `getrecentuploads`: Sync only recently modified uploads

### Development Tools (wp-dev.sh)
Development utilities and content creation:
- `wp74`: Execute WP-CLI with PHP 7.4
- `genlorem`: Generate lorem ipsum content
- `gencpt`: Scaffold custom post types
- `genctax`: Scaffold custom taxonomies

### Diagnostics & Troubleshooting (wp-diagnostics.sh)
Tools for debugging WordPress issues:
- `wp_plugin_diags`: Systematically test plugins to isolate fatal errors

### Theme Deployment (deployment.sh)
Deployment automation:
- `firstdeploy`: Initial site deployment to staging
- `firstdeploy-prod`: Initial site deployment to production
- `depto`: Deploy theme files to staging or production

### Git Utilities (git.sh)
Version control workflow:
- `new_branch`: Create new branch from ticket ID and title
- Various git aliases and shortcuts

### System Utilities (utils.sh)
General system tools:
- `listcmds`: Display all available commands and functions in a neat table
- File system helpers
- Network utilities
- Homebrew shortcuts
- Directory navigation
- Chrome proxy setup

## Usage Examples

### Upload Management
Sync uploads from live site:
```bash
cd ~/Sites/yoursite
getups l          # Sync all uploads
getups l -latest  # Sync only last 2 months
```

Push uploads to staging:
```bash
pushups -auto -target s  # Auto-detect site and push to staging
```

### Database Operations
Pull production database:
```bash
cd ~/Sites/yoursite
pullprod
```

Optimize local database:
```bash
wp_db_optimise    # Or use alias: wpopt
```

Clean up database tables:
```bash
wp_db_table_delete  # Or use alias: wpdel
```

### Development
Generate sample content:
```bash
genlorem 10 post  # Generate 10 sample posts
```

Use PHP 7.4 with WP-CLI:
```bash
wp74 plugin list  # Run WP-CLI with PHP 7.4
```

### Diagnostics
Test for plugin conflicts:
```bash
cd ~/Sites/yoursite
wp_plugin_diags  # Systematically test each plugin
```

### Deployment
Deploy theme to staging:
```bash
cd ~/Sites/yoursite/wp-content/themes/yoursite
depto -auto -target staging
```

### Git Workflow
Create new feature branch:
```bash
new_branch IR-123 "add new feature"  # Creates feature/IR-123-add-new-feature
```

### Command Reference
List all available commands:
```bash
listcmds  # Display comprehensive list of all functions and aliases
```

## Requirements

- macOS
- Homebrew
- PHP 7.4+ (if using wp74)
- WP-CLI
- Git
- SSH access to deployment servers

## File Structure After Installation

```
~/
├── .shell-functions -> /Users/dave/dotfiles/shell/
└── dotfiles/
    ├── shell/
    │   ├── deployment.sh
    │   ├── git.sh
    │   ├── utils.sh
    │   ├── wp-core.sh
    │   ├── wp-db.sh
    │   ├── wp-dev.sh
    │   ├── wp-diagnostics.sh
    │   └── wp-uploads.sh
    ├── .gitignore
    └── README.md
```

## Updating

To update the functions:

```bash
cd ~/dotfiles
git pull
```

No additional steps needed as the symbolic link will always point to the current files.

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request