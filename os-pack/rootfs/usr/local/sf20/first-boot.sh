#!/usr/bin/env bash
# /usr/local/sf20/first-boot.sh
# First-boot: autoclone repo, install terminal+shell, set boot logo (plymouth),
# generate ASCII MOTD, and ensure terminal is the main UX using chipsh.

set -euo pipefail
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/sf20-firstboot.log"
STATE_DIR="/var/lib/sf20"
DONE_FLAG="${STATE_DIR}/.firstboot_done"

mkdir -p "${LOG_DIR}" "${STATE_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1
echo "[sf20-firstboot] $(date -Is) starting..."

export DEBIAN_FRONTEND=noninteractive
apt-get update -y || true
apt-get install -y git ca-certificates || true

# -------- Repo autoclone --------
REPO_URL_FILE="/boot/sf20.repourl"
TARGET_DIR="/opt/sourceforge20"

if [[ -f "${REPO_URL_FILE}" ]]; then
  REPO_URL="$(tr -d '\r' < "${REPO_URL_FILE}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
  if [[ -n "${REPO_URL}" ]]; then
    echo "[sf20-firstboot] Autoclone URL: ${REPO_URL}"
    mkdir -p "$(dirname "${TARGET_DIR}")"
    if [[ -d "${TARGET_DIR}/.git" ]]; then
      git -C "${TARGET_DIR}" pull --ff-only || true
    else
      git clone --depth 1 "${REPO_URL}" "${TARGET_DIR}" || true
    fi
  fi
fi

CANDIDATES=(
  "${TARGET_DIR}"
  "/boot/sourceforge20"
  "/boot/sf20-repo"
  "/root/sourceforge20"
  "/home/pi/sourceforge20"
  "/home/dietpi/sourceforge20"
  "/opt/sourceforge20"
)
REPO=""
for d in "${CANDIDATES[@]}"; do
  if [[ -d "$d/terminal" && -d "$d/shell" ]]; then
    REPO="$d"; break
  fi
done

if [[ -z "${REPO}" ]]; then
  echo "[sf20-firstboot] WARNING: repo not found in candidates"
else
  echo "[sf20-firstboot] Using repo: ${REPO}"
  # Install Terminal + Shell
  apt-get install -y python3 python3-venv python3-pip gcc make || true

  # Terminal
  install -d /opt/sf20-terminal
  install -m 0644 "${REPO}/terminal/sourceforge_term.py" /opt/sf20-terminal/sourceforge_term.py
  python3 -m venv /opt/sf20-terminal/venv
  /opt/sf20-terminal/venv/bin/pip install --upgrade pip

  # Shell
  install -d /opt/sf20-chipsh
  install -m 0644 "${REPO}/shell/chipsh.c" /opt/sf20-chipsh/chipsh.c
  if [[ -f "${REPO}/shell/Makefile" ]]; then
    cp -a "${REPO}/shell/Makefile" /opt/sf20-chipsh/Makefile
    make -C /opt/sf20-chipsh
    install -m 0755 /opt/sf20-chipsh/chipsh /usr/local/bin/chipsh
  else
    gcc -O2 -Wall -Wextra -o /usr/local/bin/chipsh /opt/sf20-chipsh/chipsh.c
  fi

  # Ensure launcher and profile hook exist (from this pack)
  if [[ ! -x "/usr/local/bin/sourceforge-term" ]]; then
    echo "[sf20-firstboot] WARNING: /usr/local/bin/sourceforge-term missing; please copy pack files to /usr first"
  fi
  if [[ ! -f "/etc/profile.d/10-sf20-main.sh" ]]; then
    echo "[sf20-firstboot] WARNING: /etc/profile.d/10-sf20-main.sh missing; please copy pack files to /etc first"
  fi
fi

# -------- Boot splash (Plymouth) --------
PLY_THEME_DIR="/usr/share/plymouth/themes/sourceforge"
LOGO_SRC=""
if [[ -n "${REPO:-}" && -f "${REPO}/logo/logo.png" ]]; then
  LOGO_SRC="${REPO}/logo/logo.png"
elif [[ -f "/boot/logo/logo.png" ]]; then
  LOGO_SRC="/boot/logo/logo.png"
fi

if [[ -n "${LOGO_SRC}" ]]; then
  apt-get install -y plymouth plymouth-themes || true
  mkdir -p "${PLY_THEME_DIR}"
  cp "${LOGO_SRC}" "${PLY_THEME_DIR}/logo.png"
  cat > "${PLY_THEME_DIR}/sourceforge.plymouth" <<'EOF'
[Plymouth Theme]
Name=SourceForge 2.0
Description=SourceForge boot splash
ModuleName=script

[script]
ImageDir=/usr/share/plymouth/themes/sourceforge
ScriptFile=/usr/share/plymouth/themes/sourceforge/sourceforge.script
EOF
  cat > "${PLY_THEME_DIR}/sourceforge.script" <<'EOF'
logo = Image("logo.png");
screen_w = Window.GetWidth();
screen_h = Window.GetHeight();
logo.Scale(screen_w, screen_h, SCALE_KEEP_ASPECT);
x = (screen_w - logo.GetWidth())/2;
y = (screen_h - logo.GetHeight())/2;
logo.SetPosition(x, y);
logo.Draw();
EOF
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme -R sourceforge || plymouth-set-default-theme sourceforge || true
  fi
  update-initramfs -u || true
fi

# -------- ASCII MOTD from logo --------
if [[ -n "${LOGO_SRC}" ]]; then
  echo "[sf20-firstboot] Generating ASCII MOTD from logo"
  apt-get install -y libcaca-utils || true
  OUT="/etc/motd"
  if img2txt --width=80 --ansi "${LOGO_SRC}" > "${OUT}.ansi" 2>/dev/null; then
    {
      echo
      cat "${OUT}.ansi"
      echo
      echo "SourceForge 2.0 — DietPi Appliance"
    } > "${OUT}"
    rm -f "${OUT}.ansi"
  else
    echo "SourceForge 2.0 — DietPi Appliance" > "${OUT}"
  fi
  echo "Welcome to SourceForge 2.0 (sf20)" > /etc/issue
else
  grep -q "SourceForge 2.0" /etc/motd 2>/dev/null || echo "SourceForge 2.0 — DietPi Appliance" >> /etc/motd
  grep -q "SourceForge 2.0" /etc/issue 2>/dev/null || echo "Welcome to SourceForge 2.0 (sf20)" >> /etc/issue
fi

# Safety: remove any old login menu that might conflict
rm -f /etc/profile.d/99-sf20-login-menu.sh 2>/dev/null || true

# Mark done & disable service
touch "${DONE_FLAG}"
systemctl disable sf20-firstboot.service || true
echo "[sf20-firstboot] $(date -Is) completed."
