# kubeadm
This formula wraps kubeadm in order to manage k8s clusters.
* **note**: This formula is experimental, so use it cautiously.
* It's been tested with CentOS 7 and Ubuntu 16.04 (Xenial).

## Setup
Add the following to your Salt master's config:
```
file_roots:
  base:
    - /PATH/TO/FORMULA/kubeadm/files/custom/
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
**Note**: This process may change with newer versions of K8s, always check the upgrade process/ release notes before running it.
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
### Running kubectl Commands
kubectl commands can be executed from the salt master:
```
salt 'CONTROL NODE HERE' cmd.run env='{"KUBECONFIG": "/etc/kubernetes/admin.conf"}' cmd='kubectl get nodes' 
```

## Pillar Example
```yaml
# Primary Control Node
kubeadm:
  cluster_name: example_cluster1
  primary: True 
  control: True  
  advertise_address: {{ grains['fqdn_ip4'][0] }} # The address kubeadm uses to host etcd
  control_endpoint_ip: 192.168.1.254 #  The address the API server will listen on
  control_endpoint_port: 6443 
  control_endpoint_cidr: 24
  keepalived_config:
    interface: enp0s3 
    pass: SOME PASSWORD
    priority: 101 # This decides which of the control nodes will hold the VIP, higher increases priority

# Control Node
kubeadm:
  cluster_name: example_cluster1
  control: True
  advertise_address: {{ grains['fqdn_ip4'][0] }}
  control_endpoint_ip: 192.168.1.254
  control_endpoint_port: 6443
  control_endpoint_cidr: 24
  keepalived_config:
    interface: enp0s3
    pass: SOME PASSWORD

# Worker Node
kubeadm:
  cluster_name: example_cluster1
  control_endpoint_ip: 192.168.1.6443
  control_endpoint_port: 6443
```

## Security Considerations
* Join info (cluster CA hash, join token, CA cert encryption key) is passed between nodes via Salt mine.  There are a few things done to protect it:
  * They're only allowed to be accessed by other members of the cluster via [minion side access control](https://docs.saltstack.com/en/latest/topics/mine/index.html#minion-side-access-control).
  * They're removed from Salt mine once the orchestration they're used in is finished.
* Debug logging can expose secrets:
  * kubeadm's output (join secrets)

## Troubleshooting
* Set logging to debug on the cluster minions to see the output of kubeadm
  * **note**: The messages are prefixed with 'kubeadm' but some entries span multiple lines. This means you might miss some output by grepping for kubeadm.
