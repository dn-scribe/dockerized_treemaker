#!/bin/bash
set -e

# Virtual framebuffer — TreeMaker needs a display
Xvfb :1 -screen 0 1280x800x24 -ac -nolisten tcp &
XVFB_PID=$!

# Wait for Xvfb socket — reliable; no xdpyinfo needed
until [ -S /tmp/.X11-unix/X1 ]; do sleep 0.1; done

# VNC server — listen on localhost only; websockify is the only client
x11vnc -display :1 -nopw -localhost -xkb -forever -shared -quiet &

# Wait for x11vnc to open its VNC port
until ss -tln 2>/dev/null | grep -q ':5900'; do sleep 0.1; done

# noVNC websocket bridge: browser :6080 → websockify → x11vnc :5900
python3 -m websockify --web=/opt/novnc 6080 localhost:5900 &

echo "TreeMaker running — open http://localhost:6080 in your browser"

export DISPLAY=:1
export TREEMAKER_PREFIX=/usr/local
# No dconf daemon in container — use in-memory backend to prevent GTK3 crash.
# Adwaita is bundled in libgtk3; set explicitly to skip the dconf theme lookup.
export GSETTINGS_BACKEND=memory
export GTK_THEME=Adwaita
# Prevent GTK from hanging trying to connect to AT-SPI and dbus session bus.
export NO_AT_BRIDGE=1
export DBUS_SESSION_BUS_ADDRESS=/dev/null

exec /usr/local/bin/TreeMaker "$@"
