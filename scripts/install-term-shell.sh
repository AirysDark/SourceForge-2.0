#!/usr/bin/env bash
# install-term-shell.sh
# Integrates SourceForge Terminal app and Chip Shell into a DietPi/Debian system (terminal-only).
# Expects repo layout:
#   terminal/sourceforge_term.py
#   terminal/run.sh             (optional; we create a launcher anyway)
#   shell/chipsh.c
#   shell/Makefile              (optional; we'll prefer it if present)
# Usage:
#   sudo ./scripts/install-term-shell.sh
set -euo pipefail

REPO_ROOT="${1:-.}"
TERM_DIR="${REPO_ROOT}/terminal"
SHELL_DIR="${REPO_ROOT}/shell"

echo "[*] Installing requirements..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y python3 python3-venv python3-pip gcc make git pkg-config

echo "[*] Installing SourceForge Terminal..."
install -d /opt/sf20-terminal
if [[ -f "${TERM_DIR}/sourceforge_term.py" ]]; then
  install -m 0644 "${TERM_DIR}/sourceforge_term.py" /opt/sf20-terminal/sourceforge_term.py
else
  echo "ERROR: ${TERM_DIR}/sourceforge_term.py not found" >&2
  exit 1
fi

# Python venv (optional deps placeholder if you add requirements.txt later)
python3 -m venv /opt/sf20-terminal/venv
/opt/sf20-terminal/venv/bin/pip install --upgrade pip

# Launcher script
tee /usr/local/bin/sourceforge-term >/dev/null <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
APP_DIR="/opt/sf20-terminal"
if [[ ! -x "${APP_DIR}/venv/bin/python" ]]; then
  echo "Missing venv at ${APP_DIR}/venv" >&2
  exit 1
fi
exec "${APP_DIR}/venv/bin/python" "${APP_DIR}/sourceforge_term.py" "$@"
EOF
chmod +x /usr/local/bin/sourceforge-term

echo "[✓] Installed SourceForge Terminal → run: sourceforge-term"

echo "[*] Building Chip Shell..."
install -d /opt/sf20-chipsh
if [[ -f "${SHELL_DIR}/chipsh.c" ]]; then
  install -m 0644 "${SHELL_DIR}/chipsh.c" /opt/sf20-chipsh/chipsh.c
else
  echo "ERROR: ${SHELL_DIR}/chipsh.c not found" >&2
  exit 1
fi

if [[ -f "${SHELL_DIR}/Makefile" ]]; then
  echo "[i] Using provided Makefile"
  cp -a "${SHELL_DIR}/Makefile" /opt/sf20-chipsh/Makefile
  make -C /opt/sf20-chipsh
  install -m 0755 /opt/sf20-chipsh/chipsh /usr/local/bin/chipsh
else
  echo "[i] No Makefile, compiling with gcc defaults"
  gcc -O2 -Wall -Wextra -o /usr/local/bin/chipsh /opt/sf20-chipsh/chipsh.c
fi

echo "[✓] Installed Chip Shell → run: chipsh"

# Optional: integrate into login menu
echo "[*] Installing SourceForge 2.0 login menu (console-only)..."
tee /etc/profile.d/99-sf20-login-menu.sh >/dev/null <<'EOF'
# /etc/profile.d/99-sf20-login-menu.sh
# Show a simple console menu on interactive TTY logins.
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
    1) command -v /usr/local/sf20/sourceforge.sh >/dev/null && /usr/local/sf20/sourceforge.sh || echo "sourceforge.sh not installed";;
    2) command -v sourceforge-term >/dev/null && sourceforge-term || echo "sourceforge-term not found";;
    3) command -v chipsh >/dev/null && chipsh || echo "chipsh not found";;
    4) command -v dietpi-launcher >/dev/null && dietpi-launcher || echo "dietpi-launcher not found";;
    5) break ;;  # drop to shell
    q|Q) exit 0 ;;
    *) echo "Unknown choice"; sleep 1 ;;
  esac
done
EOF
chmod 0644 /etc/profile.d/99-sf20-login-menu.sh

# Branding (optional; skip if already set)
if [[ ! -f /etc/motd || "$(grep -c 'SourceForge 2.0' /etc/motd || true)" -eq 0 ]]; then
  echo "SourceForge 2.0 — DietPi Appliance" > /etc/motd
fi
if [[ ! -f /etc/issue || "$(grep -c 'SourceForge 2.0' /etc/issue || true)" -eq 0 ]]; then
  echo "Welcome to SourceForge 2.0 (sf20)" > /etc/issue
fi

echo
echo "[✓] Integration complete."
echo "    - Launch terminal app: sourceforge-term"
echo "    - Launch custom shell: chipsh"
echo "    - Login menu will show options on next interactive login."
