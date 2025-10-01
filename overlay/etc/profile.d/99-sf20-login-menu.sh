# /etc/profile.d/99-sf20-login-menu.sh
case "$-" in *i*) : ;; *) return ;; esac
[ -t 0 ] || return

while true; do
  clear
  echo "==================== SourceForge 2.0 ===================="
  echo " 1) SourceForge (Gitea/Runner/DDNS/HTTPS menu)"
  echo " 2) DietPi Launcher (original DietPi tools)"
  echo " 3) Shell"
  echo " q) Quit"
  echo "========================================================="
  read -rp "> " ans
  case "$ans" in
    1) /usr/local/sf20/sourceforge.sh ;;
    2) command -v dietpi-launcher >/dev/null && dietpi-launcher || echo "dietpi-launcher not found";;
    3) break ;;
    q|Q) exit 0 ;;
    *) echo "Unknown choice"; sleep 1 ;;
  esac
done
