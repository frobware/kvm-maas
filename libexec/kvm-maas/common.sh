set -a

: ${QEMU_URI:=qemu:///system}
: ${VIRT_IMAGE_TYPE:=qcow2}
: ${MAAS_PROFILE:=undefined}
: ${VIRT_POOL:=default}
: ${VIRT_IMAGE_DIR:=/var/lib/libvirt/images}
: ${VIRT_CPUS:=1}
: ${VIRT_RAM:=2048}
: ${VIRT_DISK_SIZE:=16}
: ${TAGS:=}
: ${ENLIST_TIMEOUT:=240}

set +a

die() {
    echo "error:" "$@"
    exit 1
}

defvar() {
    IFS='\n' read -r -d '' ${1} || true
}

defvar LIBVIRT_PREAMBLE <<-EOF
import libvirt, sys
conn=libvirt.open("$QEMU_URI")
if conn is None:
    print('Failed to open connection to $QEMU_URI')
    exit(1)
EOF

maas_version() {
    local profile=$1
    maas $profile version read | python2 <(cat <<EOF
import json, sys
result = json.load(sys.stdin)
if 'version' in result:
    if result['version'].startswith("2"):
        print("2")
    else:
        print("1")
EOF
) -
}

maas_system_id() {
    local profile=$1
    local version=$(maas_version $profile)
    local op="list"
    case $version in
	2*) op="read";;
    esac
    maas $profile nodes $op | python2 <(cat <<EOF
import json, sys
for node in json.load(sys.stdin):
    if 'macaddress_set' in node:
        for mac_info in node['macaddress_set']:
            if mac_info['mac_address'] == sys.argv[2]:
                print(node['system_id'])
                exit(0)
    if 'interface_set' in node:
        for mac_info in node['interface_set']:
            if mac_info['mac_address'] == sys.argv[2]:
                print(node['system_id'])
                exit(0)
EOF
) - $2
}

virt_network_address() {
    local network=$1
    echo $(virsh net-dumpxml $network | xmlstarlet sel -t -v '//network/ip/@address')
}

virt_domain_ip_address() {
    local domain=$1
    echo $(virsh dumpxml $domain | xmlstarlet sel -t -v '//interface/mac/@address' | head -n1)
}

virt_network_exists() {
    local network=$1
    python2 - $network <<EOF
$LIBVIRT_PREAMBLE
for name in conn.listNetworks():
    if name == sys.argv[1]:
        exit(0)
exit(1)
EOF
}

virt_domain_exists() {
    local domain=$1
    python2 - $domain <<EOF
$LIBVIRT_PREAMBLE
for d in conn.listAllDomains(0):
    if d.name() == sys.argv[1]:
        exit(0)
exit(1)
EOF
}

virt_domain_is_running() {
    local domain=$1
    python2 - $domain <<EOF
$LIBVIRT_PREAMBLE
for d in conn.listAllDomains(libvirt.VIR_CONNECT_LIST_DOMAINS_RUNNING):
    if d.name() == sys.argv[1]:
        exit(0)
exit(1)
EOF
}

virt_domain_state() {
    local domain=$1
    python2 - $domain <<EOF
dom_state = (
    "nostate",
    "running",
    "blocked",
    "paused",
    "shutdown",
    "shut off",
    "crashed",
    "pmsuspended"
)
$LIBVIRT_PREAMBLE
for d in conn.listAllDomains(0):
    if d.name() == sys.argv[1]:
        print(dom_state[d.state()[0]])
        exit(0)
exit(1)
EOF
}

virt_domain_volume_path() {
    local pool=$1
    local volume=$2
    python2 - $pool $volume <<EOF
$LIBVIRT_PREAMBLE
for pool in conn.listAllStoragePools(0):
    if pool.name() == sys.argv[1]:
        for v in pool.listAllVolumes(0):
            if v.name() == sys.argv[2]:
                print(v.path())
                exit(0)
EOF
}
