# KVMD running in Docker

## About

This repository is a proof-of-concept to run [PiKVM](https://pikvm.org) (kvmd) in Docker on a BliKVM v1 (using Raspberry CM4). The installation procedure was inspired by [srepac](https://github.com/srepac/kvmd-armbian). KVMD is only supported on their ArchLinux and I prefer to run it on Raspberry Pi OS, but the changes in software, configuration, version, etc makes it very prone to errors (where a docker image is static and predictable).

The following kvmd versions are available as Docker container:
- [3.333](https://hub.docker.com/r/ualex73/kvmd/tags?name=3.333)
- [4.85](https://hub.docker.com/r/ualex73/kvmd/tags?name=4.85)
- [4.87](https://hub.docker.com/r/ualex73/kvmd/tags?name=4.87)

The following features has been tested:
- WebGUI
- OTG (keyboard, mouse and mass storage)

Following services are disabled and not tested (but should work):
- IPMI
- VNC

To be tested:
- KVM switch

## Requirements

This has been tested successfully on Raspberry Pi 12 (Bookworm)

## Run

Run the `install-host.sh` script to update the system with required kernel parameters and modules. Reboot after you run it.

There is normally no external storage/configuration required to run the default installation. Login credentials are admin/admin.

**docker-compose.yaml** Example for kvmd 3.333
```
services:

  pikvm:
    container_name: pikvm
    hostname: pikvm # used in WebGUI
    image: ualex73/pikvm:3.333-1
    restart: unless-stopped
    #network_mode: host # not required for MJPEG 
    privileged: true # privileged is required for GPIO
    ports:
      - 443:443 # HTTPS
      # - 80:80 # HTTP, with redirection
      # - 5900:5900 # VNC
    volumes:
     - /dev:/dev # Required for USB/Video devices
     - /sys:/sys # required for USB OTG (keyboard/mouse/msd)
```

**docker-compose.yaml** Example for kvmd 4.87
```
services:

  pikvm:
    container_name: pikvm
    hostname: pikvm # used in WebGUI if network_mode is disabled
    image: ualex73/pikvm:4.87-1
    restart: unless-stopped
    network_mode: host # Required for WebRTC, for H264/MJPEG it is not needed
    privileged: true # privileged is required for GPIO
    volumes:
     - /dev:/dev # Required for USB/Video devices
     - /sys:/sys # required for USB OTG (keyboard/mouse/msd)

    # Port(s) are required when "network_mode: host" is not used
    #ports:
    #  - 443:443 # HTTPS
    #  - 80:80 # HTTP, with redirection
    #  - 5900:5900 # VNC

    # You can set the hostname/ip/iface in the oled screen
    # this is handy if you do not use "network_mode: host"
    #environment:
    # - KVMD_HOSTNAME=ualex73.domain.com
    # - KVMD_IPADDR=192.168.1.1
    # - KVMD_IFACE=eth0
```

## Extra's

### Storage for ISO files

Create a file like `msd.yaml`:
```
kvmd:
    msd:
        type: otg
```

Create a file as follows:
```
fallocate -l 8000M storage.img
mkfs.ext4 storage.img
```

Mount it in the volume section like:
```
volumes:
  - ./msd.yaml:/etc/kvmd/override.d/msd.yaml
  - ./storage.img:/storage.img
```

NOTE: filename `/storage.img` in container is hardcoded

## Troubleshoot
**Question:** I get an error, where are the logfiles?  
**Answer:** They are stored inside the container in the directory `/var/log/journal`

**Question:** Can i enable IPMI, VNC or other services?  
**Answer:** Yes, but need to be repeated if you re-create the container. Go into the container and executed for example for IPMI `systemctl enable kvmd-ipmi.service` and restart the container.  

**Question:** Can i customize the /etc/kvmd configuration?  
**Answer:** Yes. You can mount the file via the volume configuration. For example to overrule the EDID configuration, you can do following steps:
```
docker cp <container-name>:/etc/kvmd/tc358743-edid.hex ./tc358743-edid.hex
```

(modify the file)  
Add to the `docker-compose.yaml` the following line:
```
- ./tc358743-edid.hex:/etc/kvmd/tc358743-edid.hex
```

***Question:*** Can I change the HTTP and/or HTTPS port from 80/443 to something else?  
**Answer**:
Create a file like `nginx-change.yaml`:
```
nginx:
    http:
        port: 81
    https:
        port: 543
```

Mount it in the volume section like:
```
volumes:
  - ./nginx-change.yaml:/etc/kvmd/override.d/nginx-change.yaml
```

Restart the container


## Known issues

If the container is restarted a few times, it could happen KVMD stops working (no clear reproduction scenario just yet). A reboot of the node will fix this again.

