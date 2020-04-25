{% from "kubeadm/map.jinja" import kubeadm with context %}

Install kubelet:
  pkg.installed:
    - name: kubelet
    - version: {{ kubeadm.version | quote }}
    - hold: True
    - update_holds: True

kubelet:
  service.running:
    - enable: True
    - watch:
      - pkg: Install kubelet
