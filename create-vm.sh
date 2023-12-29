#!/bin/bash

set -o pipefail
set -o errtrace

log(){
    echo "[$(date -Iseconds)][${0}] ${1}"
}

cleanup(){
    # Terminates preseed server if it is still running
    if [[ -n $(docker ps -a | tail +2 | awk '{print $2}' | grep ^preseed-server$ || echo "") ]]; then
        log "Stopping preseed server..."
        docker rm -f preseed-server > /dev/null
        log "Preseed server stopped."
    fi
}

catch(){
    cleanup
    log "ERROR: An error occurred on line ${1}" 1>&2
    exit 1
}

help(){
    echo -e "\nUSAGE: ./create-vm.sh [yaml_file_with_parameters]\n"
    echo -e "Creates a Debian VM with the parameters in the provided YAML file.\n"
    echo "ARGUMENTS:"
    echo -e "Accepts a single argument, the path to a YAML file with the following structure:\n"
    echo "# Example YAML file"
    echo -e "\n# Host settings"
    echo "host:"
    echo "  connection: qemu:///system # Points to local libvirtd"
    echo "  #connection: qemu+tcp://localhost/system # Points to remote libvirtd on specified host"
    echo -e "\n# VM settings"
    echo "vm:"
    echo "  name: debian           # VM name"
    echo "  cpu: 2                 # CPU allocation in vCPUs"
    echo "  memory: 2048           # Memory allocation in MiB"
    echo "  diskSize: 20           # Virtual disk size in GB"
    echo "  network: default       # 'default' uses libvirt NAT network, otherwise specify name of bridge"
    echo "  #network: bridge=br0   # Enables bridge networking, bridge must already exist in advance"
    echo -e "\n# OS settings"
    echo "os:"
    echo "  version: debian12      # OS version"
    echo "  diskImage: /var/lib/libvirt/images/debian-12.4.0-amd64-netinst.iso  # Path to disk image"
    echo "  #diskImage: https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/ # Link to disk image root directory"
    echo "  hostName: debian       # VM host name"
    echo "  domainName: debian     # VM domain name"
    echo -e "\n# User settings"
    echo "user:"
    echo "  fullName: debian-user  # Linux user full name (does not have to be a real name)"
    echo "  userName: debian-user  # Linux username"
    echo -e "\nIf no argument is passed, this help message is printed."
}

# Creates a preseed file based on 'preseed-template.cfg'
create_preseed(){
    cat preseed-template.cfg | sed -e "s|\$HOST_NAME|${host_name}|g" -e "s|\$DOMAIN_NAME|${domain_name}|g" -e "s|\$FULL_NAME|${full_name}|g" -e "s|\$USERNAME|${username}|g" -e "s|\$PASSWORD|${password}|g" > preseed.cfg
    log "'preseed.cfg' created!"
}

# Creates a web server that serves preseed on port 8080
serve_preseed(){
    log "Creating preseed server to allow remote access to '${preseed}'..."
    docker build . -f ./preseed.Dockerfile -t preseed-server
    log "Starting preseed server on port 8080..."
    docker run -d -p 8080:80 --name preseed-server preseed-server
    log "Preseed server started!"
}

create_vm(){
    log "Creating Debian user password..."
    local password=$(pwgen -1)

    log "Creating Debian preseed..."
    create_preseed
    local preseed=preseed.cfg
    local initrd_inject="--initrd-inject ${preseed}"
    local extra_args="console=tty0 console=ttyS0,115200n8 serial"

    # For VM creation on a remote host
    if [[ -n $(echo $connection | grep ^qemu+tcp || echo "") ]]; then
        serve_preseed
        preseed=http://$(hostname --fqdn):8080/${preseed}
        initrd_inject=""
        extra_args="${extra_args} auto=true priority=critical preseed/url=${preseed} debian-installer/locale=en_US keyboard-configuration/xkb-keymap=us"
    fi

    log "Creating VM ${vm_name}..."
    virt-install \
    --connect $connection \
    --virt-type kvm \
    --name $vm_name  \
    --os-variant $os_version \
    --location $disk_image \
    --disk size=${disk_size} \
    --vcpus $cpu \
    --cpu host-passthrough \
    --ram $memory \
    --graphics none \
    --network $network \
    $initrd_inject \
    --extra-args "${extra_args}" \
    --noreboot

    log "Checking state of VM ${vm_name}..."
    virsh dominfo $vm_name
    if [[ $? -eq 1 ]]; then
        catch "${LINENO}: Creation of VM $vm_name failed."
    fi

    log "VM $vm_name successfully created!"
    log "VM name: ${vm_name}"
    log "VM host name: ${host_name}"
    log "VM domain name: ${domain_name}"
    log "Debian username: ${username}"
    log "Debian password: ${password}"
    log "Use virsh or virt-manager for more information."
}

main(){
    if [[ -z $1 ]]; then
        help
        exit
    elif ! [[ -f $1 ]]; then
        catch "${LINENO}: File '${1}' not found.$(help)"
    fi 
    
    log "Parsing '${1}'..."
    # Host settings
    local connection=$(cat $1 | yq -r .host.connection)
    # VM settings
    local vm_name=$(cat $1 | yq -r .vm.name)
    local cpu=$(cat $1 | yq -r .vm.cpu)
    local memory=$(cat $1 | yq -r .vm.memory)
    local disk_size=$(cat $1 | yq -r .vm.diskSize)
    local network=$(cat $1 | yq -r .vm.network)
    # OS settings
    local os_version=$(cat $1 | yq -r .os.version)
    local disk_image=$(cat $1 | yq -r .os.diskImage)
    local host_name=$(cat $1 | yq -r .os.hostName)
    local domain_name=$(cat $1 | yq -r .os.domainName)
    # User settings
    local full_name=$(cat $1 | yq -r .user.fullName)
    local username=$(cat $1 | yq -r .user.userName)

    if [[ -z $connection ]] || [[ -z $vm_name ]] || [[ -z $cpu ]] || [[ -z $memory ]] || [[ -z $disk_size ]] || [[ -z $network ]] || [[ -z $os_version ]] || [[ -z $disk_image ]] || [[ -z $host_name ]] || [[ -z $domain_name ]] || [[ -z $full_name ]] || [[ -z $username ]]; then
        catch "${LINENO}: Variable not set."
    fi

    create_vm
    cleanup
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
trap 'catch ${LINENO}.' ERR
main $1
