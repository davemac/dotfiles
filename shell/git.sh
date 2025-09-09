# Git Utilities and Workflow Functions
#
# Git aliases and functions to streamline version control workflows,
# branch management, and repository operations.
#
# ============================================================================
# FUNCTION INDEX
# ============================================================================
#
# Git Aliases:
# • gs                         - Git status (alias: git status)
# • ga                         - Git add (alias: git add)
# • gca                        - Git commit all (alias: git commit -a)
# • gc                         - Git commit (alias: git commit)
# • gl                         - Formatted git log with graph, dates, and decoration
# • glcss                      - Git log for CSS/Sass files from the last year with line numbers
#
# Branch Management:
# • new_branch [options] <ticket_id> <title> - Create new branch from ticket ID and title
#   Options:
#   - -u                      : Create update/* branch instead of feature/*
#   
#   Examples:
#   - new_branch IR-123 "add new feature"     → feature/IR-123-add-new-feature
#   - new_branch -u IR-456 "update styles"    → update/IR-456-update-styles
#
#   Features:
#   - Automatically sanitizes title for valid branch names
#   - Converts to lowercase and replaces invalid characters with hyphens
#   - Creates and switches to the new branch
#   - Supports both feature and update branch prefixes
#
# ============================================================================

# Git aliases
alias gs="git status "
alias ga="git add "
alias gca="git commit -a "
alias gc="git commit"
alias gl="git log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all"
alias glcss="git log --name-only --since='365 days' | sort -u | awk '/\.(le|c|sa|sc)ss$/{print}' | nl"

# Create a new Git branch from a ticket ID and title
new_branch() {
   if [ "$#" -lt 2 ] || [ "$#" -gt 3 ]; then
       echo "Usage: new_branch [-u] <ticket_id> <title>"
       return 1
   fi

   local update_flag=false
   local ticket
   local title

   # Check if the first argument is the -u flag
   if [ "$1" = "-u" ]; then
       update_flag=true
       ticket="$2"
       title="$3"
   else
       ticket="$1"
       title="$2"
   fi

   # Sanitize and format the title to create a valid branch name
   local sanitized_title=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-zA-Z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//;s/-$//')
   local branch_prefix="feature"

   if [ "$update_flag" = true ]; then
       branch_prefix="update"
   fi

   local branch_name="${branch_prefix}/${ticket}-${sanitized_title}"

   # Create the branch in git
   git checkout -b "$branch_name"
   echo "Branch created: $branch_name"
}
