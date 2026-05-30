#!/bin/bash
set -e

while :; do
    read -p "Enter username: " user
    [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] && break || echo "Invalid username."
done

while :; do
    read -s -p "Enter password for '$user': " pw; echo
    read -s -p "Confirm password: " cpw; echo
    [[ -n "$pw" && "$pw" == "$cpw" ]] && break || echo "Mismatch. Retry."
done

read -s -p "Enter root password (Press Enter to reuse user password): " r_pw; echo
[[ -z "$r_pw" ]] && r_pw="$pw"

tz=$(getprop persist.sys.timezone); tz=${tz:-${TZ:-Etc/UTC}}
loc=$(getprop persist.sys.locale);  loc="${loc:-en_US}"; loc="${loc//-/_}.UTF-8"

yes|pkg up
pkg i -y x11-repo
pkg i -y termux-x11-nightly proot-distro pulseaudio virglrenderer-android
pd i debian

pd login debian --shared-tmp -- sh -c '
    set -e
    u="$1"; p="$2"; rp="$3"; t="$4"; l="$5"

    apt update && DEBIAN_FRONTEND=noninteractive apt install -y \
        sudo xfce4 xfce4-terminal dbus-x11 locales fastfetch firefox-esr

    for g in storage wheel video; do groupadd -f "$g"; done
    useradd -m -g users -G wheel,audio,video,storage -s /bin/bash "$u"
    printf "root:%s\n%s:%s\n" "$rp" "$u" "$p" | chpasswd
    echo "$u ALL=(ALL:ALL) ALL" >> /etc/sudoers

    ln -sf "/usr/share/zoneinfo/$t" /etc/localtime || ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
    printf "en_US.UTF-8 UTF-8\n%s UTF-8\n" "$l" > /etc/locale.gen
    locale-gen && echo "LANG=$l" > /etc/locale.conf
' bash "$user" "$pw" "$r_pw" "$tz" "$loc"

echo "Installation Complete!"