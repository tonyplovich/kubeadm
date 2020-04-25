{%- from "kubeadm/map.jinja" import kubeadm with context %}

{%- if grains.get('os_family', '') == 'RedHat' %}
docker:
  pkgrepo.managed:
    - humanname: docker
    - baseurl: https://download.docker.com/linux/centos/7/x86_64/stable
    - gpgcheck: 1
    - enabled: 1
    - gpgkey: https://download.docker.com/linux/centos/gpg
{%- endif %}

{%- if grains.get('os', '') == 'Ubuntu' %}
docker:
  pkgrepo.managed:
    - name: "deb https://download.docker.com/linux/ubuntu {{ grains['oscodename'] }} stable"
    - enabled: 1
    - key_url: https://download.docker.com/linux/ubuntu/gpg
{%- endif %}

# Currently available for these Ubuntu distros
# artful/
# bionic/
# cosmic/
# disco/
# eoan/
# trusty/
# xenial/
# yakkety/
# zesty/
