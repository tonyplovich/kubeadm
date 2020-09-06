{% from "kubeadm/map.jinja" import kubeadm with context %}

# RHEL
{%- if grains.get('os_family', '') == 'RedHat' %}
  {%- if grains.get('osmajorrelease', '') == 7 %}
python2-cryptography:
  pkg.installed
  {%- endif %}
{%- endif %}

# Ubuntu
