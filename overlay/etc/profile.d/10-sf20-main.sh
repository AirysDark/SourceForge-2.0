# /etc/profile.d/10-sf20-main.sh
export SF20_NAME="SourceForge 2.0 OS"
if [ -t 1 ]; then
  echo ""
  echo "Welcome to $SF20_NAME"
  echo "Type 'help' for sfsh commands."
  echo ""
fi
