
# kubeadm
This formula wraps kubeadm in order to manage k8s clusters.
* **note**: This formula is experimental, so use it cautiously.
* It's been tested with CentOS 7 and Ubuntu 16.04 (Xenial).

## Setup
* Add the following to your Salt master's config:
```
file_roots:
  base:
    - /PATH/TO/FORMULA/kubeadm/files/custom/

reactor:
  - 'kubeadm/output':
    - /PATH/TO/FORMULA/kubeadm/react/kubeadm_output.sls
```
* Generate and place a Fernet encryption key in pillar for your cluster
  * This should be unique for each cluster
  * It's a secret value, so it should be encrypted in pillar
```
dd if=/dev/urandom bs=32 count=1 2>/dev/null | base64 | gpg -ear YOUR PILLAR GPG KEY HERE
```

## Usage
Different cluster settings are specified in pillar (see example below).
### Primary Control Node
This is a control node the formula uses to initialize the cluster, apply addon manifests, drain, and uncordon nodes.
### Initializing a Cluster
1. Configure the cluster settings in each nodes' pillar.
2. Execute a highstate on all nodes.
3. Run the initialize orchestrator from the salt master
```
salt-run -l info state.orchestrate kubeadm.orch.initialize pillar='{"cluster_name": "SOME CLUSTER HERE"}'
```
### Joining Additional Nodes
**Note**: This will work for both control and worker nodes.
1. Configure the cluster settings in each new nodes' pillar.
2. Execute a highstate on all new nodes.
3. Run the join_nodes orchestrator from the salt master.
```
salt-run -l info state.orchestrate kubeadm.orch.join_nodes pillar='{"cluster_name": "SOME CLUSTER HERE"}'
```
### Upgrading a Cluster
**Note**: This process may change with newer versions of K8s, always check the [upgrade process](https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/)/ release notes before running it.
1. Update the cluster_version in each nodes' pillar.
2. Refresh each nodes' pillar.
3. Run the upgrade orchestrator from the salt master.
```
salt-run -l info state.orchestrate kubeadm.orch.upgrade pillar='{"cluster_name": "SOME CLUSTER HERE"}'
```
### Container Runtime
* containerd is installed as the default runtime, it can be replaced by updating the states in runtime/ 
### K8s API HA
* Keepalived is used to provide an HA VIP for the cluster API.  If it's disabled you'll need to provide your own API VIP.
### CNI
* Calico is inistalled as the cluster CNI via the addons/ states.
### Addons
* K8s manifests can be added to all clusters by adding them to files/addons/default
* Cluster specific manifests can be added to files/addons/CLUSTER NAME
* Addons that require orchestration can be added as addtional sls files under addons/.  For example, [metallb](https://metallb.universe.tf/installation/) requires you to create a secret when first installing it.
  * **note**: these should be idempotent.
* Addons are added everytime the kubeadm formula is applied to the primary controller.
### Running kubectl Commands
kubectl commands can be executed from the salt master:
```
salt 'CONTROL NODE HERE' cmd.run env='{"KUBECONFIG": "/etc/kubernetes/admin.conf"}' cmd='kubectl get nodes' 
```

## Pillar Example
```yaml
# Primary Control Node
kubeadm:
  join_info_encrypt_key: |
    Some Fernet key here ...
  v: 5 # The verbosity level for kubeadm -v=
  cluster_name: example_cluster1
  primary: True 
  control: True  
  advertise_address: {{ grains['fqdn_ip4'][0] }} # This seems to be used to determine the advertised etcd address along with the control node's API server address
  control_endpoint_ip: 192.168.1.10 #  The VIP address the API server is load balanced from
  control_endpoint_port: 6443 
  control_endpoint_cidr: 24
  keepalived_config:
    interface: enp0s3 
    pass: SOME PASSWORD
    priority: 101 # This decides which of the control nodes will hold the VIP, higher increases priority

# Control Node
kubeadm:
  join_info_encrypt_key: |
    Some Fernet key here ...
  v: 5 # The verbosity level for kubeadm -v=
  cluster_name: example_cluster1
  control: True
  advertise_address: {{ grains['fqdn_ip4'][0] }}
  control_endpoint_ip: 192.168.1.10
  control_endpoint_port: 6443
  control_endpoint_cidr: 24
  keepalived_config:
    interface: enp0s3
    pass: SOME PASSWORD

# Worker Node
kubeadm:
  join_info_encrypt_key: |
    Some Fernet key here ...
  v: 5 # The verbosity level for kubeadm -v=
  cluster_name: example_cluster1
  control_endpoint_ip: 192.168.1.10
  control_endpoint_port: 6443
```

## Security Considerations
* Join info (cluster CA hash, join token, CA cert encryption key) is passed between nodes via Salt mine.  There are a few things done to protect it:
  * They're only allowed to be accessed by other members of the cluster via [minion side access control](https://docs.saltstack.com/en/latest/topics/mine/index.html#minion-side-access-control).
  * They're encrypted using [Fernet](https://cryptography.io/en/latest/fernet/)
  * They're removed from Salt mine once the orchestration they're used in is finished.
* Salt debug logging can expose secrets in the minion's logs:
  * kubeadm's output: --token and --certificate-key 

## Troubleshooting
* If the reactor is configured, the master will log the output of kubeadm at "info" level as the command runs.
  * It can be filtered using grep:
```
sudo journalctl -fu salt-master | grep 'kubeadm output - kube-poc0-ctrl0'
...
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: Your Kubernetes control-plane has initialized successfully!
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: To start using your cluster, you need to run the following as a regular user:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:   mkdir -p $HOME/.kube
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:   sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:   sudo chown $(id -u):$(id -g) $HOME/.kube/config
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: You should now deploy a pod network to the cluster.
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:   https://kubernetes.io/docs/concepts/cluster-administration/addons/
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: You can now join any number of the control-plane node running the following command on each as root:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:   kubeadm join 192.168.1.10:6443 --token <value withheld> \
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:     --discovery-token-ca-cert-hash sha256:94de1a8bb10212799f517753839280cd04b57ebfbca24e3f19e94e53f1ffbbd5 \
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:     --control-plane --certificate-key <value withheld>
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: Please note that the certificate-key gives access to cluster sensitive data, keep it secret!
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: As a safeguard, uploaded-certs will be deleted in two hours; If necessary, you can use
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: "kubeadm init phase upload-certs --upload-certs" to reload certs afterward.
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:
Sep 06 12:50:35 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: Then you can join any number of worker nodes by running the following on each as root:
Sep 06 12:50:36 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:
Sep 06 12:50:36 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net: kubeadm join 192.168.1.10:6443 --token <value withheld> \
Sep 06 12:50:36 sm salt-master[10628]: [INFO ] kubeadm output - kube-poc0-ctrl0.example.net:     --discovery-token-ca-cert-hash sha256:94de1a8bb10212799f517753839280cd04b57ebfbca24e3f19e94e53f1ffbbd5
```
* Debug level logging on the minion will log the exact kubeadm command that was executed:
  * **Note**: This will display --token and --certificate-key secrets, keep that in mind if you're centrally logging.
```
sudo journalctl -u salt-minion --no-pager | grep 'kubeadm executing'
Sep 06 12:54:24 kube-poc0-wkr0 salt-minion[10836]: [DEBUG   ] kubeadm executing: kubeadm join 192.168.1.10:6443 --v=5 --token=aaaaaa.bbbbbbbbbbbbbb --discovery-token-ca-cert-hash=sha256:94de1a8bb10212799f517753839280cd04b57ebfbca24e3f19e94e53f1ffbbd5
```

