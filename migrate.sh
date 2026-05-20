nix flake update nixpkgs

nix run nixpkgs#nixfmt -- *.nix

nix run home-manager/master -- switch --flake .#parinya -b backupF
