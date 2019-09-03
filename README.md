cPoP Proxmox VE post-installation script
===

This script is used in the context of cPoP Proxmox Virtual Environment (PVE) installations.

It should be used afer both PVE ISOs of the cPoP have been installed.

Proxmox is available here (documentation, ISOs...): 
* [Proxmox](https://www.proxmox.com/en/) - Proxmox Virtual Environment

## Requirements

Proxmox should be installed on both servers of the cPoP before launching this script.

Both servers need to have IP connectivity to Pastourelle to retrieve the Proxmox ISO.

Both servers need to have connectivity to each other to take part of the same PVE cluster.

Network informations are needed to configure both servers (IP@, GW, DNS, FQDN...)


## Usage

```bash
./PVE_post_install_config_v6.sh
# This will launch the installation script
```