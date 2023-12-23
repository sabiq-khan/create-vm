#!/bin/bash

set -o pipefail
set -o errtrace

log(){
    echo "[$(date -Iseconds)] ${1}"
}

catch(){
    log "ERROR: An error occurred on line ${1}" 1>&2
    exit 1
}

help(){
    echo -e "\nUSAGE: ./create-vm.sh [yaml_file_with_parameters]\n"
    echo -e "Creates a Debian VM with the parameters in the provided YAML file.\n"
    echo "ARGUMENTS:"
    echo -e "Accepts a single argument, the path to a YAML file with the following structure:\n"
    echo "# Example YAML file"
    echo "vm:"
    echo -e "  name: debian           # VM name"
    echo -e "  cpu: 2                 # CPU allocation in vCPUs"
    echo -e "  memory: 2048           # Memory allocation in MiB"
    echo -e "  diskSize: 20           # Virtual disk size in GB"
    echo "os:"
    echo -e "  version: debian12      # Debian version"
    echo -e "  diskImage: /var/lib/libvirt/images/debian-12.4.0-amd64-netinst.iso  # Path to disk image"
    echo -e "  hostName: debian       # VM host name"
    echo -e "  domainName: debian     # VM domain name"
    echo "user:"
    echo -e "  fullName: debian-user  # Debian user full name (does not have to be a real name)"
    echo -e "  userName: debian-user  # Debian username"
    echo -e "\nIf no argument is passed, this help message is printed."
}

create_preseed(){
    cat preseed-template.cfg | sed -e "s|\$HOST_NAME|${host_name}|g" -e "s|\$DOMAIN_NAME|${domain_name}|g" -e "s|\$FULL_NAME|${full_name}|g" -e "s|\$USERNAME|${username}|g" -e "s|\$PASSWORD|${password}|g" > preseed.cfg
    log "'preseed.cfg' created!"
}

create_vm(){
    log "Creating Debian user password..."
    local password=$(pwgen -1)

    log "Creating Debian preseed..."
    create_preseed

    log "Creating VM ${vm_name}..."
    virt-install \
    --virt-type kvm \
    --name $vm_name  \
    --os-variant debian12 \
    --location $disk_image \
    --disk size=${disk_size} \
    --vcpus $cpu \
    --cpu host-passthrough \
    --ram $memory \
    --graphics none \
    --network bridge=virbr0,model=virtio \
    --initrd-inject=preseed.cfg \
    --extra-args='console=tty0 console=ttyS0,115200n8 serial' \
    --noreboot

    log "Checking state of VM ${vm_name}..."
    virsh dominfo $vm_name
    if [[ $? -eq 1 ]]; then
        catch "${LINENO}: Creation of VM $vm_name failed."
    fi

    log "VM $vm_name successfully created!"
    log "VM name: ${vm_name}"
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
    local vm_name=$(cat $1 | yq -r .vm.name)
    local cpu=$(cat $1 | yq -r .vm.cpu)
    local memory=$(cat $1 | yq -r .vm.memory)
    local disk_size=$(cat $1 | yq -r .vm.diskSize)
    local debian_version=$(cat $1 | yq -r .os.version)
    local disk_image=$(cat $1 | yq -r .os.diskImage)
    local host_name=$(cat $1 | yq -r .os.hostName)
    local domain_name=$(cat $1 | yq -r .os.domainName)
    local full_name=$(cat $1 | yq -r .user.fullName)
    local username=$(cat $1 | yq -r .user.userName)

    if [[ -z $vm_name ]] || [[ -z $cpu ]] || [[ -z $memory ]] || [[ -z $disk_size ]] || [[ -z $debian_version ]] || [[ -z $disk_image ]] || [[ -z $host_name ]] || [[ -z $domain_name ]] || [[ -z $full_name ]] || [[ -z $username ]]; then
        catch "${LINENO}: Variable not set."
    fi

    create_vm
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
trap 'catch ${LINENO}.' ERR
main $1
