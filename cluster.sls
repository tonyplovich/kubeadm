{% from "kubeadm/map.jinja" import kubeadm with context %}

# Initialize cluster ... 
{%- if kubeadm.primary %}
{{ kubeadm.cluster_name }}:
  kubeadm.initialized:
    - advertise_address: {{ kubeadm.advertise_address }}
    - control_endpoint: {{ kubeadm.control_endpoint_ip }}:{{ kubeadm.control_endpoint_port }}
    - service_cidr: {{ kubeadm.service_cidr }} 
    - pod_network: {{ kubeadm.pod_network }} 
    - v: {{ kubeadm.v }}
#    - retry:
#        attempts: 2

{%- else %}

# ... and join control / worker nodes to it
{{ kubeadm.cluster_name }}:
  kubeadm.joined:
    {%- if kubeadm.control %}
    - advertise_address: {{ kubeadm.advertise_address }}
    {%- endif %}
    - control: {{ kubeadm.control }}
    - primary_controller: {{ pillar.get('primary_controller', "") }}
    - control_endpoint: {{ kubeadm.control_endpoint_ip }}:{{ kubeadm.control_endpoint_port }}
    - v: {{ kubeadm.v }}
#    - retry:
#        attempts: 2

{%- endif %}
