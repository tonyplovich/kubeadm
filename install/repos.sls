{%- from "kubeadm/map.jinja" import kubeadm with context %}

{%- if grains.get('os_family', '') == 'RedHat' %}
kubernetes:
  pkgrepo.managed:
    - humanname: kubernetes
    - baseurl: https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
    - gpgcheck: 1
    - enabled: 1
    - gpgkey: https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
{%- endif %}

{%- if grains.get('os', '') == 'Ubuntu' %}
kubernetes:
  pkgrepo.managed:
    - name: 'deb https://apt.kubernetes.io/ kubernetes-{{ grains['oscodename']  }} main'
    - enabled: 1
    - key_url: https://packages.cloud.google.com/apt/doc/apt-key.gpg
{%- endif %}

# Repo currently available for these distributions
# kubernetes-jessie
# kubernetes-lucid
# kubernetes-precise
# kubernetes-squeeze
# kubernetes-stretch
# kubernetes-trusty
# kubernetes-wheezy
# kubernetes-xenial
# kubernetes-yakkety

