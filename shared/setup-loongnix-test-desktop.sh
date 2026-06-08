#!/bin/sh
# Configure the Loongnix mini guest for visible X11 application testing.
# Run as root inside the guest:
#   sh /mnt/hostshare/setup-loongnix-test-desktop.sh
#
# Optional environment variables:
#   TEST_USER=loongson   target desktop user
#   AUTOLOGIN=1          create LightDM autologin config; set 0 to keep login screen
#   SET_CHINESE=1        generate zh_CN.UTF-8 locale and set system language; set 0 to skip
#   RESTART_LIGHTDM=1    start/restart LightDM at the end; set 0 to skip
#   REBOOT_AFTER=0       set 1 to reboot automatically after configuration

set -e

TEST_USER="${TEST_USER:-loongson}"
AUTOLOGIN="${AUTOLOGIN:-1}"
SET_CHINESE="${SET_CHINESE:-1}"
RESTART_LIGHTDM="${RESTART_LIGHTDM:-1}"
REBOOT_AFTER="${REBOOT_AFTER:-0}"
SESSION_NAME="loongnix-test"

log() {
    printf '%s\n' "==> $*"
}

warn() {
    printf '%s\n' "WARN: $*" >&2
}

if [ "$(id -u)" != "0" ]; then
    printf '%s\n' "This script must run as root. Log in as root, or run: su -"
    exit 1
fi

if ! command -v apt-get >/dev/null 2>&1; then
    printf '%s\n' "apt-get was not found. This script is intended for the Debian-based Loongnix image."
    exit 1
fi

USER_HOME="$(getent passwd "$TEST_USER" | awk -F: '{print $6}')"
if [ -z "$USER_HOME" ] || [ ! -d "$USER_HOME" ]; then
    printf '%s\n' "User '$TEST_USER' was not found. Set TEST_USER=your_user if needed."
    exit 1
fi
USER_GROUP="$(id -gn "$TEST_USER")"

export DEBIAN_FRONTEND=noninteractive

log "Checking interrupted package state"
if dpkg --audit | grep . >/dev/null 2>&1; then
    dpkg --configure -a
    apt-get -f install -y
fi

log "Updating apt package index"
apt-get update

PACKAGES="
xorg
dbus-x11
openssh-server
ffmpeg
alsa-utils
pulseaudio
lightdm
xfwm4
xfce4-panel
xfce4-statusnotifier-plugin
xfce4-indicator-plugin
libayatana-appindicator3-1
libappindicator3-1
ayatana-indicator-application
xfce4-notifyd
libnotify-bin
lxterminal
xfe
x11-xserver-utils
iproute2
locales
fonts-noto-cjk
fonts-wqy-zenhei
fonts-wqy-microhei
"

log "Installing lightweight X11 desktop, compositor, tray, notification, audio, and test tools"
apt-get install -y $PACKAGES

if [ "$SET_CHINESE" = "1" ]; then
    log "Configuring Chinese locale and fonts"
    if [ -f /etc/locale.gen ]; then
        if grep -q '^[#[:space:]]*zh_CN.UTF-8[[:space:]]\+UTF-8' /etc/locale.gen; then
            sed -i 's/^[#[:space:]]*zh_CN.UTF-8[[:space:]]\+UTF-8/zh_CN.UTF-8 UTF-8/' /etc/locale.gen
        else
            printf '%s\n' 'zh_CN.UTF-8 UTF-8' >> /etc/locale.gen
        fi

        if grep -q '^[#[:space:]]*en_US.UTF-8[[:space:]]\+UTF-8' /etc/locale.gen; then
            sed -i 's/^[#[:space:]]*en_US.UTF-8[[:space:]]\+UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
        else
            printf '%s\n' 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
        fi

        if command -v locale-gen >/dev/null 2>&1; then
            locale-gen zh_CN.UTF-8 en_US.UTF-8
        elif [ -x /usr/sbin/locale-gen ]; then
            /usr/sbin/locale-gen zh_CN.UTF-8 en_US.UTF-8
        else
            warn "locale-gen was not found; /etc/locale.gen was updated only"
        fi
    fi

    if command -v update-locale >/dev/null 2>&1; then
        update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_MESSAGES=zh_CN.UTF-8
    elif [ -x /usr/sbin/update-locale ]; then
        /usr/sbin/update-locale LANG=zh_CN.UTF-8 LANGUAGE=zh_CN:zh LC_MESSAGES=zh_CN.UTF-8
    else
        cat >/etc/default/locale <<'EOF'
LANG=zh_CN.UTF-8
LANGUAGE=zh_CN:zh
LC_MESSAGES=zh_CN.UTF-8
EOF
    fi

    if [ -d /usr/share/zoneinfo/Asia ] && [ -f /usr/share/zoneinfo/Asia/Shanghai ]; then
        ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
        printf '%s\n' 'Asia/Shanghai' >/etc/timezone
    fi

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f >/dev/null 2>&1 || true
    fi
fi

log "Enabling SSH service"
systemctl enable ssh >/dev/null 2>&1 || true
systemctl restart ssh >/dev/null 2>&1 || systemctl start ssh >/dev/null 2>&1 || warn "Could not start ssh.service"

log "Creating Loongnix X11 test desktop session for $TEST_USER"
cat >/usr/local/bin/loongnix-test-session <<'EOF'
#!/bin/sh
# Lightweight visible X11 test session for LoongArch old-world application testing.

USER_ID="$(id -u)"
export LANG="${LANG:-zh_CN.UTF-8}"
export LANGUAGE="${LANGUAGE:-zh_CN:zh}"
export LC_MESSAGES="${LC_MESSAGES:-zh_CN.UTF-8}"
export XDG_CURRENT_DESKTOP=XFCE
export DESKTOP_SESSION=loongnix-test
export XDG_SESSION_DESKTOP=loongnix-test

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ] && [ -S "/run/user/$USER_ID/bus" ]; then
    export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus"
fi

LOG_FILE="$HOME/.loongnix-test-session.log"
exec >>"$LOG_FILE" 2>&1
printf '%s\n' "== $(date '+%F %T') starting Loongnix test session =="

set_panel_prop() {
    property="$1"
    type="$2"
    value="$3"
    xfconf-query -c xfce4-panel -p "$property" -n -t "$type" -s "$value" >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p "$property" -t "$type" -s "$value" >/dev/null 2>&1 || true
}

configure_panel() {
    command -v xfconf-query >/dev/null 2>&1 || return 0

    xfconf-query -c xfce4-panel -p /panels -r -R >/dev/null 2>&1 || true
    xfconf-query -c xfce4-panel -p /plugins -r -R >/dev/null 2>&1 || true
    xfconf-query -c xfce4-panel -p /configver -r >/dev/null 2>&1 || true

    xfconf-query -c xfce4-panel -p /panels -n -a -t int -s 1 >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p /panels -a -t int -s 1 >/dev/null 2>&1 || true
    set_panel_prop /configver int 2
    set_panel_prop /panels/panel-1/position string 'p=10;x=0;y=0'
    set_panel_prop /panels/panel-1/length uint 100
    set_panel_prop /panels/panel-1/position-locked bool true
    set_panel_prop /panels/panel-1/size uint 30

    xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -n -a \
        -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 -t int -s 6 >/dev/null 2>&1 || \
        xfconf-query -c xfce4-panel -p /panels/panel-1/plugin-ids -a \
        -t int -s 1 -t int -s 2 -t int -s 3 -t int -s 4 -t int -s 5 -t int -s 6 >/dev/null 2>&1 || true

    set_panel_prop /plugins/plugin-1 string applicationsmenu
    set_panel_prop /plugins/plugin-2 string tasklist
    set_panel_prop /plugins/plugin-3 string separator
    set_panel_prop /plugins/plugin-3/expand bool true
    set_panel_prop /plugins/plugin-3/style uint 0
    set_panel_prop /plugins/plugin-4 string statusnotifier
    set_panel_prop /plugins/plugin-5 string systray
    set_panel_prop /plugins/plugin-6 string clock
}

pkill -x xfce4-panel >/dev/null 2>&1 || true
pkill -x wrapper-1.0 >/dev/null 2>&1 || true
pkill -x wrapper-2.0 >/dev/null 2>&1 || true
pkill -x tint2 >/dev/null 2>&1 || true
pkill -x stalonetray >/dev/null 2>&1 || true
pkill -x xcompmgr >/dev/null 2>&1 || true

command -v xsetroot >/dev/null 2>&1 && xsetroot -solid '#d8e0e5' || true
command -v pulseaudio >/dev/null 2>&1 && pulseaudio --start >/dev/null 2>&1 || true

if [ -x /usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd ]; then
    /usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd >/dev/null 2>&1 &
fi

xfconf-query -c xfwm4 -p /general/use_compositing -n -t bool -s true >/dev/null 2>&1 || \
    xfconf-query -c xfwm4 -p /general/use_compositing -t bool -s true >/dev/null 2>&1 || true
xfwm4 --compositor=on >/dev/null 2>&1 &
WM_PID=$!

sleep 2
configure_panel
xfce4-panel --disable-wm-check >/dev/null 2>&1 &
sleep 1
lxterminal >/dev/null 2>&1 &
xfe >/dev/null 2>&1 &

wait "$WM_PID"
EOF
chmod 0755 /usr/local/bin/loongnix-test-session

cat >/usr/share/xsessions/loongnix-test.desktop <<'EOF'
[Desktop Entry]
Name=Loongnix X11 Test Desktop
Comment=Lightweight X11 session with compositor, panel, tray, notifications, terminal, and file manager
Exec=/usr/local/bin/loongnix-test-session
Type=Application
DesktopNames=XFCE
EOF

cat >"$USER_HOME/.dmrc" <<EOF
[Desktop]
Session=$SESSION_NAME
EOF
chown "$TEST_USER:$USER_GROUP" "$USER_HOME/.dmrc"
chmod 0644 "$USER_HOME/.dmrc"

log "Configuring notification service for the lightweight session"
if [ -f /usr/share/dbus-1/services/org.kde.plasma.Notifications.service ]; then
    mv /usr/share/dbus-1/services/org.kde.plasma.Notifications.service \
        /usr/share/dbus-1/services/org.kde.plasma.Notifications.service.disabled
fi

cat >/usr/share/dbus-1/services/org.freedesktop.Notifications.service <<'EOF'
[D-BUS Service]
Name=org.freedesktop.Notifications
Exec=/usr/lib/loongarch64-linux-gnu/xfce4/notifyd/xfce4-notifyd
EOF

log "Configuring LightDM as the display manager"
mkdir -p /etc/xdg/lightdm/lightdm.conf.d

for conf in /etc/xdg/lightdm/lightdm.conf.d/*openbox*.conf; do
    if [ -f "$conf" ]; then
        mv "$conf" "$conf.disabled"
    fi
done

cat >/etc/xdg/lightdm/lightdm.conf.d/50-loongnix-test.conf <<EOF
[Seat:*]
user-session=$SESSION_NAME
EOF

if [ "$AUTOLOGIN" = "1" ]; then
    cat >/etc/xdg/lightdm/lightdm.conf.d/90-loongnix-test-session.conf <<EOF
[Seat:*]
autologin-user=$TEST_USER
autologin-user-timeout=0
user-session=$SESSION_NAME
autologin-session=$SESSION_NAME
EOF
else
    rm -f /etc/xdg/lightdm/lightdm.conf.d/90-loongnix-test-session.conf
fi

printf '%s\n' '/usr/sbin/lightdm' >/etc/X11/default-display-manager
systemctl disable sddm >/dev/null 2>&1 || true

LIGHTDM_UNIT=""
for candidate in /lib/systemd/system/lightdm.service /usr/lib/systemd/system/lightdm.service; do
    if [ -f "$candidate" ]; then
        LIGHTDM_UNIT="$candidate"
        break
    fi
done

if [ -n "$LIGHTDM_UNIT" ]; then
    ln -sf "$LIGHTDM_UNIT" /etc/systemd/system/display-manager.service
else
    warn "lightdm.service unit was not found; display-manager.service symlink was not created"
fi

systemctl daemon-reload
systemctl set-default graphical.target >/dev/null 2>&1 || true
systemctl enable lightdm >/dev/null 2>&1 || true

if [ "$RESTART_LIGHTDM" = "1" ]; then
    log "Starting or restarting LightDM"
    systemctl restart lightdm >/dev/null 2>&1 || systemctl start lightdm
fi

log "Configuration summary"
printf '%s\n' "User: $TEST_USER"
printf '%s\n' "Autologin: $AUTOLOGIN"
printf '%s\n' "Chinese locale: $SET_CHINESE"
printf '%s\n' "Desktop session: $SESSION_NAME"
printf '%s\n' "Default target: $(systemctl get-default 2>/dev/null || printf unknown)"
printf '%s\n' "Display manager: $(readlink /etc/systemd/system/display-manager.service 2>/dev/null || printf missing)"
printf '%s\n' ""
printf '%s\n' "If the desktop is not visible yet, run: systemctl reboot"
printf '%s\n' "After reboot, the VM should enter Loongnix X11 Test Desktop with xfwm4, xfce4-panel, tray, LXTerminal, and Xfe."

if [ "$REBOOT_AFTER" = "1" ]; then
    log "Rebooting"
    systemctl reboot
fi
