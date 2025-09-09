# Dotfiles

My collection of shell functions and configuration files for WordPress development.

## Directory Structure

```
dotfiles/
├── shell/
│   ├── config.sh         # Global configuration management
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

## How It Works

This dotfiles system uses a **centralized configuration approach** that keeps sensitive information secure while maintaining full functionality:

### 🔧 **Configuration System**
- **`shell/config.sh`** - Central configuration manager with safe defaults
- **`.dotfiles-config`** - Your personal settings file (git-ignored for security)
- **Automatic loading** - Functions load config when needed, no manual setup required

### 🔒 **Security Model**
- All sensitive values (passwords, hostnames, API keys) are stored in `.dotfiles-config`
- This file is **git-ignored** so it never gets committed to the public repository
- Other users get safe defaults and can create their own personal configuration
- You keep full functionality with your actual credentials

### ⚡ **Loading Pattern**
Each function automatically loads configuration when called:
```bash
load_dotfiles_config 2>/dev/null || true  # Safe loading pattern
```

## Installation

1. **Clone this repository:**
    ```bash
    cd ~
    git clone git@github.com:davemac/dotfiles.git
    ```

2. **Create symbolic link to your home directory:**
    ```bash
    ln -s ~/dotfiles/shell ~/.shell-functions
    ```

3. **Add loading code to your shell config** (choose your shell):
    
    **For zsh (~/.zshrc):**
    ```bash
    # Load shell functions (interactive features)
    for file in ~/.shell-functions/*.sh; do
        source "$file"
    done
    ```
    
    **For bash (~/.bashrc):**
    ```bash
    # Load shell functions
    for file in ~/.shell-functions/*.sh; do
        source "$file"
    done
    ```

4. **Reload your shell:**
    ```bash
    source ~/.zshrc  # or ~/.bashrc
    ```

5. **Create your personal configuration:**
    ```bash
    dotfiles_config --create  # Creates .dotfiles-config in repo root
    dotfiles_config --edit    # Edit your personal settings
    ```

6. **Get started:**
    ```bash
    listcmds  # View all available commands organized by category
    ```

### 🛠️ **First-Time Setup**
After installation, you'll want to customize your `.dotfiles-config` file with your actual values:
- `DEV_WP_PASSWORD` - Your preferred WordPress development password  
- `SSH_PROXY_HOST` - Your SSH proxy server hostname
- `WC_HOSTS` - Your WooCommerce production server aliases
- And other personal settings...

## Function Groups

### Configuration Management (config.sh)
Central configuration system that manages all dotfiles settings securely:
- `dotfiles_config --create`: Create your personal configuration file  
- `dotfiles_config --show`: Display current configuration settings and values
- `dotfiles_config --edit`: Edit configuration file with your default editor
- `dotfiles_config --help`: Show detailed configuration help
- `load_dotfiles_config`: Load configuration (used automatically by functions)

**Key Features:**
- 🔒 Keeps sensitive data out of the public repository
- 🎯 Provides safe defaults for all users
- ⚡ Auto-loads when functions need configuration  
- 🛠️ Easy customization through simple config file

### WordPress Core Shortcuts (wp-core.sh)
Essential WP-CLI aliases and shortcuts:
- `updatem`: Update all plugins, themes, and WordPress core
- `siteurl`: Display current site URL from database
- `plugincheck`: Check for plugin conflicts
- `onetimeinstall`: Install one-time login plugin on production
- `onetimeadmin`: Generate one-time login link for admin

### Database Operations (wp-db.sh)
All database-related functions consolidated:

**Database Sync Functions:**
- `pullprod`: Pull production database to local environment (full sync)
- `pullstage`: Pull staging database to local environment
- `pulltest`: Pull testing database to local environment
- `pushstage`: Push local database to staging environment
- `pulldb`: Export production database to timestamped local file (alias)

**User Management:**
- `dmcweb [user]`: Update user password to configured dev password (defaults to admin)

**Database Analysis:**
- `check-featured-image`: Find posts missing featured images

**Multi-Host Operations:**
- `update-wc-db`: Update WooCommerce database on multiple configured hosts

**Database Optimization:**
- `wp_db_optimise [options]` / `wpopt`: Comprehensive database cleanup and optimization
- `wp_db_table_delete [options]` / `wpdel`: Interactive database table cleanup

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
Version control workflow and convenient aliases:
- `new_branch`: Create new branch from ticket ID and title
- `gs`: Git status (alias)
- `ga`: Git add (alias)  
- `gca`: Git commit all (alias)
- `gc`: Git commit (alias)
- `gl`: Formatted git log with graph, dates, and decoration
- `glcss`: Git log for CSS/Sass files from the last year with line numbers

### System Utilities (utils.sh)
General system tools and productivity functions:
- `listcmds`: Display all available commands and functions in a neat table

**File System Utilities:**
- `showsize`: Display directory sizes (alias: du -sh ./*)
- `dsclean`: Delete all .DS_Store files recursively
- `ls`: Enhanced ls with colors and details (alias)  
- `up [N]`: Move up N directories in the filesystem

**Network Utilities:**
- `myip`: Display your public IP address
- `socksit`: Create SSH SOCKS proxy (uses configured SSH_PROXY_HOST)
- `chromeproxy`: Launch Chrome with SSH SOCKS proxy
- `flushdns`: Flush DNS cache and announce completion

**Development Tools:**
- `zp`: Edit ~/.zprofile in Cursor (alias)
- `sshconfig`: Edit ~/.ssh/config in Cursor (alias)
- `code`: Open files in VSCode with proper setup
- `tb`: Send text to termbin.com (alias)

**Homebrew Utilities:**
- `brewup`: Update Homebrew packages (alias)
- `brewupc`: Update Homebrew packages and cleanup (alias)

**Media Download Tools:**
- `ytaudio [URL]`: Download YouTube audio as MP3
- `download_vimeo_hd` / `dlvimeo`: Download all Vimeo videos from a page in HD with metadata
- `wp_download_images` / `wpdli`: Download images from clipboard HTML to wp-content/uploads

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

### Media Utilities (utils.sh)
Download images referenced in clipboard HTML into the current site's uploads directory:
```bash
# From within ~/Sites/yoursite (auto-detects site path)
wp_download_images

# Or specify the site path explicitly
wp_download_images -p ~/Sites/yoursite
```

Download Vimeo videos from a lesson page (HD with source URL metadata):
```bash
# Use the short alias
dlvimeo https://example.com/lesson-page/

# Or the full function name
download_vimeo_hd https://example.com/lesson-page/
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
├── .shell-functions -> ~/dotfiles/shell/     # Symlink to shell functions  
└── dotfiles/
    ├── shell/
    │   ├── config.sh                         # Central configuration system
    │   ├── deployment.sh                     # Theme deployment functions
    │   ├── git.sh                           # Git utilities
    │   ├── utils.sh                         # System utilities
    │   ├── wp-core.sh                       # WordPress shortcuts
    │   ├── wp-db.sh                         # Database operations
    │   ├── wp-dev.sh                        # Development tools
    │   ├── wp-diagnostics.sh                # Troubleshooting
    │   └── wp-uploads.sh                    # File sync operations
    ├── .dotfiles-config                     # Your personal settings (git-ignored)
    ├── .gitignore                           # Includes .dotfiles-config
    └── README.md
```

### 📁 **Important Files:**
- **`~/.shell-functions/`** - Symlink that makes all functions available in your shell
- **`.dotfiles-config`** - Contains your personal/sensitive configuration values
- **`.gitignore`** - Ensures `.dotfiles-config` is never committed to git

## Updating

To update the functions:

```bash
cd ~/dotfiles
git pull
```

**No additional steps needed!** The symbolic link ensures you always use the latest files.

### ⚠️ **Important Notes:**
- Your `.dotfiles-config` file will never be overwritten during updates
- New configuration options may be added - run `dotfiles_config --show` to see available settings
- Functions automatically load the latest configuration when called

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request