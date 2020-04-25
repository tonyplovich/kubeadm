{% from "kubeadm/map.jinja" import kubeadm with context %}

# Make the node compliant with K8s requirements
swapoff -av:
  cmd.run:
    - onlyif: 'swapon -s | grep -q Filename'

/etc/fstab:
  file.comment:
    - regex: ^[^#]\S+\s+\S+\s+swap\s+

firewalld:
  service.dead:
    - enable: False

'iptables -F':
  cmd.run:
    - onchanges:
      - service: firewalld

br_netfilter:
  kmod.present:
    - persist: True

net.bridge.bridge-nf-call-ip6tables:
  sysctl.present:
    - value: 1

net.bridge.bridge-nf-call-iptables:
  sysctl.present:
    - value: 1

net.ipv4.ip_forward:
  sysctl.present:
    - value: 1

{%- if kubeadm.control %}
net.ipv4.ip_nonlocal_bind:
  sysctl.present:
    - value: 1
{%- endif %}

