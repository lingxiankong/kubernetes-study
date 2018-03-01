# Create k8s cluster using Ansible on top of OpenStack

This script can only create kubernetes cluster including 1 master and multiple nodes. Version 2 playbook doesn't take openstack as k8s cloud provider, if you need integration with openstack, please refer to version 3.

## How to run
### Prepare your local environment
```shell
mkvirtualenv test_k8s
pip install ansible shade
```

### Install
Take a look at the variables in `site.yml` file, you need to define your own as needed or pass those as ansible-playbook vars. 

```bash
source openrc
ansible-playbook site.yml -e "rebuild=false image=$image flavor=$flavor"
```

If anything unexpected happened during the installation, just re-run using:
```shell
ansible-playbook site.yml -e "rebuild=true"
```

## Destroy

- Delete the instances
- Delete ports after instances deletion, using `neutron port-list -- --device-id <vm_id>` to get port attached to the instance.
