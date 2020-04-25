{% from "kubeadm/map.jinja" import kubeadm with context %}

# Create namespace for secret
kubectl create ns metallb-system:
  cmd.run:
    - env:
      - KUBECONFIG: '/etc/kubernetes/admin.conf'
    - unless: kubectl get ns/metallb-system

# Secret created on first run
kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)":
  cmd.run:
    - env:
      - KUBECONFIG: '/etc/kubernetes/admin.conf'
    - unless: kubectl get -n metallb-system secrets/memberlist
    - require:
      - cmd: kubectl create ns metallb-system
