alias grub-update="sudo grub-mkconfig -o /boot/grub/grub.cfg"

# pacman related
alias pcs="sudo pacman -S"
alias pcr="sudo pacman -R"
alias pcrs="sudo pacman -Rs"

alias ls='exa -lah --color --icons'

alias r='ranger'

alias c='clear'
alias q='exit'

alias mkdircd='mkdircd() { mkdir -p "$1" && cd "$1"; } && mkdircd'

alias zmk-studio='WEBKIT_DISABLE_COMPOSITING_MODE=1 GDK_BACKEND=x11 zmk-studio'

alias uprog='env WINEPREFIX=/home/nebolsinvasili/.wbolid /home/nebolsinvasili/.wbolid/drive_c/BOLID/UProg/UProg.exe'
alias pprog='env WINEPREFIX=/home/nebolsinvasili/.wbolid /home/nebolsinvasili/.wbolid/drive_c/BOLID/PProg/PProg.exe'
