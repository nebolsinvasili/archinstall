git_branch() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    local g_branch=$(git symbolic-ref --short HEAD 2>/dev/null || echo "detached")
    echo " %F{green}$g_branch%f"
  fi
}

PROMPT='[%n@%m %2~$(git_branch) ]\$ '

setopt prompt_subst
