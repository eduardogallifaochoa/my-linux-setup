# my-linux-setup

Portable Ubuntu setup for quickly restoring my environment.

## What this includes
- Zsh + Oh My Zsh + plugins
- Dotfiles (.zshrc, .p10k.zsh, .gitconfig)
- Apt packages (manual list)
- Snap packages (if exported)
- VSCode settings + extensions list
- GNOME settings (dconf)
- Nerd Font (JetBrains Mono Nerd Font)
- ChatGPT web shortcut (opens in default browser)

## Install on a fresh Ubuntu
```bash
git clone <your-private-repo-url>
cd my-linux-setup
bash install.sh
```

## Manual steps (if needed)
- Set default shell: `chsh -s /bin/zsh`
- Open a new terminal or run: `exec zsh`
- If VSCode CLI missing, install VSCode then re-run extensions step.
- GNOME settings will be restored from `gnome/dconf-settings.ini` if present.

## Notes
- Secrets are intentionally excluded. Do not commit SSH keys or tokens.
- `packages/snap-list.txt` may be a placeholder if snapd was not responding.

## Re-export from current machine
- Update package lists:
  - `apt-mark showmanual > packages/apt-manual.txt`
  - `snap list > packages/snap-list.txt`
- Update VSCode:
  - `code --list-extensions > vscode/extensions.txt`
- Copy dotfiles and zsh assets again if they changed.
- GNOME settings:
  - `dconf dump / > gnome/dconf-settings.ini`
