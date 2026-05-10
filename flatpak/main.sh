#!/bin/bash

flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

programs=(
  com.discordapp.Discord
  com.obsproject.Studio
  md.obsidian.Obsidian
  com.rustdesk.RustDesk
  org.signal.Signal
  com.github.tchx84.Flatseal
  com.usebruno.Bruno
  io.dbeaver.DBeaverCommunity
  com.usebottles.bottles
  org.gaphor.Gaphor
)

flatpak install --user "${programs[@]}" -y
