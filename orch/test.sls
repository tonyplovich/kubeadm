{%- set cluster_name = salt['pillar.get']('cluster_name') %}
{%- set primary_controller = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and I@kubeadm:primary:True'.format(cluster_name), 'compound'])[0] %}
{%- set controllers = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and I@kubeadm:control:True and not I@kubeadm:primary:True'.format(cluster_name), 'compound']) %}
{%- set workers = salt['saltutil.runner']('manage.up', arg=['I@kubeadm:cluster_name:{0} and not I@kubeadm:control:True'.format(cluster_name), 'compound']) %}

Ping Primary Controller:
  salt.function:
    - tgt: {{ primary_controller }}
    - name: test.ping

Ping Controllers:
  salt.function:
    - tgt: {{ controllers |tojson }}
    - tgt_type: list
    - name: test.ping
    - require:
      - salt: Ping Primary Controller

Ping Workers:
  salt.function:
    - tgt: {{ workers |tojson }}
    - tgt_type: list
    - name: test.ping
    - require:
      - salt: Ping Controllers
