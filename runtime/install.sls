{% from "kubeadm/map.jinja" import kubeadm with context %}

{%- if grains.get('os_family', '') == 'RedHat' %}
container-selinux:
  pkg.installed
{%- endif %}

install_containter_runtime_packages:
  pkg.installed:
    - hold: True
    - update_holds: True
    - pkgs:
      - {{ kubeadm.runtime_pkg }}: {{ kubeadm.runtime_version | quote }}

configure_runtime:
  file.managed:
    - name: /etc/containerd/config.toml
    - user: root
    - group: root
    - mode: 644
    - source: salt:///kubeadm/files/containerd.config.toml

{{ kubeadm.runtime_service }}:
  service.running:
    - enable: True
