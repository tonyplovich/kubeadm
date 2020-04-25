{% from "kubeadm/map.jinja" import kubeadm with context %}

Install kubectl:
  pkg.installed:
    - name: kubectl
    - version: {{ kubeadm.version | quote }}
    - hold: True
    - update_holds: True
