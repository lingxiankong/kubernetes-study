# Create k8s cluster using Ansible on top of OpenStack

This script can only create kubernetes cluster including 1 master and multiple nodes. Kubernetes cluster will use OpenStack as cloud provider.

## How to run
### Prepare your local environment
```shell
mkvirtualenv test_k8s
pip install ansible shade
```

### Install
Take a look at the variables in `site.yml` file, you need to define your own as needed or pass those as ansible-playbook vars. Here is an script example that I used in my devstack environment.

```bash
echo 'alias source_adm="source ~/devstack/openrc admin admin"' >> ~/.bashrc
echo 'alias source_demo="source ~/devstack/openrc demo demo"' >> ~/.bashrc
echo 'alias source_altdemo="source ~/devstack/openrc alt_demo alt_demo"' >> ~/.bashrc
echo 'alias os="openstack"' >> ~/.bashrc
echo 'alias lb="openstack loadbalancer"' >> ~/.bashrc
echo 'export PYTHONWARNINGS="ignore"' >> ~/.bashrc
sed -i "/alias ll/c alias ll='ls -l'" ~/.bashrc
cat <<'EOF' >> ~/.bashrc
export PS1='\[\033[1;34m\]\u@\h [\w]\[\033[00m\]\n\[\033[01;31m\]$\[\033[00m\] '
EOF
source ~/.bashrc

cd ~
cat << EOF > pre.sh
set -e
pushd ~/devstack
# create a new flavor
source openrc admin admin
openstack flavor create --id 6 --ram 2048 --disk 7 --vcpus 1 --public k8s
# create keypair
source openrc demo demo
ssh-keygen -t rsa -b 4096 -N "" -f ~/.ssh/id_rsa
openstack keypair create --public-key ~/.ssh/id_rsa.pub testkey
# set up the security group rules
openstack security group rule create --proto icmp default
openstack security group rule create --protocol tcp --dst-port 1:65535 default
# register ubuntu image
source openrc admin admin
curl -SOL http://cloud-images.ubuntu.com/xenial/current/xenial-server-cloudimg-amd64-disk1.img
glance image-create --name ubuntu-xenial \
            --visibility public \
            --container-format bare \
            --disk-format qcow2 \
            --file xenial-server-cloudimg-amd64-disk1.img
rm -f xenial-server-cloudimg-amd64-disk1.img
# modify quota
openstack quota set --instances 100 --cores 50 --secgroups 100 --secgroup-rules 500 demo
# update ansible and install shade
sudo apt-add-repository ppa:ansible/ansible -y && sudo apt-get update -y && sudo apt-get install -y ansible && sudo pip install shade
popd
EOF

bash pre.sh

git clone https://github.com/lingxiankong/kubernetes_study.git
pushd ~/kubernetes_study/installation/ansible/version_3/
pushd ~/devstack && source openrc demo demo && popd
image=$(openstack image list --name ubuntu-xenial -c ID -f value)
network=$(openstack network list --name private -c ID -f value)
subnet_id=$(openstack subnet list --network private --name private-subnet -c ID -f value)
auth_url=$(export | grep OS_AUTH_URL | awk -F '"' '{print $2}')
pushd ~/devstack && source openrc admin admin && popd
user_id=$(openstack user show demo -c id -f value)
tenant_id=$(openstack project show demo -c id -f value)
cat << EOF > roles/kube_master/defaults/main.yml
auth_url: $auth_url
user_id: $user_id
password: password
tenant_id: $tenant_id
region: RegionOne
subnet_id: $subnet_id
EOF
cp roles/kube_master/defaults/main.yml roles/kube_node/defaults/main.yml

pushd ~/devstack && source openrc demo demo && popd
ansible-playbook site.yml -e "rebuild=false flavor=6 image=$image network=$network key_name=testkey private_key=/home/ubuntu/.ssh/id_rsa node_prefix=test"
popd
```

If anything unexpected happened during the installation, just re-run using:
```shell
ansible-playbook site.yml -e "rebuild=true"
```

## Destroy

- Delete the instances
- Disassociate/delete allocated floatingips if needed
- Delete ports after instances deletion, using `neutron port-list -- --device-id <vm_id>` to get port attached to the instance.
