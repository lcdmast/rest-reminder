#!/bin/bash
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
BIN="$DIR/RestReminder"
SRC="$DIR/RestReminder.swift"
INSTALLED="$HOME/Applications/RestReminder"
LABEL="com.local.rest-reminder"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

build() {
  if [[ ! -x "$BIN" || "$SRC" -nt "$BIN" ]]; then
    echo "正在编译休息提醒..."
    swiftc "$SRC" -O -o "$BIN" -framework AppKit
  fi
}

stop_running() {
  pkill -f "$BIN" >/dev/null 2>&1 || true
  pkill -f "$INSTALLED" >/dev/null 2>&1 || true
}

install_login() {
  build
  mkdir -p "$HOME/Applications"
  cp "$BIN" "$INSTALLED"
  chmod +x "$INSTALLED"
  mkdir -p "$HOME/Library/LaunchAgents"
  cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${INSTALLED}</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <dict>
    <key>SuccessfulExit</key>
    <false/>
  </dict>
  <key>LimitLoadToSessionType</key>
  <string>Aqua</string>
  <key>ProcessType</key>
  <string>Interactive</string>
</dict>
</plist>
EOF
  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
  launchctl bootstrap "gui/$(id -u)" "$PLIST"
  echo "已安装开机自启。"
  echo "登录后菜单栏会出现咖啡杯图标；点「退出」不会被自动拉起，下次开机仍会启动。"
}

uninstall_login() {
  launchctl bootout "gui/$(id -u)/${LABEL}" >/dev/null 2>&1 || true
  rm -f "$PLIST" "$INSTALLED"
  echo "已取消开机自启。"
}

case "${1:-}" in
  --install)
    stop_running
    install_login
    ;;
  --uninstall)
    uninstall_login
    stop_running
    ;;
  --now)
    build
    exec "$BIN" --now "${@:2}"
    ;;
  --help|-h)
    cat <<'EOF'
休息提醒

  ./start.sh              编译并前台运行
  ./start.sh --now        立刻弹一次，方便看效果
  ./start.sh --install    安装为开机自启
  ./start.sh --uninstall  取消开机自启
  ./start.sh --interval 25 --snooze 5

间隔也可以在菜单栏咖啡杯图标里改，会记住你的选择。
EOF
    ;;
  *)
    build
    exec "$BIN" "$@"
    ;;
esac
