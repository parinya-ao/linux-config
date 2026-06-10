sudo dnf install dnf-plugins-core -y

sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-beta.s3.brave.com/brave-browser-beta.repo

sudo dnf install brave-origin-beta -y
