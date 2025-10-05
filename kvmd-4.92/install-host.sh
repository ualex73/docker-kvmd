#!/bin/bash

# Add group kvmd as 900, needs to be done too in the container
groupadd -g 900 kvmd

# Update /boot*/config.txt
if [ -f "/boot/firmware/config.txt" ]; then
  BOOTCONF="/boot/firmware/config.txt"
else
  BOOTCONF="/boot/config.txt"
fi

# Check if otg is disabled, otherwise kvmd-otg will not started
grep "^otg_mode=" $BOOTCONF
if [ $? -eq 1 ]; then
  echo "INFO: Disabled otg_mode in $BOOTCONF ..."
  sed -i "s/otg_mode=/#otg_mode=/" $BOOTCONF
else
  echo "WARN: Not disabling otg_mode in $BOOTCONF, they seem to disabled already ..."
fi

grep -q "# Custom PiKVM" $BOOTCONF
if [ $? -eq 1 ]; then 
  echo "INFO: Adding entries to $BOOTCONF ..."
  cat <<EOF >> $BOOTCONF
# ##############################################################################
# Custom PiKVM
# ##############################################################################

hdmi_force_hotplug=1
gpu_mem=128
enable_uart=1

# Video (CM4)
dtoverlay=tc358743,4lane=1

dtoverlay=disable-bt
dtoverlay=dwc2,dr_mode=peripheral
dtparam=act_led_gpio=13

# HDMI audio capture
dtoverlay=tc358743-audio

# SPI (AUM)
dtoverlay=spi0-1cs

# I2C (display)
dtparam=i2c_arm=on

# Clock
dtoverlay=i2c-rtc,pcf8563
EOF
else
  echo "WARN: Not adding entries to $BOOTCONF, they seem to exist already ..."
fi

# Update /etc/modules

grep -q "# Custom PiKVM" /etc/modules
if [ $? -eq 1 ]; then
  echo "INFO: Adding entries to /etc/modules ..."
  cat <<EOF >> /etc/modules
# ##############################################################################
# Custom PiKVM
# ##############################################################################
tc358743
dwc2
libcomposite
i2c-dev
EOF
else
  echo "WARN: Not adding entries to /etc/modules, they seem to exist already ..."
fi

echo "INFO: Creating /etc/udev/rules.d/99-kvmd.rules"
cat <<EOF >/etc/udev/rules.d/99-kvmd.rules 
KERNEL=="video[0-9]*", SUBSYSTEM=="video4linux", KERNELS=="fe801000.csi|fe801000.csi1", ATTR{name}=="unicam-image", GROUP="kvmd", SYMLINK+="kvmd-video", TAG+="systemd"
KERNEL=="hidg0", GROUP="kvmd", SYMLINK+="kvmd-hid-keyboard"
KERNEL=="hidg1", GROUP="kvmd", SYMLINK+="kvmd-hid-mouse"
KERNEL=="hidg2", GROUP="kvmd", SYMLINK+="kvmd-hid-mouse-alt"
EOF

exit 0
