#!/usr/bin/env bash
# /usr/local/sf20/first-boot.sh
# First-boot for SourceForge 2.0: repo autoclone + terminal/shell install + boot logo + login menu

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

# -------- Repo discovery / autoclone --------
# 1) If /boot/sf20.repourl exists, clone or pull into /opt/sourceforge20
REPO_URL_FILE="/boot/sf20.repourl"
TARGET_DIR="/opt/sourceforge20"

if [[ -f "${REPO_URL_FILE}" ]]; then
  REPO_URL="$(tr -d '\r' < "${REPO_URL_FILE}" | sed -e 's/^[ \t]*//' -e 's/[ \t]*$//')"
  if [[ -n "${REPO_URL}" ]]; then
    echo "[sf20-firstboot] Autoclone URL found: ${REPO_URL}"
    mkdir -p "$(dirname "${TARGET_DIR}")"
    if [[ -d "${TARGET_DIR}/.git" ]]; then
      echo "[sf20-firstboot] Repo exists; pulling latest..."
      git -C "${TARGET_DIR}" pull --ff-only || true
    else
      echo "[sf20-firstboot] Cloning to ${TARGET_DIR} ..."
      git clone --depth 1 "${REPO_URL}" "${TARGET_DIR}" || true
    fi
  fi
fi

# 2) Find a repo with terminal/ and shell/
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
  echo "[sf20-firstboot] WARNING: repo not found. Place your repo at one of:"
  printf '  - %s\n' "${CANDIDATES[@]}"
else
  echo "[sf20-firstboot] Using repo: ${REPO}"
  # Ensure installer exists; if not, create minimal one
  if [[ ! -f "${REPO}/scripts/install-term-shell.sh" ]]; then
    echo "[sf20-firstboot] Creating minimal installer at ${REPO}/scripts/install-term-shell.sh"
    mkdir -p "${REPO}/scripts"
    cat > "${REPO}/scripts/install-term-shell.sh" <<'EOS'
#!/usr/bin/env bash
set -euo pipefail
REPO_ROOT="${1:-.}"
TERM_DIR="${REPO_ROOT}/terminal"
SHELL_DIR="${REPO_ROOT}/shell"
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3 python3-venv python3-pip gcc make

install -d /opt/sf20-terminal
install -m 0644 "${TERM_DIR}/sourceforge_term.py" /opt/sf20-terminal/sourceforge_term.py
python3 -m venv /opt/sf20-terminal/venv
/opt/sf20-terminal/venv/bin/pip install --upgrade pip

tee /usr/local/bin/sourceforge-term >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exec /opt/sf20-terminal/venv/bin/python /opt/sf20-terminal/sourceforge_term.py "$@"
EOF
chmod +x /usr/local/bin/sourceforge-term

install -d /opt/sf20-chipsh
install -m 0644 "${SHELL_DIR}/chipsh.c" /opt/sf20-chipsh/chipsh.c
if [[ -f "${SHELL_DIR}/Makefile" ]]; then
  cp -a "${SHELL_DIR}/Makefile" /opt/sf20-chipsh/Makefile
  make -C /opt/sf20-chipsh
  install -m 0755 /opt/sf20-chipsh/chipsh /usr/local/bin/chipsh
else
  gcc -O2 -Wall -Wextra -o /usr/local/bin/chipsh /opt/sf20-chipsh/chipsh.c
fi

tee /etc/profile.d/99-sf20-login-menu.sh >/dev/null <<'EOF'
case "$-" in *i*) : ;; *) return ;; esac
[ -t 0 ] || return
while true; do
  clear
  echo "==================== SourceForge 2.0 ===================="
  echo " 1) SourceForge (Gitea/Runner/DDNS/HTTPS menu)"
  echo " 2) SourceForge Terminal (UI program)"
  echo " 3) Chip Shell (custom shell)"
  echo " 4) DietPi Launcher"
  echo " 5) Shell"
  echo " q) Quit"
  echo "========================================================="
  read -rp "> " ans
  case "$ans" in
    1) /usr/local/sf20/sourceforge.sh ;;
    2) sourceforge-term ;;
    3) chipsh ;;
    4) command -v dietpi-launcher >/dev/null && dietpi-launcher || echo "dietpi-launcher not found" ;;
    5) break ;;
    q|Q) exit 0 ;;
    *) echo "Unknown choice"; sleep 1 ;;
  esac
done
EOF
chmod 0644 /etc/profile.d/99-sf20-login-menu.sh
EOS
    chmod +x "${REPO}/scripts/install-term-shell.sh"
  fi

  echo "[sf20-firstboot] Running installer..."
  bash "${REPO}/scripts/install-term-shell.sh" "${REPO}" || echo "[sf20-firstboot] installer reported errors"
fi

# -------- Boot splash (Plymouth) using repo logo/logo.png if available --------
# Only if a logo exists
PLY_THEME_DIR="/usr/share/plymouth/themes/sourceforge"
LOGO_SRC=""
if [[ -n "${REPO:-}" && -f "${REPO}/logo/logo.png" ]]; then
  LOGO_SRC="${REPO}/logo/logo.png"
elif [[ -f "/boot/logo/logo.png" ]]; then
  LOGO_SRC="/boot/logo/logo.png"
fi

if [[ -n "${LOGO_SRC}" ]]; then
  echo "[sf20-firstboot] Installing boot splash using ${LOGO_SRC}"
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
# Plymouth script to center logo.png preserving aspect
logo = Image("logo.png");
# scale to fit screen (keep aspect)
screen_w = Window.GetWidth();
screen_h = Window.GetHeight();

# Compute scale
scale_w = screen_w;
scale_h = screen_h;
logo.Scale(scale_w, scale_h, SCALE_KEEP_ASPECT);

x = (screen_w - logo.GetWidth())/2;
y = (screen_h - logo.GetHeight())/2;

logo.SetPosition(x, y);
logo.Draw();
EOF

  # Set as default theme and rebuild initramfs if available
  if command -v plymouth-set-default-theme >/dev/null 2>&1; then
    plymouth-set-default-theme -R sourceforge || plymouth-set-default-theme sourceforge || true
  fi
  # Many Pi builds skip initramfs; try update-initramfs but ignore errors
  update-initramfs -u || true
else
  echo "[sf20-firstboot] No logo found; skipping boot splash setup"
fi

# -------- Branding --------
grep -q "SourceForge 2.0" /etc/motd 2>/dev/null || echo "SourceForge 2.0 — DietPi Appliance" >> /etc/motd
grep -q "SourceForge 2.0" /etc/issue 2>/dev/null || echo "Welcome to SourceForge 2.0 (sf20)" >> /etc/issue

# Mark done & disable service
touch "${DONE_FLAG}"
systemctl disable sf20-firstboot.service || true

echo "[sf20-firstboot] $(date -Is) completed."
