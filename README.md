# VM Creation Script
```
.
├── create-vm.sh
├── preseed.Dockerfile
├── preseed-template.cfg
├── README.md
└── values.yaml
```
[create-vm.sh](./create-vm.sh) creates a headless Debian VM using [libvirt](https://libvirt.org/), [QEMU](https://www.qemu.org/), and [KVM](https://linux-kvm.org/page/Main_Page). The script creates a [preseed.cfg](https://wiki.debian.org/DebianInstaller/Preseed) file that automates the installation of Debian on the VM, forgoing the need to manually click through the installation options. 

[preseed-template.cfg](./preseed-template.cfg) provides a template for the `preseed.cfg` file created during the execution of the script. [values.yaml](./values.yaml) is an example of a YAML file that can be passed as an argument to the script. The script reads the parameters passed in the YAML file to substitute placeholder values in `preseed-template.cfg` in order to create the final `preseed.cfg` file. 

[preseed.Dockerfile](./preseed.Dockerfile) is used to create a web server that serves the `preseed.cfg` file on port 8080 for cases where VMs being created on remote hosts need to be able to access preseed file. 

Note that the YAML file passed to the script does not need to be named `values.yaml` or located in the same directory. Any YAML file with the following structure can be passed as an argument:
```
# Example YAML file

# Host settings
host:
  connection: qemu:///system # Points to local libvirtd
  #connection: qemu+tcp://localhost/system # Points to remote libvirtd on specified host

# VM settings
vm:
  name: debian           # VM name
  cpu: 2                 # CPU allocation in vCPUs
  memory: 2048           # Memory allocation in MiB
  diskSize: 20           # Virtual disk size in GB
  network: default       # 'default' uses libvirt NAT network, otherwise specify name of bridge
  #network: bridge=br0   # Enables bridge networking, bridge must already exist in advance

# OS settings
os:
  version: debian12      # OS version
  diskImage: /var/lib/libvirt/images/debian-12.4.0-amd64-netinst.iso  # Path to disk image
  #diskImage: https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/ # Link to disk image root directory
  hostName: debian       # VM host name
  domainName: debian     # VM domain name

# User settings
user:
  fullName: debian-user  # Linux user full name (does not have to be a real name)
  userName: debian-user  # Linux username

```

# Installation
1) Ensure you have `libvirt`, `QEMU`, and `KVM` installed.
- Since this script requires `KVM`, it is intended to be run on a Linux system.
- These packages can be installed on Debian-based distros with the [following commands](https://ubuntu.com/server/docs/virtualization-libvirt):
    ```
    sudo apt update && sudo apt upgrade
    sudo apt install -y qemu-kvm libvirt-clients libvirt-daemon-system virtinst bridge-utils
    ```
- On RPM-based distros, the [following command](https://docs.fedoraproject.org/en-US/quick-docs/virtualization-getting-started/) can be used instead:
    ```
    sudo dnf install @virtualization
    ```
2) Ensure that you have `yq` installed since the script requires it to parse the YAML file. 
- `yq` can be installed with the [following command](https://pypi.org/project/yq/):
    ```
    pip3 install yq
    ```

3) Ensure that you have [Docker](https://docs.docker.com/desktop/install/linux-install/) installed since the script requires it to create a web server to host the Debian preseed fie for remote installations.
- Docker can be installed on Debian-based distros with the following command:
  ```
  sudo apt install docker.io
  ```
- And on RPM-based distros with the following commands:
  ```
  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
  sudo yum install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  ```

4) Clone this repo by running `git clone https://github.com/sabiq-khan/create-vm.git`.

5) Navigate to to the `create-vm` directory and make the script executable by running `chmod u+x create-vm.sh`.

# Usage
If the script is run with no parameters or with the options `-h` or `--help`, it prints a help message.
```
$ ./create-vm.sh

USAGE: ./create-vm.sh [OPTIONS] [--file FILE]

Creates a Debian VM with the parameters provided via options or YAML file.

ARGUMENTS:

-h, --help, [none]      Prints this help message

--connection            A connection string specifying the libvirtd instance to connect to. 
                        To connect to a local instance of libvirtd, use 'qemu:///system'
                        To connect to libvirtd listening on a TCP socket on another machine, use 'qemu+tcp://domain-name/system'

--vm-name               The desired name for the VM, by which it will be identified in the libvirt back end

--cpu                   The number of vCPUs desired for the VM

--memory                The amount of memory in MiB desired for the VM

--disk-size             The amount of virtual disk space in GB desired for the VM

--network               The networking configuration for the VM
                        To make the VM reachable only by other VMs on the same host, use 'network=default'
                        To make the VM reachable over the LAN, use 'bridge=<bridge-interface-name>'

--os-version            The Debian version to install on the VM, e.g. 'debian12'

--disk-image            The location of the installation medium
                        Specify a file path to a local '.iso' file, e.g. /var/lib/libvirt/images/debian-12.4.0-amd64-netinst.iso
                        OR, specify the URL of a Debian installer, e.g. https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/

--host-name             The host name of the VM, by which it is identified on its own OS

--domain-name           The domain name of the VM, by which it is identified to other devices on its network

--full-name             The full name of the Linux user being created during the Debian installation
                        Does not have to be an actual name, e.g. 'debian-user'

--username              The username of the Linux user being created during the Debian installation, e.g. 'debian-user'

-f, --file              A YAML file containing values for the above parameters

# Example YAML file

# Host settings
host:
  connection: qemu:///system # Points to local libvirtd
  #connection: qemu+tcp://localhost/system # Points to remote libvirtd on specified host

# VM settings
vm:
  name: debian           # VM name
  cpu: 2                 # CPU allocation in vCPUs
  memory: 2048           # Memory allocation in MiB
  diskSize: 20           # Virtual disk size in GB
  network: default       # 'default' uses libvirt NAT network, otherwise specify name of bridge
  #network: bridge=br0   # Enables bridge networking, bridge must already exist in advance

# OS settings
os:
  version: debian12      # OS version
  diskImage: /var/lib/libvirt/images/debian-12.4.0-amd64-netinst.iso  # Path to disk image
  #diskImage: https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/ # Link to disk image root directory
  hostName: debian       # VM host name
  domainName: debian     # VM domain name

# User settings
user:
  fullName: debian-user  # Linux user full name (does not have to be a real name)
  userName: debian-user  # Linux username

```

To create a VM, fill out the parameters in `values.yaml` or whatever YAML file you choose to pass to the script.
```
$ cat <<-"EOF" > values.yaml
# Host settings
host:
  connection: qemu:///system # Points to local libvirtd
  #connection: qemu+tcp://localhost/system # Points to remote libvirtd on specified host

# VM settings
vm:
  name: debian           # VM name
  cpu: 2                 # CPU allocation in vCPUs
  memory: 2048           # Memory allocation in MiB
  diskSize: 20           # Virtual disk size in GB
  network: default       # 'default' uses libvirt NAT network, otherwise specify name of bridge
  #network: bridge=br0   # Enables bridge networking, bridge must already exist in advance

# OS settings
os:
  version: debian12      # OS version
  diskImage: /var/lib/libvirt/images/debian-12.4.0-amd64-netinst.iso  # Path to disk image
  #diskImage: https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/ # Link to disk image root directory
  hostName: debian       # VM host name
  domainName: debian     # VM domain name

# User settings
user:
  fullName: debian-user  # Linux user full name (does not have to be a real name)
  userName: debian-user  # Linux username

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
[2023-12-22T17:53:39-08:00] VM host name: debian
[2023-12-22T17:53:39-08:00] VM domain name: debian
[2023-12-22T17:53:39-08:00] Debian username: debian-user
[2023-12-22T17:53:39-08:00] Debian password: xxxxxxxx
[2023-12-22T17:53:39-08:00] Use 'virsh' or 'virt-manager' to see more information.
```

After the VM is successfully created, the script prints your Debian username and password to the screen. The [preseed file](./preseed-template.cfg#L53) includes a directive to install `sshd` on the VM. Thus, you can use [virsh](https://www.libvirt.org/manpages/virsh.html) to boot the VM and find its IP and then `ssh` into it.
```
$ virsh start debian
Domain 'debian' started

$ virsh net-dhcp-leases default
 Expiry Time           MAC address         Protocol   IP address          Hostname     Client ID or DUID
-------------------------------------------------------------------------------------------------------------------------------------------------
 2023-12-22 18:54:07   xx:xx:xx:xx:xx:xx   ipv4       xxx.xxx.xxx.xxx/xx   debian xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx:xx

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

Note that when creating VMs on remote hosts where `libvirtd` is listening on a TCP socket:
- The `host.connection` field in the YAML file should be set to `qemu+tcp://<dns-name>:<libvirtd-port>/system`
- The `os.diskImage` field should point to a Debian installer URL instead of a local `.iso` file, e.g. https://deb.debian.org/debian/dists/bookworm/main/installer-amd64/
- The script will use Docker to create an nginx web server hosting the preseed file on port 8080 so that the VM can access the preseed file.
- Ensure that the VM will have connectivity to the web server so it can access the preseed file.  
