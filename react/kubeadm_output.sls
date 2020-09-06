log_output:
  runner.kubeadm.log_output:
    - args:
      - minion: {{ data['id'] }}
      - output: {{ data['data']['output']|tojson }}
