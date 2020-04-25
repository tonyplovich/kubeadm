{% from "kubeadm/map.jinja" import kubeadm with context %}

include:
  - .compliant
  - .install
  - .runtime
  {%- if kubeadm.primary and salt['kubeadm.is_initialized']() %}
  - .addons
  {%- endif %}
