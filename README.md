# Dotfiles

My collection of shell functions and configuration files for WordPress development, WP database operations, deployments and system utilities.

## Directory Structure

```
dotfiles/
├── shell/
│   ├── deployment.sh    # Deployment functions (firstdeploy, depto, etc.)
│   ├── git.sh          # Git utilities and branch management
│   ├── utils.sh        # System utilities and common aliases
│   ├── wp-core.sh      # WordPress core functions (getups, pushups, etc.)
│   └── wp-db.sh        # WordPress database operations (pullprod, pullstage, etc.)
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

## Function Groups

### WordPress Core (wp-core.sh)
- `getups`: Sync WordPress uploads directory from remote
- `pushups`: Push uploads to remote server
- `wp74`: Execute WP-CLI with PHP 7.4
- various WP-CLI aliases and utilities

### Database Operations (wp-db.sh)
- `pullprod`: Pull production database to local
- `pullstage`: Pull staging database to local
- `pulltest`: Pull testing database to local
- `pushstage`: Push local database to staging

### Deployment (deployment.sh)
- `firstdeploy`: Initial site deployment to staging
- `firstdeploy-prod`: Initial site deployment to production
- `depto`: Deploy theme files to staging or production

### Git Utilities (git.sh)
- `new_branch`: Create new branch from ticket ID and title
- Various git aliases and shortcuts

### System Utilities (utils.sh)
- File system helpers
- Network utilities
- Homebrew shortcuts
- Directory navigation
- Chrome proxy setup

## Usage Examples

Sync uploads from live site:
```bash
cd ~/Sites/yoursite
getups l          # Sync all uploads
getups l -latest  # Sync only last 2 months
```

Pull production database:
```bash
cd ~/Sites/yoursite/wp-content/themes/yoursite
pullprod
```

Deploy theme to staging:
```bash
cd ~/Sites/yoursite/wp-content/themes/yoursite
depto -auto -target staging
```

Create new feature branch:
```bash
new_branch IR-123 "add new feature"  # Creates feature/IR-123-add-new-feature
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
    │   └── wp-db.sh
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