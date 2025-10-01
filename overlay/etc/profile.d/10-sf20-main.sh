# /etc/profile.d/10-sf20-main.sh
# Auto-launch SourceForge Terminal on interactive TTY/SSH logins.
# Bypass with: SF20_SKIP=1

case "$-" in *i*) : ;; *) return ;; esac
[ -t 0 ] || return
[ "${SF20_SKIP:-0}" = "1" ] && return

# Prevent recursion
if [ -z "${SF20_RUNNING:-}" ]; then
  export SF20_RUNNING=1
  if command -v sourceforge-term >/dev/null 2>&1; then
    sourceforge-term || true
  fi
fi
