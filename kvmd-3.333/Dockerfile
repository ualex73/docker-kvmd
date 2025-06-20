FROM dtcooper/raspberrypi-os:bookworm
#FROM dtcooper/raspberrypi-os:python3.11-bookworm

# Install all required packages
RUN apt-get update && apt-get install -y lsof vim-tiny wget sudo git make libevent-dev libjpeg-dev libbsd-dev libgpiod-dev libsystemd-dev libmd-dev libdrm-dev janus-dev janus nginx python3 net-tools bc expect v4l-utils iptables dos2unix screen tmate nfs-common gpiod ffmpeg dialog iptables dnsmasq git python3-pip tesseract-ocr tesseract-ocr-eng libasound2-dev libsndfile-dev libspeexdsp-dev libdrm-dev build-essential cmake git libjson-c-dev libwebsockets-dev libevent-2.1-7 libevent-core-2.1-7 libevent-pthreads-2.1-7 build-essential && apt-get install -y python3-aiofiles python3-aiohttp python3-appdirs python3-asn1crypto python3-async-timeout python3-bottle python3-cffi python3-chardet python3-click python3-colorama python3-cryptography python3-dateutil python3-dbus python3-dev python3-hidapi python3-idna python3-libgpiod python3-mako python3-marshmallow python3-more-itertools python3-multidict python3-netifaces python3-packaging python3-passlib python3-pillow python3-ply python3-psutil python3-pycparser python3-pyelftools python3-pyghmi python3-pygments python3-pyparsing python3-requests python3-semantic-version python3-setproctitle python3-setuptools python3-six python3-spidev python3-systemd python3-tabulate python3-urllib3 python3-wrapt python3-xlib python3-yaml python3-yarl python3-pyotp python3-qrcode python3-serial python3-serial-asyncio python3-dbus-next python3-zstandard python3-build autoconf-archive libtool dh-autoreconf python3-luma.core python3-luma.oled

# Copy install files
COPY app/* /tmp

# https://github.com/gdraheim/docker-systemctl-replacement/tree/master
COPY app/systemctl3.py /usr/bin/systemctl
RUN test -e /bin/systemctl || ln -sf /usr/bin/systemctl /bin/systemctl

# Install kvmd software
RUN /bin/bash /tmp/install-kvmd.sh

# Define startup script
#CMD [ "/bin/bash", "/run.sh" ]
CMD ["/usr/bin/systemctl"]
