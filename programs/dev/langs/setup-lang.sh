#!/usr/bin/env sh

for d in */; do 
  [ -f "$d/install.sh" ] && (cd "$d" && chmod +x install.sh && ./install.sh); 
done
