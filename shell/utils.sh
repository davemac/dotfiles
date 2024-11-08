# File system utilities
alias showsize="du -sh ./*"
alias dsclean="find . -type f -name .DS_Store -delete"
alias ls="ls -Ghal"
alias rsync="rsync -avzW --progress"
alias gbb="grunt buildbower"

# Homebrew utilities
alias brewup="brew update && brew upgrade"
alias brewupc="brew update && brew upgrade && brew cleanup"

# Network utilities
alias myip="curl ifconfig.co"
alias socksit="ssh -D 8080 keith"
alias flushdns="sudo dscacheutil -flushcache;sudo killall -HUP mDNSResponder;say dns cache flushed"

# Quick access to config files
alias zp="code ~/.zprofile"
alias sshconfig="code ~/.ssh/config"

# YouTube download utility
ytaudio() {
   yt-dlp -f bestaudio --extract-audio --audio-format mp3 --audio-quality 0 "$1"
}

# Move up X directories
up() {
   local d=""
   limit=$1
   for ((i=1 ; i <= limit ; i++))
   do
       d=$d/..
   done
   d=$(echo $d | sed 's/^\///')
   if [ -z "$d" ]; then
       d=..
   fi
   cd $d || return
}

# Chrome with proxy
chromeproxy() {
   ssh -N -D 9090 keith

   "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
   --user-data-dir="$HOME/proxy-profile" \
   --proxy-server="socks5://localhost:9090"
}

# VSCode helper
code () {
   VSCODE_CWD="$PWD" open -n -b "com.microsoft.VSCode" --args $* ;
}

# Send to termbin
alias tb="nc termbin.com 9999"
