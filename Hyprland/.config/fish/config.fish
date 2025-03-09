#source /usr/share/cachyos-fish-config/cachyos-config.fish

# Initialize starship prompt
starship init fish | source
alias vim nvim


## Useful aliases
# Replace ls with eza
alias la='eza -al --color=always --group-directories-first --icons' # preferred listing
alias ls='eza -a --color=always --group-directories-first --icons'  # all files and dirs
alias ll='eza -l --color=always --group-directories-first --icons'  # long format
alias lt='eza -aT --color=always --group-directories-first --icons' # tree listing
alias l.="eza -a | grep -e '^\.'"

#alias fastfetch="fastfetch --logo arch"
# show only dotfiles

# overwrite greeting
# potentially disabling fastfetch
#function fish_greeting
#    # smth smth
#end

