# How to deploy

1. Prepare your customized values file like the following:

    ```shell
    cat <<EOF > myvals.yaml
    clusterName: mycluster
    openstack:
      username: demo
      password: password
      projectID: b83c654b664042818707291acff230df
      authURL: http://10.52.0.6/identity/v3
      region: RegionOne
      lbSubnetID: 100a129c-8f53-47fa-adf8-9f04849cb00b
      lbFipNetwork: a5d4e91c-7982-4b0a-8122-ffb3b38af42a
    EOF
    ```

2. Install the chart using helm CLI.

    ```shell
    helm install --name os-ingress-controller \
        -f myvals.yaml \
        https://github.com/lingxiankong/kubernetes-study/releases/download/v0.2.0/openstack-ingress-controller-0.2.0.tgz
    ```