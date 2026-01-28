#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
backup_ts="$(date +%Y%m%d_%H%M%S)"

log() {
  printf '%s\n' "$*"
}

restore_file() {
  local src="$1"
  local dst="$2"
  if [ -f "$src" ]; then
    if [ -f "$dst" ]; then
      mv "$dst" "${dst}.bak_${backup_ts}"
    fi
    mkdir -p "$(dirname "$dst")"
    cp -a "$src" "$dst"
  fi
}

restore_dir() {
  local src="$1"
  local dst="$2"
  if [ -d "$src" ]; then
    if [ -d "$dst" ]; then
      mv "$dst" "${dst}.bak_${backup_ts}"
    fi
    mkdir -p "$dst"
    cp -a "$src/." "$dst/"
  fi
}

ensure_base_packages() {
  sudo apt-get update -y
  sudo apt-get install -y curl git zsh ca-certificates gnupg lsb-release unzip xdg-utils
}

ensure_oh_my_zsh() {
  if [ ! -d "$HOME/.oh-my-zsh" ]; then
    export RUNZSH=no
    export CHSH=no
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  fi
}

ensure_google_chrome_repo() {
  if [ ! -f /etc/apt/sources.list.d/google-chrome.list ]; then
    curl -fsSL https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /usr/share/keyrings/google-chrome.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/google-chrome.gpg] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
    sudo apt-get update -y
  fi
}

ensure_vscode_repo() {
  if [ ! -f /etc/apt/sources.list.d/vscode.list ]; then
    curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | sudo gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg
    echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update -y
  fi
}

install_apt_packages() {
  local list_file="$repo_dir/packages/apt-manual.txt"
  if [ ! -f "$list_file" ]; then
    log "No apt package list found at $list_file"
    return
  fi

  # Always ensure Chrome repo, then install Chrome explicitly if missing from list.
  ensure_google_chrome_repo

  # Install packages listed (skip comments/empty)
  grep -v '^[[:space:]]*$' "$list_file" | grep -v '^[[:space:]]*#' | xargs -r sudo apt-get install -y

  if ! grep -q '^google-chrome-stable$' "$list_file"; then
    sudo apt-get install -y google-chrome-stable || true
  fi
}

install_snaps() {
  local snap_list="$repo_dir/packages/snap-list.txt"
  if [ ! -f "$snap_list" ]; then
    return
  fi

  if ! command -v snap >/dev/null 2>&1; then
    log "snap not available; skipping snap installs"
    return
  fi

  # Expect output from `snap list` (name is first column)
  # Skip header lines and common base snaps.
  awk 'NR>1 {print $1}' "$snap_list" | grep -v '^(core|core18|core20|core22|snapd|bare)$' | while read -r name; do
    [ -n "$name" ] && sudo snap install "$name" || true
  done
}

install_nerd_fonts() {
  local fonts_dir="$HOME/.local/share/fonts"
  local zip_path="/tmp/JetBrainsMono.zip"
  mkdir -p "$fonts_dir"
  if ls "$fonts_dir"/JetBrainsMono* >/dev/null 2>&1; then
    return
  fi
  curl -fL "https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip" -o "$zip_path"
  unzip -o "$zip_path" -d "$fonts_dir" >/dev/null
  rm -f "$zip_path"
  fc-cache -f "$fonts_dir" >/dev/null 2>&1 || true
}

create_chatgpt_shortcut() {
  local apps_dir="$HOME/.local/share/applications"
  mkdir -p "$apps_dir"
  cat > "$apps_dir/chatgpt-web.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=ChatGPT (Web)
Exec=xdg-open https://chatgpt.com
Icon=web-browser
Terminal=false
Categories=Network;WebBrowser;
DESKTOP
}

restore_dotfiles() {
  restore_file "$repo_dir/dotfiles/.zshrc" "$HOME/.zshrc"
  restore_file "$repo_dir/dotfiles/.p10k.zsh" "$HOME/.p10k.zsh"
  restore_file "$repo_dir/dotfiles/.gitconfig" "$HOME/.gitconfig"
}

restore_zsh_assets() {
  restore_dir "$repo_dir/zsh/oh-my-zsh-custom" "$HOME/.oh-my-zsh/custom"
  restore_dir "$repo_dir/zsh/.zsh" "$HOME/.zsh"
}

restore_vscode_settings() {
  restore_dir "$repo_dir/vscode/User" "$HOME/.config/Code/User"
}

install_vscode_extensions() {
  local ext_file="$repo_dir/vscode/extensions.txt"
  if [ ! -f "$ext_file" ]; then
    return
  fi

  if ! command -v code >/dev/null 2>&1; then
    log "VSCode (code) not found; skipping extension install"
    return
  fi

  grep -v '^[[:space:]]*$' "$ext_file" | grep -v '^[[:space:]]*#' | while read -r ext; do
    [ -n "$ext" ] && code --install-extension "$ext" || true
  done
}

install_vscode() {
  if command -v code >/dev/null 2>&1; then
    return
  fi
  ensure_vscode_repo
  sudo apt-get install -y code
}

restore_gnome_settings() {
  local dconf_file="$repo_dir/gnome/dconf-settings.ini"
  if [ -f "$dconf_file" ] && command -v dconf >/dev/null 2>&1; then
    dconf load / < "$dconf_file"
  fi
}

main() {
  log "Starting setup restore..."
  ensure_base_packages
  ensure_oh_my_zsh
  install_vscode
  install_apt_packages
  install_snaps
  install_nerd_fonts
  restore_dotfiles
  restore_zsh_assets
  restore_vscode_settings
  install_vscode_extensions
  restore_gnome_settings
  create_chatgpt_shortcut
  log "Done. Open a new terminal or run: exec zsh"
  log "Optional: chsh -s /bin/zsh"
}

main "$@"
