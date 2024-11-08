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
