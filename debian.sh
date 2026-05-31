#!/bin/bash
set -e

while :; do
    read -p "Enter username: " user </dev/tty
    [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] && break
done

while :; do
    read -s -p "Enter password for '$user': " pw </dev/tty; printf "\n"
    read -s -p "Confirm password: " cpw </dev/tty; printf "\n"
    [[ -n "$pw" && "$pw" == "$cpw" ]] && break
done

read -s -p "Enter root password (Press Enter to reuse user password): " r_pw </dev/tty; printf "\n"
[[ -z "$r_pw" ]] && r_pw="$pw"

start_time=$(date +%s)

# ADDED: Install termux-api silently before the first toast to fix 'command not found' error
pkg install -y termux-api >/dev/null 2>&1 || true

termux-toast "Starting Debian installation for $user..."

tz=$(getprop persist.sys.timezone); tz=${tz:-${TZ:-Etc/UTC}}
loc=$(getprop persist.sys.locale);  loc="${loc:-en_US}"; loc="${loc//-/_}.UTF-8"

export DEBIAN_FRONTEND=noninteractive
pkg upgrade -y -o Dpkg::Options::="--force-confold"

pkg i -y x11-repo
pkg i -y termux-x11-nightly proot-distro pulseaudio virglrenderer-android termux-api

termux-toast "Termux dependencies installed successfully"

pd i debian

pd login debian --shared-tmp -- sh -c '
    set -e
    u="$1"; p="$2"; rp="$3"; t="$4"; l="$5"

    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y \
        sudo xfce4 xfce4-terminal dbus-x11 locales fastfetch firefox-esr

    for g in storage wheel video; do groupadd -f "$g"; done
    useradd -m -g users -G wheel,audio,video,storage -s /bin/bash "$u"
    printf "root:%s\n%s:%s\n" "$rp" "$u" "$p" | chpasswd
    printf "%s ALL=(ALL:ALL) ALL\n" "$u" >> /etc/sudoers

    ln -sf "/usr/share/zoneinfo/$t" /etc/localtime || ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
    printf "en_US.UTF-8 UTF-8\n%s UTF-8\n" "$l" > /etc/locale.gen
    locale-gen && printf "LANG=%s\n" "$l" > /etc/locale.conf
' bash "$user" "$pw" "$r_pw" "$tz" "$loc"

termux-toast "Debian base system configured"

cat << 'EOF' > "$PREFIX/bin/debian"
#!/bin/bash
{
    pkill -9 -f termux.x11
    killall -9 pulseaudio virgl_test_server_android
    export XDG_RUNTIME_DIR=${TMPDIR}
    termux-x11 :0 -ac & X=$!
    pulseaudio --start --exit-idle-time=-1
    pacmd load-module module-native-protocol-tcp auth-ip-acl=127.0.0.1 auth-anonymous=1
    virgl_test_server_android & V=$!
    proot-distro login debian --user __USERNAME__ --shared-tmp -- bash -c 'export DISPLAY=:0 PULSE_SERVER=tcp:127.0.0.1 GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.0; dbus-launch --exit-with-session startxfce4'
    kill $X $V 2>/dev/null; pulseaudio --kill
} >/dev/null 2>&1 &

tput civis; stty -echo
trap 'tput cnorm; stty echo 2>/dev/null' EXIT
clr() { printf "\033[3A\r\033[J"; }
trap 'clr; exit 1' INT
trap '' TSTP QUIT HUP
printf "Booting Debian...\n[%-30s] 10s\n[ENTER] Open now  [CTRL+C] Abort\n" ""
launch() { clr; am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1; exit; }
bar=""
for i in $(seq 1 30); do
    bar+="#"
    t=$(date +%s%3N)
    printf "\033[2A\r[%-30s] %ds\033[K\033[2B\r" "$bar" $(( (30-i)/3+1 ))
    while (( $(date +%s%3N) - t < 333 )); do
        IFS= read -rs -n1 -t0.05 k; rc=$?
        [[ $rc -eq 0 && -z "$k" ]] && launch
        while IFS= read -rs -n1 -t0 _ 2>/dev/null; do :; done
    done
done
launch
EOF

sed -i "s/__USERNAME__/$user/g" "$PREFIX/bin/debian"

chmod +x "$PREFIX/bin/debian"

end_time=$(date +%s)
elapsed=$((end_time - start_time))
elapsed_min=$((elapsed / 60))
elapsed_sec=$((elapsed % 60))

termux-toast "Installation Complete in ${elapsed_min}m ${elapsed_sec}s! Launch with 'debian'"
echo "Installation Complete in ${elapsed_min}m ${elapsed_sec}s! You can now start Debian by typing 'debian' in your terminal."