!/bin/bash

curl -f https://zed.dev/install.sh | sh

mkdir -p ~/.config/zed

cat <<EOF > ~/.config/zed/settings.json
{
  "auto_update": true,
  "auto_install_extensions": {
    "html": true,
    "rust": true,
    "python": true
  },
  "format_on_save": "on",
  "theme": "One Dark"
}
EOF

export PATH=$PATH:$HOME/.local/bin

fish_add_path -U /home/parinya/.local/bin
