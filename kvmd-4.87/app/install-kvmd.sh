#!/bin/bash
# set -x

INSTALLDIR=/tmp/kvmd

# kvmd 3.333 only support Python 3.11
# kvmd 4.85  only supports Python 3.13
# kvmd 4.87  only supports Python 3.13

# based on following github:
# https://github.com/srepac/kvmd-armbian

# source files:
# https://files.pikvm.org/repos/arch/rpi4/
# https://git.kernel.org/pub/scm/libs/libgpiod/libgpiod.git

# ################################################################################
# Title Function
# ################################################################################
Title() {
  echo "################################################################################"
  echo "$*"
  echo "################################################################################"
}

# ################################################################################
# ################################################################################
# Remove pip3 restrictions
rm -f /usr/lib/python3.13/EXTERNALLY-MANAGED

# Install 3rd party software
pip3 install -U async_lru --break-system-packages

# ################################################################################
# *** Install kvmd software ***
# ################################################################################
Title "Installing kvmd software"

cd /
FNL=`ls -1 $INSTALLDIR/kvmd-platform-v4mini-hdmi-rpi4-[0-9]*.[0-9]*-*-any.pkg.tar.xz`
tar xfJ $FNL
[ $? -ne 0 ] && exit 1

FNL=`ls -1 $INSTALLDIR/kvmd-[0-9]*.[0-9]*-*-any.pkg.tar.xz`
tar xfJ $FNL
[ $? -ne 0 ] && exit 1

FNL=`ls -1 $INSTALLDIR/janus-gateway-pikvm-[0-9]*-*-armv7h.pkg.tar.xz`
tar xfJ $FNL
[ $? -ne 0 ] && exit 1

FNL=`ls -1 $INSTALLDIR/kvmd-webterm-[0-9]*.[0-9]*-*-any.pkg.tar.xz`
tar xfJ $FNL
[ $? -ne 0 ] && exit 1

# ################################################################################
# *** Create python links of kvmd ***
# ################################################################################
ln -sf /usr/bin/python3 /usr/bin/python
ln -sf /usr/lib/python3.13/site-packages/kvmd /usr/lib/python3/dist-packages

# ################################################################################
# Add environment variables to kvmd-oled
# ################################################################################

# Fix rotation for BliKVM v1
sed -i 's/return {"height": 64, "rotate": [0,2]}/return {"height": 64, "rotate": 0}/' /usr/lib/python3.13/site-packages/kvmd/apps/oled/__init__.py
[ $? -ne 0 ] && exit 1

# Check sum, before we modify it
SUM=`cat /usr/lib/python3.13/site-packages/kvmd/apps/oled/sensors.py | sum`
if [ "$SUM" != "60378     5" ]; then
  echo "ERROR: kvmd/apps/oled/sensors.py has different checksum ('$SUM' vs '60378     5')"
  exit 1
fi

cp -p /usr/lib/python3.13/site-packages/kvmd/apps/oled/sensors.py /usr/lib/python3.13/site-packages/kvmd/apps/oled/sensors.py.org

# Add "import os"
sed -i 's/import socket/import os\nimport socket/' /usr/lib/python3.13/site-packages/kvmd/apps/oled/sensors.py
[ $? -ne 0 ] && exit 1

# Fix the interface name
sed -i 's/return self.__get_netconf(round(time.monotonic() \/ 0.3))\[0\]/return os.getenv("KVMD_IFACE", default=self.__get_netconf(round(time.monotonic() \/ 0.3))\[0\])/' /usr/lib/python3.13/site-packages/kvmd/apps/oled/sensors.py
[ $? -ne 0 ] && exit 1

# Fix the ip address
sed -i 's/return self.__get_netconf(round(time.monotonic() \/ 0.3))\[1\]/return os.getenv("KVMD_IPADDR", default=self.__get_netconf(round(time.monotonic() \/ 0.3))\[1\])/' /usr/lib/python3.13/site-packages/kvmd/apps/oled/sensors.py
[ $? -ne 0 ] && exit 1

# Fix the hostname
sed -i 's/    def __get_iface(self) -> str:/    def __get_hostname(self) -> str:\n        return os.getenv("KVMD_HOSTNAME", default=socket.getfqdn())\n\n    def __get_iface(self) -> str:/' /usr/lib/python3.13/site-packages/kvmd/apps/oled/sensors.py
sed -i 's/socket\.getfqdn,/self.__get_hostname,/' /usr/lib/python3.13/site-packages/kvmd/apps/oled/sensors.py
[ $? -ne 0 ] && exit 1

# ################################################################################
# Copy configuration
# ################################################################################
Title "Applying configuration"

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

# Overrule default edid.hex with our own
cd $INSTALLDIR
cp tc358743-edid.hex /etc/kvmd/tc358743-edid.hex

ln -sf /usr/share/tesseract-ocr/5/tessdata /usr/share/tessdata

# Hack OTG, otherwise MSD will not work
sed -i "/inquiry_string_cdrom: str,/d" /usr/lib/python3.13/site-packages/kvmd/apps/otg/__init__.py
sed -i "/inquiry_string_flash: str,/d" /usr/lib/python3.13/site-packages/kvmd/apps/otg/__init__.py
sed -i "/inquiry_string_cdrom=/d" /usr/lib/python3.13/site-packages/kvmd/apps/otg/__init__.py
sed -i "/inquiry_string_flash=/d" /usr/lib/python3.13/site-packages/kvmd/apps/otg/__init__.py
sed -i '/_write(join(func_path, "lun.0\/inquiry_string_cdrom")/d' /usr/lib/python3.13/site-packages/kvmd/apps/otg/__init__.py
sed -i '/_write(join(func_path, "lun.0\/inquiry_string")/d' /usr/lib/python3.13/site-packages/kvmd/apps/otg/__init__.py

# ################################################################################
# Copy compiled ttyd to right location
# ################################################################################
Title "Installing ttyd"

cd $INSTALLDIR
cp ttyd.aarch64.* /usr/bin/ttyd
chmod a+x /usr/bin/ttyd

# ################################################################################
# Compile WiringPi
# ################################################################################
Title "Installing WiringPi"

cd $INSTALLDIR
FNL=`ls -1 WiringPi-*.tar.gz`
FNS=`echo $FNL | sed "s/\.tar\.gz//"`

tar xfz $FNL
[ $? -ne 0 ] && exit 1
cd $FNS
[ $? -ne 0 ] && exit 1
./build
[ $? -ne 0 ] && exit 1

cd $INSTALLDIR
rm -rf $FNS
#gpio -v

# ################################################################################
# Compile ustreamer
# ################################################################################
Title "Installing uStreamer"

cd $INSTALLDIR
sed -i -e 's|^#include "refcount.h"$|#include "../refcount.h"|g' /usr/include/janus/plugins/plugin.h

FNL=`ls -1 ustreamer-*.tar.gz`
FNS=`echo $FNL | sed "s/\.tar\.gz//"`

tar xfz $FNL
[ $? -ne 0 ] && exit 1
cd $FNS
[ $? -ne 0 ] && exit 1
make WITH_GPIO=1 WITH_SYSTEMD=1 WITH_JANUS=1 WITH_V4P=1 WITH_PYTHON=1 -j
[ $? -ne 0 ] && exit 1
make install
[ $? -ne 0 ] && exit 1

ln -sf /usr/local/bin/ustreamer /usr/local/bin/ustreamer-dump /usr/bin/
mkdir -p /usr/lib/ustreamer/janus
cp janus/libjanus_ustreamer.so /usr/lib/ustreamer/janus
cp python/root/usr/local/lib/python3.13/dist-packages/ustreamer.cpython-313-aarch64-linux-gnu.so /usr/lib/python3/dist-packages/

cd $INSTALLDIR
rm -rf $FNS

# ################################################################################
# *** Compile janus ***
# ################################################################################
Title "Installing Janus WebRTC"

cd $INSTALLDIR
FNL=`ls -1 janus-gateway-*.tar.gz`
FNS=`echo $FNL | sed "s/\.tar\.gz//"`

tar xfz $FNL
[ $? -ne 0 ] && exit 1
cd $FNS
[ $? -ne 0 ] && exit 1
sh autogen.sh
[ $? -ne 0 ] && exit 1
./configure --prefix=/usr
[ $? -ne 0 ] && exit 1
make
[ $? -ne 0 ] && exit 1
# Only copy single binary, nothing else
cp src/janus /usr/bin/janus
rm -f /usr/lib/janus/transports/*
cp src/transports/.libs/libjanus_websockets.so.2.0.6 /usr/lib/janus/transports/
ln -s /usr/lib/janus/transports/libjanus_websockets.so.2.0.6 /usr/lib/janus/transports/libjanus_websockets.so.2
ln -s /usr/lib/janus/transports/libjanus_websockets.so.2.0.6 /usr/lib/janus/transports/libjanus_websockets.so

cd $INSTALLDIR
rm -rf $FNS

# ################################################################################
# *** Create users/groups/sudo and fix permissions
# ################################################################################
Title "Creating users/groups/sudo"
mkdir /tmp/kvmd-nginx
mkdir /run/kvmd
chmod a+rwx /run/kvmd

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

cd $INSTALLDIR
cp tc358743-edid.hex /etc/kvmd/tc358743-edid.hex

# ################################################################################
# Remove other stuff, otherwise systemctl will try to start it
# ################################################################################
Title "Removing all existing systemctl commands"

rm -f /etc/rc?.d/?01*
rm -f /etc/init.d/*
rm -rf /etc/systemd/system/*
rm -rf /var/lib/systemd/deb-systemd-helper-enabled/*
mv /usr/lib/systemd/system/kvmd*.service /tmp
rm -rf /usr/lib/systemd/system/*
mv /tmp/kvmd*.service /usr/lib/systemd/system

# ################################################################################
# Enable kvmd services
# ################################################################################
Title "Installing systemctl commands"

systemctl enable kvmd-oled.service
systemctl enable kvmd-otg.service
systemctl enable kvmd-nginx.service
systemctl enable kvmd-webterm.service
systemctl enable kvmd-tc358743.service
systemctl enable kvmd-janus.service
systemctl enable kvmd-media.service
systemctl enable kvmd.service

# Install custom services to fix docker issues
cd $INSTALLDIR
cp kvmd-first /usr/bin
cp kvmd-last /usr/bin
cp kvmd-first.service /usr/lib/systemd/system/kvmd-first.service 
cp kvmd-last.service /usr/lib/systemd/system/kvmd-last.service 

systemctl enable kvmd-first.service
systemctl enable kvmd-last.service

# ################################################################################
# Update motd of terminal
# ################################################################################
cd $INSTALLDIR
cp armbian-motd /usr/bin/
sed -i 's/cat \/etc\/motd/armbian-motd/g' /lib/systemd/system/kvmd-webterm.service

# ################################################################################
# Install extras stub file for e.g. terminal
# ################################################################################
cd $INSTALLDIR
cp extras_stub.py /usr/lib/python3.13/site-packages/kvmd/apps/kvmd/info/

# Modify extras.py file to execute the stub code
cp -p /usr/lib/python3.13/site-packages/kvmd/apps/kvmd/info/extras.py /usr/lib/python3.13/site-packages/kvmd/apps/kvmd/info/extras.py.bak
sed -i '/async def get_state/a \        from .extras_stub import extras_stub_list\n        return extras_stub_list()' /usr/lib/python3.13/site-packages/kvmd/apps/kvmd/info/extras.py

# ################################################################################
# vcgencmd binary is mandatory, dirty hack to copy it
# ################################################################################
cd $INSTALLDIR
cp vcgencmd /usr/bin/vcgencmd

# ################################################################################
# Fix Janus ws-socket permissions, that group has also write access
# ################################################################################
cd $INSTALLDIR
cp kvmd-janus /usr/bin/kvmd-janus

# ################################################################################
# Add a dummy file to /etc/fstab for MSD support
# ################################################################################
cat <<EOF >>/etc/fstab
/storage.img  /var/lib/kvmd/msd   ext4  nodev,nosuid,noexec,rw,errors=remount-ro,data=journal,X-kvmd.otgmsd-root=/var/lib/kvmd/msd,X-kvmd.otgmsd-user=kvmd  0  0
EOF

# ################################################################################
# Delete the temp directory
# ################################################################################
rm -rf /tmp/kvmd

exit 0
