{% from "kubeadm/map.jinja" import kubeadm with context %}

# RHEL
{%- if grains.get('os_family', '') == 'RedHat' %}
epel-release:
  pkg.installed
    - require:
      - pkg: yum-plugin-versionlock

python3-pip
  pkg.installed

python2-pip
  pkg.installed:
    - require:
      - pkg: epel-release

python-gnupg:
  pip.installed:
    - bin_env: /usr/bin/pip3
    - require:
      - pkg: Supporting packages

python2-gnupg:
  pip.installed:
    - name: python-gnupg
    - bin_env: /usr/bin/pip
    - require:
      - pkg: Supporting packages
{%- endif %}

# Ubuntu
