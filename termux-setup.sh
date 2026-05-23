#!/data/data/com.termux/files/usr/bin/bash
yes | (pkg up && pkg i x11-repo && pkg i termux-x11-nightly proot-distro pulseaudio virglrenderer-android)
pd i debian
pd login debian --shared-tmp -- sh -c '
apt update && DEBIAN_FRONTEND=noninteractive apt install -y sudo chromium xfce4 xfce4-terminal dbus-x11 locales fastfetch firefox-esr
groupadd storage; groupadd wheel; groupadd video
useradd -mg users -G wheel,audio,video,storage -s /bin/bash nue
printf "root:000\nnue:000\n" | chpasswd
echo "nue ALL=(ALL:ALL) ALL" >> /etc/sudoers
ln -sf /usr/share/zoneinfo/Asia/Jakarta /etc/localtime
echo "en_US.UTF-8 UTF-8" > /etc/locale.gen && locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf'
