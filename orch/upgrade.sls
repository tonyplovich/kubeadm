{%- set cluster_name = salt['pillar.get']('cluster_name') %}
{%- set primary_controller = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and I@kubeadm:primary:True'.format(cluster_name), 'compound'])[0] %}
{%- set controllers = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and I@kubeadm:control:True and not I@kubeadm:primary:True'.format(cluster_name), 'compound']) %}
{%- set workers = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and not I@kubeadm:control:True'.format(cluster_name), 'compound']) %}

# Upgrade primary controller
Upgrade Primary Control Node Software:
  salt.state:
    - tgt: {{ primary_controller }}
    - sls:
      - kubeadm.install.kubectl
      - kubeadm.install.kubelet
      - kubeadm.install.kubeadm

Drain Primary Control Node:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.drain
    - require:
      - salt: Upgrade Primary Control Node Software
    - retry:
        attempts: 2

Upgrade Primary Control Node:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.upgrade
    - arg:
      - 1.18.1-0
    - kwarg:
      primary: True
    - require:
      - salt: Drain Primary Control Node
    - retry:
        attempts: 2

Uncordon Primary Control Node:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.uncordon
    - require:
      - salt: Upgrade Primary Control Node
    - retry:
        attempts: 2


# Upgrade the other control nodes
{%- for controller in controllers %}
Upgrade Control Node Software {{ controller}}:
  salt.state:
    - tgt: {{ controller }}
    - sls:
      - kubeadm.install.kubectl
      - kubeadm.install.kubelet
      - kubeadm.install.kubeadm

Drain Control Node {{ controller }}:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.drain
    - kwarg:
        node: {{ controller }}
    - require:
      - salt: Upgrade Primary Control Node Software
    - retry:
        attempts: 2

Upgrade Control Node {{ controller }}:
  salt.function:
    - tgt: {{ controller }}
    - name: kubeadm.upgrade
    - require:
      - salt: Drain Control Node {{ controller }}
    - retry:
        attempts: 2

Uncordon Control Node {{ controller}}:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.uncordon
    - kwarg:
        node: {{ controller }}
    - require:
      - salt: Upgrade Control Node {{ controller }}
    - retry:
        attempts: 2
{%- endfor %}

# Upgrade the worker nodes
{%- for worker in workers %}
Upgrade Worker Node Software {{ worker }}:
  salt.state:
    - tgt: {{ worker }}
    - sls:
      - kubeadm.install.kubectl
      - kubeadm.install.kubelet
      - kubeadm.install.kubeadm

Drain Worker Node {{ worker }}:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.drain
    - kwarg:
        node: {{ worker }}
    - require:
      - salt: Upgrade Worker Node Software {{ worker }}
    - retry:
        attempts: 2

Upgrade Worker Node {{ worker }}:
  salt.function:
    - tgt: {{ worker }}
    - name: kubeadm.upgrade
    - require:
      - salt: Drain Worker Node {{ worker }}
    - retry:
        attempts: 2

Uncordon Worker Node {{ worker }}:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: kubeadm.uncordon
    - kwarg:
        node: {{ worker }}
    - require:
      - salt: Upgrade Worker Node {{ worker }}
    - retry:
        attempts: 2
{%- endfor %}
