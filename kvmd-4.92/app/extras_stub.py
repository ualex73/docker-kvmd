
import os

kvmfile = "/tmp/systemctl-kvmd.txt"

def extras_stub_list():

    extras = {
       'janus': {'name': 'Janus', 'description': 'Janus WebRTC Gateway', 'path': 'janus', 'daemon': 'kvmd-janus', 'place': -1, 'enabled': False, 'started': False}, 
       'vnc': {'name': 'VNC', 'description': 'Show VNC information', 'icon': 'share/svg/vnc.svg', 'path': 'vnc', 'daemon': 'kvmd-vnc', 'port': 5900, 'place': 20, 'enabled': False, 'started': False}, 
       'ipmi': {'name': 'IPMI', 'description': 'Show IPMI information', 'icon': 'share/svg/ipmi.svg', 'path': 'ipmi', 'daemon': 'kvmd-ipmi', 'port': 623, 'place': 21, 'enabled': False, 'started': False}, 
       'janus_static': {'name': 'Janus Static', 'description': 'Janus WebRTC Gateway (Static Config)', 'path': 'janus', 'daemon': 'kvmd-janus-static', 'place': -1, 'enabled': False, 'started': False}, 
       'webterm': {'name': 'Terminal', 'description': 'Open terminal in a web browser', 'icon': 'extras/webterm/terminal.svg', 'path': 'extras/webterm/ttyd', 'daemon': 'kvmd-webterm', 'place': 10, 'enabled': False, 'started': False}
    }

    # If temporary file does not exist, run external command
    if not os.path.isfile(kvmfile):

        # Create temporary file
        #os.system("systemctl -t service --state=running | grep '^kvmd' | sed 's/\t/ /g'  | cut -f 1 -d ' '>%s" % kvmfile)
        return extras

    # Read file
    fin = open(kvmfile, 'r')

    # Read all lines into a list
    lines = fin.readlines()

    for line in lines:
        name = line.replace("kvmd-", "").replace(".service\n", "")

        if name in extras:
            extras[name]["enabled"] = True
            extras[name]["started"] = True

    # Return information
    return extras

# copy into: /usr/lib/python3.11/site-packages/kvmd/apps/kvmd/info
#
#    async def get_state(self) -> (dict | None):                              
#
#        from .extras_stub import extras_stub_list
#        return extras_stub_list()

