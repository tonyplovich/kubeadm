{%- set cluster_name = salt['pillar.get']('cluster_name') %}
{%- set primary_controller = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and I@kubeadm:primary:True'.format(cluster_name), 'compound'])[0] %}
{%- set controllers = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and I@kubeadm:control:True and not I@kubeadm:primary:True'.format(cluster_name), 'compound']) %}
{%- set workers = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and not I@kubeadm:control:True'.format(cluster_name), 'compound']) %}

Create Join Info:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.create_join_info
    - arg:
      - {{ cluster_name }}

# Join the other control nodes, one at a time.
# Doing more than one at a time has caused issues with etcd starting up.
{%- for controller in controllers %}
Join Control Node {{ controller}}:
  salt.state:
    - tgt: {{ controller }}
    - timeout: 120
    - pillar:
        primary_controller: {{ primary_controller }}
    - sls:
      - kubeadm.install.kubectl
      - kubeadm.install.kubelet
      - kubeadm.install.kubeadm
      - kubeadm.cluster
    - require:
      - salt: Create Join Info
{%- endfor %}

{%- if workers %}
Join Worker Nodes:
  salt.state:
    - tgt: {{ workers |tojson }}
    - timeout: 120
    - tgt_type: list
    - pillar:
        primary_controller: {{ primary_controller }}
    - sls:
      - kubeadm.install.kubectl
      - kubeadm.install.kubelet
      - kubeadm.install.kubeadm
      - kubeadm.cluster
    - require:
      - salt: Create Join Info
{%- for controller in controllers %}
      - salt: Join Control Node {{ controller }}
{%- endfor %}
{%- endif %}

Clean Up Join Info:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.remove_join_info
    - arg:
      - {{ pillar['cluster_name'] }}
