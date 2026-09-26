#!/usr/bin/env sh

for d in */; do 
  [ -f "$d/setup.sh" ] && (cd "$d" && chmod +x setup.sh && ./setup.sh); 
done
