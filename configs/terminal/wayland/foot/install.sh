#!/bin/sh

yay -S foot --noconfirm

stow -R -v -t ~/.config config
