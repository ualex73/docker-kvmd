#!/bin/bash

# based on following github:
# https://github.com/srepac/kvmd-armbian

# Remove pip3 restrictions
rm -f /usr/lib/python3.11/EXTERNALLY-MANAGED

# Install 3rd party software
pip3 install -U async_lru --break-system-packages

# Install kvmd software
cd /
tar xfJ /tmp/kvmd-platform-v4mini-hdmi-rpi4-3.333-1-any.pkg.tar.xz
tar xfJ /tmp/kvmd-3.333-1-any.pkg.tar.xz
tar xfJ /tmp/kvmd-webterm-0.48-1-any.pkg.tar.xz
tar xfJ /tmp/kvmd-oled-0.26-1-any.pkg.tar.xz

# Create python links
ln -sf /usr/bin/python3 /usr/bin/python
ln -sf /usr/lib/python3.11/site-packages/kvmd /usr/lib/python3/dist-packages

# Fix xk_hk4401, otherwise it does not support the kvm-switch v2
cd /tmp
cp xh_hk4401.py /usr/lib/python3.11/site-packages/kvmd/plugins/ugpio/xh_hk4401.py

# Fix oled stuff
mkdir -p /usr/share/fonts/TTF
wget -q -O /usr/share/fonts/TTF/ProggySquare.ttf https://fontsfree.net/wp-content/fonts/bitmap/pixel-bitmap/FontsFree-Net-ProggySquare.ttf

# Fix rotation for BliKVM v1
sed -i 's/"rotate": 2/"rotate": 0/' /usr/bin/kvmd-oled

# Copy configuration
cp /etc/kvmd/main.yaml /etc/kvmd/main.yaml.orig
cp /usr/share/kvmd/configs.default/kvmd/main/v4mini-hdmi-rpi4.yaml /etc/kvmd/main.yaml
cp /etc/kvmd/tc358743-edid.hex /etc/kvmd/tc358743-edid.hex.orig
cp /usr/share/kvmd/configs.default/kvmd/edid/v4plus.hex /etc/kvmd/tc358743-edid.hex
cd /etc/kvmd/nginx/ssl
openssl ecparam -out server.key -name prime256v1 -genkey
openssl req -new -x509 -sha256 -nodes -key server.key -out server.crt -days 3650 -subj /C=US/ST=Denial/L=Denial/O=Pi-KVM/OU=Pi-KVM/CN=kvmd-pi
cp server.crt server.key /etc/kvmd/vnc/ssl/

# Switch override.d and override.yaml, to make it easier to apply configuration in docker
# Then we just need to mount a file in /etc/kvmd/override.d/<filename> and that's it
sed -i "s/override.d, override.yaml/override.yaml, override.d/" /etc/kvmd/main.yaml

# Create default override configuration file
cat <<EOF >> /etc/kvmd/override.yaml
kvmd:
    ### disable fan socket check ###
    info:
        fan:
            unix: ''
    hid:
        mouse_alt:
            device: /dev/kvmd-hid-mouse-alt
    ### Disable mass storage device ###
    msd:
        type: disabled
    streamer:
        forever: true
        cmd_append:
            - "--slowdown"      # so target doesn't have to reboot
    ### Disable ATX button in GUI ###
    atx:
        type: disabled

EOF

ln -sf /usr/share/tesseract-ocr/5/tessdata /usr/share/tessdata

# Copy compiled ttyd to right location
cd /tmp
cp ttyd.aarch64.* /usr/bin/ttyd
chmod a+x /usr/bin/ttyd

# Compile WiringPi
cd /tmp
tar xfz WiringPi.*.tar.gz
cd WiringPi-*
./build
cd /tmp
rm -rf WiringPi-*
#gpio -v

# Compile ustreamer
cd /tmp
sed -i -e 's|^#include "refcount.h"$|#include "../refcount.h"|g' /usr/include/janus/plugins/plugin.h
tar xfz ustreamer.*.tar.gz
cd ustreamer-*
make WITH_GPIO=1 WITH_SYSTEMD=1 WITH_JANUS=1 WITH_V4P=1 WITH_PYTHON=1 -j
make install
ln -sf /usr/local/bin/ustreamer /usr/local/bin/ustreamer-dump /usr/bin/
mkdir -p /usr/lib/ustreamer/janus
cp janus/libjanus_ustreamer.so /usr/lib/ustreamer/janus
cd /tmp
rm -rf ustreamer-*

# Compile libgpio v2, required for pikvm 3.292+
cd /tmp
tar xfz libgpiod.2.1.1.tar.gz 
cd libgpiod-*
./autogen.sh --enable-tools=yes --enable-bindings-python=yes --prefix=/usr
make
make install
cd /tmp
rm -rf libgpiod-*

#get rid of this line, otherwise kvmd-nginx won't start properly since the nginx version is not 1.25 and higher
sed -i -e '/http2 on;/d' /usr/bin/kvmd-nginx-mkconf /etc/kvmd/nginx/nginx.conf.mako

mkdir /run/kvmd
chmod a+rwx /run/kvmd

mkdir /tmp/kvmd-nginx
#/run/kvmd/nginx.conf ????

# !!! we need to sync kvmd group id to host !!!
sed -i "s/g kvmd - -/g kvmd 900 -/" /usr/lib/sysusers.d/kvmd.conf
systemd-sysusers /usr/lib/sysusers.d/kvmd.conf
systemd-sysusers /usr/lib/sysusers.d/kvmd-webterm.conf

mkdir -p /home/kvmd-webterm
chown kvmd-webterm /home/kvmd-webterm
chown kvmd:kvmd /etc/kvmd/htpasswd
chown kvmd-ipmi:kvmd-ipmi /etc/kvmd/ipmipasswd
chown kvmd-vnc:kvmd-vnc /etc/kvmd/vncpasswd
chown kvmd:kvmd /etc/kvmd/totp.secret

echo 'kvmd ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/kvmd
echo 'kvmd-webterm ALL=(ALL) NOPASSWD: ALL' >>/etc/sudoers.d/kvmd
chmod 440 /etc/sudoers.d/kvmd

# Overrule default edid.hex with our own
cd /tmp
cp tc358743-edid.hex /etc/kvmd/tc358743-edid.hex

# Finally put run.sh script in place
cd /tmp
cp run.sh /

# Remove other stuff, otherwise systemctl will try to start it
rm -f /etc/init.d/*
rm -rf /etc/systemd/system/*
rm -rf /var/lib/systemd/deb-systemd-helper-enabled/*
mv /usr/lib/systemd/system/kvmd*.service /tmp
rm -rf /usr/lib/systemd/system/*
mv /tmp/kvmd*.service /usr/lib/systemd/system

# Enable kvmd services
systemctl enable kvmd-oled.service
systemctl enable kvmd-otg.service
systemctl enable kvmd-nginx.service
systemctl enable kvmd-webterm.service
systemctl enable kvmd-tc358743.service
systemctl enable kvmd-janus-static.service
systemctl enable kvmd.service

# Install custom services to fix docker issues
cd /tmp
cp kvmd-first /usr/bin
cp kvmd-last /usr/bin
cp kvmd-first.service /usr/lib/systemd/system/kvmd-first.service 
cp kvmd-last.service /usr/lib/systemd/system/kvmd-last.service 

systemctl enable kvmd-first.service
systemctl enable kvmd-last.service

# xxx
cp /tmp/armbian-motd /usr/bin/
sed -i 's/cat \/etc\/motd/armbian-motd/g' /lib/systemd/system/kvmd-webterm.service

# Install extras stub file
cp /tmp/extras_stub.py /usr/lib/python3.11/site-packages/kvmd/apps/kvmd/info/

# Modify extras.py file to execute the stub code
cp -p /usr/lib/python3.11/site-packages/kvmd/apps/kvmd/info/extras.py /usr/lib/python3.11/site-packages/kvmd/apps/kvmd/info/extras.py.bak
sed -i '/async def get_state/a \        from .extras_stub import extras_stub_list\n        return extras_stub_list()' /usr/lib/python3.11/site-packages/kvmd/apps/kvmd/info/extras.py

# Add a dummy file to /etc/fstab for MSD support
cat <<EOF >>/etc/fstab
/storage.img  /var/lib/kvmd/msd   ext4  nodev,nosuid,noexec,rw,errors=remount-ro,data=journal,X-kvmd.otgmsd-root=/var/lib/kvmd/msd,X-kvmd.otgmsd-user=kvmd  0  0
EOF

# Delete the /tmp directory
#rm -rf /tmp/*

exit 0
