#!/bin/bash

programs=(
  com.discordapp.Discord
  com.obsproject.Studio
  md.obsidian.Obsidian
  com.rustdesk.RustDesk
  org.signal.Signal
  com.github.tchx84.Flatseal
  org.vinegarhq.Sober
  com.usebruno.Bruno
  io.dbeaver.DBeaverCommunity
  com.usebottles.bottles
)

flatpak install "${programs[@]}" -y
