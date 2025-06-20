# KVMD running in Docker

## About

This repository is a proof-of-concept to run [PiKVM](https://pikvm.org) in Docker on a BliKVM v1 (using Raspberry CM4). The installation procedure was inspired by [srepac](https://github.com/srepac/kvmd-armbian).

**At this moment only kvmd 3.333 has been tested***

The following has been tested:
- WebGUI
- OTG (USB devices)

Following services are disabled and not tested (but should work):
- IPMI
- VNC

To be tested:
- MSD (mass storage device)
- KVM switch

## Requirements

This has been tested successfully on Raspberry Pi 12 (Bookworm)

## Run

Run the `install-host.sh` script to update the system with required kernel parameters and modules. Reboot after you run it.

There is normally no external storage/configuration required to run the default installation. Login credentials are admin/admin.

**docker-compose.yaml Example**
```
services:

  pikvm:
    container_name: pikvm
    hostname: pikvm # used in WebGUI
    image: ualex73/pikvm:3.333-1
    restart: unless-stopped
    privileged: true # privileged is required for GPIO
    ports:
      - 443:443 # HTTPS
      # 80:80 # HTTP, with redirection
      # 5900:5900 # VNC
    volumes:
     - /dev:/dev # Required for USB/Video devices
     - /sys:/sys # required for USB OTG (keyboard/mouse/msd)
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
            - ./tc358743-edid.hex /etc/kvmd/tc358743-edid.hex
```
            Restart the container


## Known issues

If the container is restarted a few times, it could happen KVMD stops working (no clear reproduction scenario just yet). A reboot of the node will fix this again.

