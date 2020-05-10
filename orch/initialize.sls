{%- set cluster_name = salt['pillar.get']('cluster_name') %}
{%- set primary_controller = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and I@kubeadm:primary:True'.format(cluster_name), 'compound'])[0] %}
{%- set controllers = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and I@kubeadm:control:True and not I@kubeadm:primary:True'.format(cluster_name), 'compound']) %}
{%- set workers = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and not I@kubeadm:control:True'.format(cluster_name), 'compound']) %}

Initialize Cluster:
  salt.state:
    - tgt: {{ primary_controller }}
    - pillar:
        primary_controller: {{ primary_controller }}
    - sls:
      - kubeadm.install.kubectl
      - kubeadm.install.kubelet
      - kubeadm.install.kubeadm
      - kubeadm.cluster

# Join the other control nodes, one at a time.  
# Doing more than one at a time has caused issues with etcd starting up.
{%- for controller in controllers %}
Join Control Node {{ controller}}:
  salt.state:
    - tgt: {{ controller }}
    - pillar:
        primary_controller: {{ primary_controller }}
    - sls:
      - kubeadm.install.kubectl
      - kubeadm.install.kubelet
      - kubeadm.install.kubeadm
      - kubeadm.cluster
    - require:
      - salt: Initialize Cluster
{%- endfor %}

{%- if workers %}
Join Worker Nodes:
  salt.state:
    - tgt: {{ workers |tojson }}
    - tgt_type: list
    - pillar:
        primary_controller: {{ primary_controller }}
    - sls:
      - kubeadm.install.kubectl
      - kubeadm.install.kubelet
      - kubeadm.install.kubeadm
      - kubeadm.cluster
    - require:
      - salt: Initialize Cluster
{%- for controller in controllers %}
      - salt: Join Control Node {{ controller }}
{%- endfor %}
{%- endif %}

Apply Addons:
  salt.state:
    - tgt: {{ primary_controller }}
    - sls:
      - kubeadm.addons
    - require:
{%- for controller in controllers %}
      - salt: Join Control Node {{ controller }}
{%- endfor %}
{%- if workers %}
      - salt: Join Worker Nodes
{%- endif %}

Clean Up Join Info:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.remove_join_info
    - arg:
      - {{ pillar['cluster_name'] }}
