# Create k8s cluster using Ansible on top of OpenStack

This script can only create kubernetes cluster including 1 master and multiple
nodes.

## How to run
First, you need to download all the ansible scripts here, then do the
following:

```shell
mkvirtualenv test_k8s
pip install ansible shade
source <your-openrc-file>
```

Take a look at the variables in `deploy_k8s.yml` file, you need to define your
own as needed or pass those as ansible-playbook vars.

```shell
ansible-playbook deploy_k8s.yml -e "rebuild=false"
```

If anything unexpected happened during the installation, just re-run using:
```shell
ansible-playbook deploy_k8s.yml -e "rebuild=true"
```
