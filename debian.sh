#!/bin/bash
set -e

while :; do
    read -p "Enter username: " user </dev/tty
    [[ "$user" =~ ^[a-z_][a-z0-9_-]*$ ]] && break || echo "Invalid username."
done

while :; do
    read -s -p "Enter password for '$user': " pw </dev/tty; echo
    read -s -p "Confirm password: " cpw </dev/tty; echo
    [[ -n "$pw" && "$pw" == "$cpw" ]] && break || echo "Mismatch. Retry."
done

read -s -p "Enter root password (Press Enter to reuse user password): " r_pw </dev/tty; echo
[[ -z "$r_pw" ]] && r_pw="$pw"

start_time=$(date +%s)

pkg install -y termux-api

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
    
    echo "$u ALL=(ALL:ALL) ALL" >> /etc/sudoers

    ln -sf "/usr/share/zoneinfo/$t" /etc/localtime || ln -sf /usr/share/zoneinfo/Etc/UTC /etc/localtime
    printf "en_US.UTF-8 UTF-8\n%s UTF-8\n" "$l" > /etc/locale.gen
    
    locale-gen && echo "LANG=$l" > /etc/locale.conf
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
trap 'clr; pkill -9 -f termux.x11 2>/dev/null; killall -9 pulseaudio virgl_test_server_android 2>/dev/null; termux-toast "Aborted."; echo "Aborted."; exit 1' INT
trap '' TSTP QUIT HUP
launch() { clr; am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1; termux-toast "Debian Launched!"; echo "Debian Launched!"; exit; }
run_countdown() { clr; am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1; echo "Success."; exit; }
# Changed progress bar to dynamically adapt to terminal screen size (tput cols) instead of a fixed character width, keeping fill speed proportional to countdown time
run_countdown() {
    local secs=$1
    local cols=$(tput cols 2>/dev/null || echo 80)
    local bar_width=$(( cols - 12 ))
    (( bar_width < 10 )) && bar_width=10
    local steps=$((secs * 3))
    printf "Booting Debian...\n[%-${bar_width}s] %ds\n[ENTER] Open now  [CTRL+C] Abort\n" "" "$secs"
    for i in $(seq 1 $steps); do
        local filled=$(( i * bar_width / steps ))
        local bar=""
        for ((j=0; j<filled; j++)); do bar+="#"; done
        local t=$(date +%s%3N)
        printf "\033[2A\r[%-${bar_width}s] %ds\033[K\033[2B\r" "$bar" $(( (steps-i)/3+1 ))
        while (( $(date +%s%3N) - t < 333 )); do
            IFS= read -rs -n1 -t0.05 k; rc=$?
            [[ $rc -eq 0 && -z "$k" ]] && launch
            while IFS= read -rs -n1 -t0 _ 2>/dev/null; do :; done
        done
    done
    launch
}
run_countdown 10
EOF

sed -i "s/__USERNAME__/$user/g" "$PREFIX/bin/debian"

chmod +x "$PREFIX/bin/debian"

end_time=$(date +%s)
elapsed=$((end_time - start_time))
elapsed_min=$((elapsed / 60))
elapsed_sec=$((elapsed % 60))

termux-toast "Installation Complete in ${elapsed_min}m ${elapsed_sec}s! Launch with 'debian'"
echo "Installation Complete in ${elapsed_min}m ${elapsed_sec}s! You can now start Debian by typing 'debian' in your terminal."