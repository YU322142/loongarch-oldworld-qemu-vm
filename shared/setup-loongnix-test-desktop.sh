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
openbox
obconf
lxterminal
tint2
xfe
xfce4-notifyd
libnotify-bin
iproute2
locales
fonts-noto-cjk
fonts-wqy-zenhei
fonts-wqy-microhei
"

log "Installing lightweight X11 desktop and test tools"
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

log "Configuring Openbox session for $TEST_USER"
mkdir -p "$USER_HOME/.config/openbox" "$USER_HOME/.config/autostart"
cat >"$USER_HOME/.config/openbox/autostart" <<'EOF'
pulseaudio --start &
tint2 &
lxterminal &
xfe &
EOF

cat >"$USER_HOME/.dmrc" <<'EOF'
[Desktop]
Session=openbox
EOF

chown -R "$TEST_USER:$USER_GROUP" "$USER_HOME/.config" "$USER_HOME/.dmrc"
chmod 0644 "$USER_HOME/.config/openbox/autostart" "$USER_HOME/.dmrc"

log "Configuring LightDM as the display manager"
mkdir -p /etc/xdg/lightdm/lightdm.conf.d
cat >/etc/xdg/lightdm/lightdm.conf.d/50-openbox-test.conf <<'EOF'
[Seat:*]
user-session=openbox
EOF

if [ "$AUTOLOGIN" = "1" ]; then
    cat >/etc/xdg/lightdm/lightdm.conf.d/60-autologin-openbox.conf <<EOF
[Seat:*]
autologin-user=$TEST_USER
autologin-user-timeout=0
user-session=openbox
autologin-session=openbox
EOF
else
    rm -f /etc/xdg/lightdm/lightdm.conf.d/60-autologin-openbox.conf
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
printf '%s\n' "Default target: $(systemctl get-default 2>/dev/null || printf unknown)"
printf '%s\n' "Display manager: $(readlink /etc/systemd/system/display-manager.service 2>/dev/null || printf missing)"
printf '%s\n' ""
printf '%s\n' "If the desktop is not visible yet, run: systemctl reboot"
printf '%s\n' "After reboot, the VM should enter Openbox with tint2, LXTerminal, and Xfe."

if [ "$REBOOT_AFTER" = "1" ]; then
    log "Rebooting"
    systemctl reboot
fi
