import logging

log = logging.getLogger(__name__)

def log_output(minion, output):
    log.warning('kubeadm output - {}: {}'.format(minion, output))
