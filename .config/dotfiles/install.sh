#!/usr/bin/env bash
# OtoYuki/dotfiles installer: Arch Linux + Hyprland.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/OtoYuki/dotfiles/main/.config/dotfiles/install.sh)
#
# Safe to re-run: it updates an existing checkout instead of cloning again, and every
# file it would overwrite is first moved to ~/.dotfiles-backup/<timestamp>/.
set -euo pipefail

REPO=${DOTFILES_REPO:-https://github.com/OtoYuki/dotfiles.git}
GIT_DIR=${DOTFILES_DIR:-$HOME/.cfg}
BRANCH=${DOTFILES_BRANCH:-main}
TAKT_REPO=${TAKT_REPO:-https://github.com/OtoYuki/takt.git}
TAKT_SRC=${TAKT_SRC:-$HOME/.local/src/takt}
DMI_PRODUCT=${DMI_PRODUCT:-$(cat /sys/class/dmi/id/product_name 2>/dev/null || true)}

PACKAGES=1 TAKT=1 ASSUME_YES=0 DRY_RUN=0 HOST=auto

usage() {
    cat <<EOF
usage: install.sh [options]

  --no-packages   only check out the dotfiles; install nothing with pacman/AUR
  --no-takt       skip building the takt bar (waybar is used instead)
  --host NAME     force a host profile (see ~/.config/dotfiles/hosts), or 'none'
  --dry-run       print what would happen, change nothing
  -y, --yes       do not ask for confirmation
  -h, --help      show this help

env: DOTFILES_REPO DOTFILES_DIR DOTFILES_BRANCH TAKT_REPO TAKT_SRC
EOF
}

while (($#)); do
    case $1 in
        --no-packages) PACKAGES=0 ;;
        --no-takt) TAKT=0 ;;
        --host) HOST=${2:?--host needs a value}; shift ;;
        --dry-run) DRY_RUN=1 ;;
        -y | --yes) ASSUME_YES=1 ;;
        -h | --help) usage; exit 0 ;;
        *) usage >&2; exit 2 ;;
    esac
    shift
done

if [[ -t 1 ]]; then
    c_dim=$'\e[2m' c_ok=$'\e[38;2;153;146;8m' c_warn=$'\e[38;2;216;166;100m' c_err=$'\e[38;2;190;93;60m' c_off=$'\e[0m'
else
    c_dim='' c_ok='' c_warn='' c_err='' c_off=''
fi
step() { printf '%s::%s %s\n' "$c_ok" "$c_off" "$*"; }
note() { printf '%s   %s%s\n' "$c_dim" "$*" "$c_off"; }
warn() { printf '%s!!%s %s\n' "$c_warn" "$c_off" "$*" >&2; }
die() { printf '%sxx%s %s\n' "$c_err" "$c_off" "$*" >&2; exit 1; }
run() {
    if ((DRY_RUN)); then note "would run: $*"; else "$@"; fi
}
cfg() { git --git-dir="$GIT_DIR" --work-tree="$HOME" "$@"; }
read_list() { [[ -f $1 ]] && sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; return 0; }

# ── preflight ────────────────────────────────────────────────────────────
((EUID != 0)) || die "run as your user, not root (sudo is used where needed)"
command -v git >/dev/null || die "git is required: sudo pacman -S git"
if ((PACKAGES)) && [[ ! -f /etc/arch-release ]]; then
    warn "not Arch Linux: skipping package installation"
    PACKAGES=0
fi

step "dotfiles  $REPO ($BRANCH) -> $GIT_DIR"
note "packages: $( ((PACKAGES)) && echo yes || echo no)   takt: $( ((TAKT)) && echo yes || echo no)   machine: ${DMI_PRODUCT:-unknown}"
if ((!ASSUME_YES && !DRY_RUN)) && [[ -r /dev/tty ]]; then
    read -r -p "   continue? [Y/n] " reply </dev/tty || reply=n
    [[ -z $reply || $reply == [Yy]* ]] || exit 0
fi

# ── packages ─────────────────────────────────────────────────────────────
install_packages() {
    local root=$1 host=$2 aur_helper=''
    mapfile -t repo_pkgs < <(read_list "$root/packages/pacman.txt"; [[ $host != none ]] && read_list "$root/hosts/$host/pacman.txt")
    mapfile -t aur_pkgs < <(read_list "$root/packages/aur.txt")

    step "pacman: ${#repo_pkgs[@]} packages"
    run sudo pacman -Syu --needed --noconfirm "${repo_pkgs[@]}"

    for h in paru yay; do command -v "$h" >/dev/null && { aur_helper=$h; break; }; done
    if [[ -z $aur_helper ]]; then
        step "bootstrapping yay-bin"
        local tmp
        tmp=$(mktemp -d)
        run git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
        if ((DRY_RUN)); then note "would run: makepkg -si in $tmp/yay-bin"; else (cd "$tmp/yay-bin" && makepkg -si --noconfirm); fi
        rm -rf "$tmp"
        aur_helper=yay
    fi
    step "$aur_helper: ${#aur_pkgs[@]} AUR packages"
    run "$aur_helper" -S --needed --noconfirm "${aur_pkgs[@]}"
}

# ── checkout ─────────────────────────────────────────────────────────────
if [[ -d $GIT_DIR ]]; then
    [[ $(git -C "$GIT_DIR" rev-parse --is-bare-repository 2>/dev/null) == true ]] ||
        die "$GIT_DIR exists but is not a bare git repo; move it aside or set DOTFILES_DIR"
    step "updating existing checkout"
    run cfg fetch origin "$BRANCH"
    run cfg merge --ff-only "origin/$BRANCH"
else
    step "cloning"
    run git clone --bare --branch "$BRANCH" "$REPO" "$GIT_DIR"
    if ((!DRY_RUN)); then
        cfg config status.showUntrackedFiles no
        cfg config remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'

        # Back up every file the checkout would overwrite, keeping its path.
        backup="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
        moved=0
        while IFS= read -r -d '' f; do
            [[ -e $HOME/$f || -L $HOME/$f ]] || continue
            if [[ -f $HOME/$f && ! -L $HOME/$f ]] &&
                [[ $(git hash-object "$HOME/$f") == "$(cfg rev-parse "HEAD:$f")" ]]; then
                continue
            fi
            mkdir -p "$backup/$(dirname "$f")"
            mv "$HOME/$f" "$backup/$f"
            moved=$((moved + 1))
        done < <(cfg ls-tree -r -z --name-only HEAD)
        ((moved == 0)) || note "backed up $moved existing files to $backup"

        cfg checkout -f "$BRANCH"
        cfg branch --set-upstream-to="origin/$BRANCH" "$BRANCH" >/dev/null 2>&1 || true
    fi
fi

ROOT="$HOME/.config/dotfiles"
((DRY_RUN)) && [[ ! -d $ROOT ]] && ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── host profile ─────────────────────────────────────────────────────────
if [[ $HOST == auto ]]; then
    HOST=none
    for m in "$ROOT"/hosts/*/match; do
        [[ -f $m ]] || continue
        if [[ -n $DMI_PRODUCT && $(head -n1 "$m") == "$DMI_PRODUCT" ]]; then
            HOST=$(basename "$(dirname "$m")")
        fi
    done
fi
[[ $HOST == none || -d $ROOT/hosts/$HOST ]] || die "unknown host profile: $HOST"
step "host profile: $HOST"

# Hardware-specific files of every OTHER profile leave the work tree.
for d in "$ROOT"/hosts/*/; do
    name=$(basename "$d")
    [[ $name == "$HOST" ]] && continue
    while IFS= read -r f; do
        if cfg ls-files --error-unmatch -- "$f" >/dev/null 2>&1; then
            run cfg update-index --skip-worktree -- "$f"
            run rm -f -- "$HOME/$f"
            note "skipped $f ($name only)"
        fi
    done < <(read_list "$d/paths")
done
if [[ $HOST != none ]]; then
    while IFS= read -r f; do
        run cfg update-index --no-skip-worktree -- "$f"
        [[ -e $HOME/$f ]] || run cfg checkout -- "$f"
    done < <(read_list "$ROOT/hosts/$HOST/paths")
fi

((PACKAGES)) && install_packages "$ROOT" "$HOST"

# ── takt ─────────────────────────────────────────────────────────────────
if ((TAKT)); then
    if ! command -v cargo >/dev/null && command -v rustup >/dev/null; then
        run rustup default stable
    fi
    if command -v cargo >/dev/null || ((DRY_RUN)); then
        step "building takt"
        if [[ -d $TAKT_SRC/.git ]]; then
            run git -C "$TAKT_SRC" pull --ff-only
        else
            run git clone --depth 1 "$TAKT_REPO" "$TAKT_SRC"
        fi
        if ((DRY_RUN)); then
            note "would run: cargo build --release --locked in $TAKT_SRC"
        elif (cd "$TAKT_SRC" && cargo build --release --locked); then
            install -Dm755 "$TAKT_SRC/target/release/takt" "$HOME/.local/bin/takt"
            mkdir -p "$HOME/.local/share/takt"
            cp -r "$TAKT_SRC/assets" "$HOME/.local/share/takt/"
        else
            warn "takt failed to build; Hyprland falls back to waybar"
        fi
    else
        warn "no cargo: skipping takt, Hyprland falls back to waybar"
    fi
fi

# ── finish ───────────────────────────────────────────────────────────────
step "finishing"
run cfg config core.hooksPath "$ROOT/hooks"
command -v fc-cache >/dev/null && run fc-cache -f >/dev/null
if command -v systemctl >/dev/null && systemctl --user show-environment >/dev/null 2>&1; then
    run systemctl --user daemon-reload
    run systemctl --user enable hypridle.service || warn "could not enable hypridle.service"
fi
if [[ ${SHELL##*/} != zsh ]] && command -v zsh >/dev/null; then
    note "default shell is ${SHELL##*/}; switch with: chsh -s $(command -v zsh)"
fi

step "done"
note "log in with: uwsm start hyprland.desktop    (or pick Hyprland (uwsm) in your display manager)"
note "manage with: alias config='git --git-dir=$GIT_DIR --work-tree=\$HOME'"
note "machine-local overrides: ~/.zshrc.local  ~/.config/hypr/local.lua"
