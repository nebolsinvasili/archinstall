git_status() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    local g_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
    echo " %F{green}$g_branch%f"
  fi
}

PROMPT='%F{blue}  %2~%f%F{gray}$(git_status) ∮%  ' #'%F{blue}  %2~%f%F{gray} ∮%  ' #'%B%(!.#.$)%b '

setopt prompt_subst
