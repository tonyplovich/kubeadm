{% from "kubeadm/map.jinja" import kubeadm with context %}

{%- if grains.get('os_family', '') == 'RedHat' %}
yum-plugin-versionlock:
  pkg.installed
{%- endif %}
