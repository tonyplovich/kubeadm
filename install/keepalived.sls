{% from "kubeadm/map.jinja" import kubeadm with context %}

{%- if kubeadm.control and kubeadm.keepalived %}
keepalived:
  pkg.installed

{%- if grains.get('os_family', '') == 'RedHat' %}
# Allow keepalived to run the checkscript, which connects to the kubeapi on a non-standard port (6443 by convention)
keepalived_connect_any:
  selinux.boolean:
    - value: 1
    - persist: True
    - require:
      - pkg: keepalived
{%- endif %}

/opt/keepalived/kubeapi_check.sh:
  file.managed:
    - user: root
    - group: root
    - mode: 755
    - template: jinja
    - makedirs: True
    - context:
        port: {{ kubeadm.control_endpoint_port }}
    - source: salt://kubeadm/files/keepalived/kubeapi_check.sh.jinja

/etc/keepalived/keepalived.conf:
  file.managed:
    - user: root
    - group: root
    - mode: 644
    - source: salt:///kubeadm/files/keepalived/keepalived.conf.jinja
    - template: jinja
    - context:
        config: {{ kubeadm.keepalived_config }}
        config_vip: {{ kubeadm.control_endpoint_ip }}/{{ kubeadm.control_endpoint_cidr }}

keepalived_service:
  service.running:
    - name: keepalived
    - enable: True
    - watch:
      - file: /etc/keepalived/keepalived.conf
{%- endif %}
