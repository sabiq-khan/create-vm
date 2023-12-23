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
    echo -e "\tAccepts a single argument, the path to a YAML file with the following structure.\n"
    echo -e "\t# Example YAML file"
    echo -e "\tvm:"
    echo -e "\t  name:\t\t# VM name"
    echo -e "\t  hostName:\t# VM host name"
    echo -e "\t  domainName:\t# VM domain name"
    echo -e "\tuser:"
    echo -e "\t  firstName:\t# First name of user"
    echo -e "\t  lastName:\t# Last name of user"
    echo -e "\t  userName:\t# Debian username\n"
    echo -e "\tIf no argument is passed, this help message is printed."
}

create_preseed(){
    cat preseed-template.cfg | sed -e "s|\$HOST_NAME|${host_name}|g" -e "s|\$DOMAIN_NAME|${domain_name}|g" -e "s|\$FIRST_NAME|${first_name}|g" -e "s|\$LAST_NAME|${last_name}|g" -e "s|\$USERNAME|${username}|g" -e "s|\$PASSWORD|${password}|g" > preseed.cfg
}

create_vm(){
    local password=$(pwgen -1)

    create_preseed

    virt-install \
    --virt-type kvm \
    --name $vm_name  \
    --os-variant debian12 \
    --location /var/lib/libvirt/images/debian-12.4.0-amd64-netinst.iso \
    --disk size=20 \
    --vcpus 2 \
    --cpu host-passthrough \
    --ram 2048 \
    --graphics none \
    --network bridge=virbr0,model=virtio \
    --initrd-inject=preseed.cfg \
    --extra-args='console=tty0 console=ttyS0,115200n8 serial' \
    --noreboot

    log "Checking $vm_name VM state..."
    virsh dominfo $vm_name
    if [[ $? -eq 1 ]]; then
        catch "${LINENO}: Creation of VM $vm_name failed."
    fi

    log "VM successfully created!"
    log "VM name: ${vm_name}"
    log "VM password: ${password}"
    log "Use 'virsh' or 'virt-manager' to see more information."
}

main(){
    if [[ -z $1 ]]; then
        help
        exit
    elif ! [[ -f $1 ]]; then
        catch "${LINENO}: File '${1}' not found.$(help)"
    fi 
    
    local vm_name=$(cat $1 | yq -r .vm.name)
    local host_name=$(cat $1 | yq -r .vm.hostName)
    local domain_name=$(cat $1 | yq -r .vm.domainName)
    local first_name=$(cat $1 | yq -r .user.firstName)
    local last_name=$(cat $1 | yq -r .user.lastName)
    local username=$(cat $1 | yq -r .user.userName)

    if [[ -z $vm_name ]] || [[ -z $host_name ]] || [[ -z $domain_name ]] || [[ -z $first_name ]] || [[ -z $last_name ]] || [[ -z $username ]]; then
        catch "${LINENO}: Variable not set."
    fi

    create_vm
}

# =============================================================================
# ENTRYPOINT
# =============================================================================
trap 'catch ${LINENO}.' ERR
main $1
