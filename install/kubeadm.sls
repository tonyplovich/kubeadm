{% from "kubeadm/map.jinja" import kubeadm with context %}

Install kubeadm:
  pkg.installed:
    - name: kubeadm
    - version: {{ kubeadm.version | quote }}
    - hold: True
    - update_holds: True
