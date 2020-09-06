{% from "kubeadm/map.jinja" import kubeadm with context %}

include:
  - .repos
  - .versionlock
  - .python-cryptography
{%- if kubeadm.control and kubeadm.keepalived %}
  - .keepalived
{%- endif %}
