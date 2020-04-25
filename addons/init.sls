{% from "kubeadm/map.jinja" import kubeadm with context %}

# Create a state file if your addon requires extra orchestration, it should be idemnpotent
include:
  - .metallb

# place default addons in here
/etc/kubernetes/salt-addons/default:
  file.recurse:
    - user: root
    - group: root
    - dir_mode: 750
    - file_mode: 640
    - source: salt://kubeadm/files/addons/default

kubectl apply -f /etc/kubernetes/salt-addons/default:
  cmd.run:
    - onchanges:
      - file: /etc/kubernetes/salt-addons/default
    - env:
      - KUBECONFIG: '/etc/kubernetes/admin.conf'

# place cluster specific static addons in files/addons/CLUSTER NAME
{%- if salt['cp.list_master_dirs']( prefix='kubeadm/files/addons/{0}'.format(kubeadm.cluster_name)) %}
/etc/kubernetes/salt-addons/{{ kubeadm.cluster_name }}:
  file.recurse:
    - user: root
    - group: root
    - dir_mode: 750
    - file_mode: 640
    - source: salt://kubeadm/files/addons/{{ kubeadm.cluster_name }}

kubectl apply -f /etc/kubernetes/salt-addons/{{ kubeadm.cluster_name }}:
  cmd.run:
    - onchanges:
      - file: /etc/kubernetes/salt-addons/{{ kubeadm.cluster_name }}
    - env:
      - KUBECONFIG: '/etc/kubernetes/admin.conf'
{%- endif %}
