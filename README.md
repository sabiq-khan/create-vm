# VM Creation Script
```
.
├── create-vm.sh
├── preseed-template.cfg
└── values.yaml
```
`create-vm.sh` creates a VM using `libvirt`, `QEMU`, and `KVM`. The script creates a `preseed.cfg` file that automates the installation of Debian on the VM, forgoing the need to manually click through the installation options. 

`preseed-template.cfg` provides a template for the `preseed.cfg` file created during the execution of the script. `values.yaml` is an example of a YAML file that can be passed as an argument to the script. The script reads the parameters passed in the YAML file to substitute placeholder values in `preseed-template.cfg` in order to create the final `preseed.cfg` file. 

Note that the YAML file passed to the script does not need to be named `values.yaml` or located in the same directory. Any YAML file with the following structure can be passed as an argument:
```
# Example YAML file
vm:
  name:       # VM name
  hostName:   # VM host name
  domainName: # VM domain name
user:
  firstName:  # First name of user
  lastName:   # Last name of user
  userName:   # Debian username
```

# Installation
1) Ensure you have `libvirt`, `QEMU`, and `KVM` installed.
- Since this script requires `KVM`, it is intended to be run on a Linux system.
- These packages can be installed on Debian-based distros with the following commands:
    ```
    sudo apt update && sudo apt upgrade
    sudo apt install -y qemu-kvm libvirt-clients libvirt-daemon-system virtinst bridge-utils
    ```
- On RPM-based distros, the following command can be used instead:
    ```
    sudo dnf install @virtualization
    ```
2) Ensure that you have `yq` installed since the script requires it to parse the YAML file. 
- `yq` can be installed with the following command:
    ```
    pip3 install yq
    ```
3) Clone this repo with `git clone https://github.com/sabiq-khan/create-vm.git`.

4) Navigate to to the `create-vm` directory and make the script executable with `chmod u+x create-vm.sh`.

# Usage
If the script is run with no parameters, it prints a help message.
```
$ ./create-vm.sh

USAGE: ./create-vm.sh [yaml_file_with_parameters]

Creates a Debian VM with the parameters in the provided YAML file.

ARGUMENTS:
	Accepts a single argument, the path to a YAML file with the following structure.

	# Example YAML file
	vm:
	  name:		    # VM name
	  hostName:	    # VM host name
	  domainName:	# VM domain name
	user:
	  firstName:	# First name of user
	  lastName:	    # Last name of user
	  userName:	    # Debian username

	If no argument is passed, this help message is printed.
```

To create a VM, fill out the parameters in `values.yaml` or whatever YAML file you choose to pass to the script.
```
$ cat <<-"EOF" > values.yaml
vm:
  name: debian
  hostName: debian
  domainName: debian
user:
  firstName: First
  lastName: Last
  userName: debian-user
EOF
```
Then, run the script and pass the path to the YAML file as an argument:
```
$ ./create-vm.sh values.yaml
Starting install...
Retrieving 'vmlinuz'                                                         |    0 B  00:00:00 ... 
Retrieving 'initrd.gz'                                                       |    0 B  00:00:00 ... 
...
Allocating 'debian.qcow2'                                                    |    0 B  00:00:00 ... 
Creating domain...                                                           |    0 B  00:00:00
...
[2023-12-22T17:53:39-08:00] Checking debian VM state...                     
Id:             -                                                               
Name:           debian          
UUID:           xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx                                            
OS Type:        hvm
State:          shut off
CPU(s):         2
Max memory:     2097152 KiB
Used memory:    2097152 KiB
Persistent:     yes
Autostart:      disable
Managed save:   no
Security model: apparmor
Security DOI:   0

[2023-12-22T17:53:39-08:00] VM successfully created!
[2023-12-22T17:53:39-08:00] VM name: debian
[2023-12-22T17:53:39-08:00] Debian username: debian-user
[2023-12-22T17:53:39-08:00] Debian password: xxxxxxxx
[2023-12-22T17:53:39-08:00] Use 'virsh' or 'virt-manager' to see more information.
```

After the VM is successfully created, the script prints your Debian username and password to the screen. You can then use `virsh` to boot the VM and find its IP and use `ssh` to connect to it.
```
$ virsh start debian
Domain 'debian' started

$ virsh net-dhcp-leases default
 Expiry Time           MAC address         Protocol   IP address          Hostname     Client ID or DUID
-------------------------------------------------------------------------------------------------------------------------------------------------
 2023-12-22 18:54:07   xx:xx:xx:xx:xx:xx   ipv4       xxx.xxx.xxx.xxx/xx   debian xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:Xx:xx

$ ssh debian-user@xxx.xxx.xxx.xxx
The authenticity of host 'xxx.xxx.xxx.xxx (xxx.xxx.xxx.xxx)' can't be established.
ED25519 key fingerprint is SHA256:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx.
This key is not known by any other names
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
Warning: Permanently added 'xxx.xxx.xxx.xxx' (ED25519) to the list of known hosts.
debian-user@xxx.xxx.xxx.xxx's password: 
Linux debian 6.1.0-16-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.67-1 (2023-12-12) x86_64

The programs included with the Debian GNU/Linux system are free software;
the exact distribution terms for each program are described in the
individual files in /usr/share/doc/*/copyright.

Debian GNU/Linux comes with ABSOLUTELY NO WARRANTY, to the extent
permitted by applicable law.
debian-user@debian:~$ uname -a
Linux debian 6.1.0-16-amd64 #1 SMP PREEMPT_DYNAMIC Debian 6.1.67-1 (2023-12-12) x86_64 GNU/Linux
debian-user@debian:~$ exit
logout
Connection to xxx.xxx.xxx.xxx closed.
```