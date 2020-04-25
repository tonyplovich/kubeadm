{% from "kubeadm/map.jinja" import kubeadm with context %}

include:
  - .repos
  - .versionlock
{%- if kubeadm.encrypt_join_info %}
  - .python-gnupg.sls
{%- endif %}
{%- if kubeadm.control and kubeadm.keepalived %}
  - .keepalived
{%- endif %}
