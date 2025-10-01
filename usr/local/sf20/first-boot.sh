#!/usr/bin/env bash
# /usr/local/sf20/first-boot.sh
# Run once at first boot to integrate SourceForge Terminal + Chip Shell and show the startup menu on first login.

set -euo pipefail
LOG_DIR="/var/log"
LOG_FILE="${LOG_DIR}/sf20-firstboot.log"
STATE_DIR="/var/lib/sf20"
DONE_FLAG="${STATE_DIR}/.firstboot_done"

mkdir -p "${LOG_DIR}" "${STATE_DIR}"
exec > >(tee -a "${LOG_FILE}") 2>&1

echo "[sf20-firstboot] $(date -Is) starting..."

# Try to locate repo containing terminal/ and shell/
CANDIDATES=(
  "/boot/sourceforge20"            # if user staged repo on boot partition
  "/boot/sf20-repo"
  "/opt/sourceforge20"             # pre-cloned
  "/root/sourceforge20"
  "/home/pi/sourceforge20"
  "/home/dietpi/sourceforge20"
)

REPO=""
for d in "${CANDIDATES[@]}"; do
  if [[ -d "$d/terminal" && -d "$d/shell" ]]; then
    REPO="$d"; break
  fi
done

if [[ -z "${REPO}" ]]; then
  echo "[sf20-firstboot] WARNING: repo not found in common locations. Skipping app/shell install."
  echo "[sf20-firstboot] You can rerun later: sudo /usr/local/sf20/first-boot.sh"
else
  echo "[sf20-firstboot] Using repo: ${REPO}"
  # Ensure installer exists; if not, write a minimal one-time copy
  if [[ ! -f "${REPO}/scripts/install-term-shell.sh" ]]; then
    echo "[sf20-firstboot] No installer found; creating minimal installer at ${REPO}/scripts/install-term-shell.sh"
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
  bash "${REPO}/scripts/install-term-shell.sh" "${REPO}" || {
    echo "[sf20-firstboot] ERROR: installer failed"; 
  }
fi

# Ensure branding exists (safe no-op if already present)
grep -q "SourceForge 2.0" /etc/motd 2>/dev/null || echo "SourceForge 2.0 — DietPi Appliance" >> /etc/motd
grep -q "SourceForge 2.0" /etc/issue 2>/dev/null || echo "Welcome to SourceForge 2.0 (sf20)" >> /etc/issue

# Mark done and disable service
touch "${DONE_FLAG}"
systemctl disable sf20-firstboot.service || true

echo "[sf20-firstboot] $(date -Is) completed."
