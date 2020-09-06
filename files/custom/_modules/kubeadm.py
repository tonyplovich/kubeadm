import os
import subprocess
import logging
import json
try:
    from cryptography.fernet import Fernet
except ImportError:
    pass

log = logging.getLogger(__name__)


def execute_cmd(args):
    
    log.debug('kubeadm executing: {0}'.format(' '.join(args)))

    p = subprocess.Popen(args, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
    while True:
        output = p.stdout.readline()
        if output == '' and p.poll() is not None:
            break
        if output:
            log.info('{} output: {}'.format(args[0], output))
            __salt__['event.send']('kubeadm/output', {'output': output})
    r = p.returncode

    if r == 0:
        return True
    else:
        return False


def reset(v="0"):
    '''
    reset a node to before kubeadm ran on it
  
    Parameters:
      v - kubeadm command verbosity

    Returns:
      True or False based on success
    '''

    args = ["kubeadm"]
    args.append("--v={0}".format(v))
    args.append("reset")
    args.append("--force")
    return execute_cmd(args) 


def drain(node="", v="0"):
    '''
    drain a node to remove running pods
  
    Parameters:
      node - the node to drain

    Returns:
      True or False based on success
    '''

    # __grains__ isn't defined globally, have to place it inside this module
    if not node:
        node = __grains__['id']

    args = ["kubectl"]
    args.append("--v={0}".format(v))
    args.append("drain")
    args.append(node)
    args.append("--ignore-daemonsets")
    args.append("--kubeconfig={0}".format("/etc/kubernetes/admin.conf"))
    return execute_cmd(args) 


def upgrade(version="", primary=False, v="0"):
    '''
    Upgrade a node
  
    Parameters:
      primary - whether this is the primary control node or not

    Returns:
      True or False based on success
    '''
    args = ["kubeadm"]
    args.append("--v={0}".format(v))
    args.append("upgrade")
    if primary:
        args.append("apply")
        args.append(version)
    else:
        args.append("node")    
    return execute_cmd(args) 


def uncordon(node="", v="0"):
    '''
    Uncordon a node
  
    Parameters:
      node - the node to uncordon
  
    Returns:
      True or False based on success
    '''

    # __grains__ isn't defined globally, have to place it inside this module
    if not node:
        node = __grains__['id']

    args = ["kubectl"]
    args.append("--v={0}".format(v))
    args.append("uncordon")
    args.append(node)
    args.append("--kubeconfig={0}".format("/etc/kubernetes/admin.conf"))
    return execute_cmd(args) 


def is_initialized():
    '''
    See if a kubernetes cluster is initalized

    Returns:
      True or False based on success
    '''

    # kubelet.conf doesn't exist until the cluster is created
    # Need a more definitive test
    if os.path.isfile('/etc/kubernetes/kubelet.conf'):
        return True
    else:
        return False


def is_joined():
    '''
    See if a kubernetes node is joined to the cluster

    Returns:
      True or False based on success
    '''

    # kubelet.conf doesn't exist until the node isn't joined
    # Need a more definitive test
    if os.path.isfile('/etc/kubernetes/kubelet.conf'):
        return True
    else:
        return False


def generate_cert_key(v="0"):
    '''
    Generate a certificate key to use with kubeadm init

    Returns:
      The cert key or False based on success
    '''

    args = ["kubeadm", ]
    args.append("--v={0}".format(v))
    args.extend(["alpha", "certs", "certificate-key"])
    log.info('kubeadm.generate_cert_key executing: {0}'.format(' '.join(args)))
    p = subprocess.Popen(args, stdout=subprocess.PIPE)
    cert_key = p.communicate()[0].rstrip().decode("utf-8")
    log.debug('kubeadm.generate_cert_key: cert_key is "{0}"'.format(cert_key))

    r = p.returncode

    if r == 0:
        return cert_key
    else:
        return False


def generate_token(v="0"):
    '''
    Generate a join token to use with kubeadm init

    Returns:
      The token or False based on success
    '''

    args = ["kubeadm"]
    args.append("--v={0}".format(v))
    args.extend(["token", "generate"])
    log.info('kubeadm.generate_token executing: {0}'.format(' '.join(args)))
    p = subprocess.Popen(args, stdout=subprocess.PIPE)
    token = p.communicate()[0].rstrip().decode("utf-8")
    log.debug('kubeadm.generate_token: token is {0}'.format(token))
    r = p.returncode

    if r == 0:
        return token
    else:
        return False


def get_ca_hash():
    '''
    Get the cluster's CA certificate hash

    Returns:
      The CA hash or False based on success
    '''

    # https://kubeadm.io/docs/reference/setup-tools/kubeadm/kubeadm-join/#token-based-discovery-with-ca-pinning
    p = subprocess.Popen("openssl x509 -pubkey -in /etc/kubernetes/pki/ca.crt | openssl rsa -pubin -outform der 2>/dev/null | openssl dgst -sha256 -hex | sed 's/^.* //'", stdout=subprocess.PIPE, shell=True)
    ca_hash = 'sha256:{0}'.format(p.communicate()[0].rstrip().decode("utf-8"))
    log.info('kubeadm.get_ca_hash: ca_hash is "{0}"'.format(ca_hash))
    r = p.returncode

    if r == 0:
        return ca_hash
    else:
        return False


def upload_certs(cert_key, v="0"):
    '''
    Upload the encrypted certs needed to join a control node to the cluster

    Parameters:
      args:
        cert_key - The encryption key to use on certs uploaded for joining control nodes

    Returns:
      True or False based on success
    '''

    args = ["kubeadm"]
    args.append("--v={0}".format(v))
    args.extend(["init", "phase", "upload-certs"])
    args.append("--skip-certificate-key-print")
    args.append("--upload-certs")
    args.append("--certificate-key={0}".format(cert_key))

    log.debug('kubeadm.upload_certs executing: {0}'.format(' '.join(args)))
    p = subprocess.Popen(args, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
    cmd_output = p.communicate()[0].rstrip().decode("utf-8")
    log.debug('kubeadm.upload_certs command output: {0}'.format(cmd_output))
    r = p.returncode

    if r == 0:
        return True
    else:
        return False


def create_token(token, ttl="30m", v="0"):
    '''
    Create a token for joining nodes to a cluster
    
    Parameters:
      args:
        token - can be gotten from kubeadm token generate
      kwargs:
        ttl - the lifetime of the token

    Returns:
      True or False based on success
    '''

    args = ["kubeadm"]
    args.append("--v={0}".format(v))
    args.extend(["token", "create", token])
    args.append("--ttl={0}".format(ttl))

    log.debug('kubeadm.create_token executing: {0}'.format(' '.join(args)))
    p = subprocess.Popen(args, stderr=subprocess.STDOUT, stdout=subprocess.PIPE)
    cmd_output = p.communicate()[0].rstrip().decode("utf-8")
    log.debug('kubeadm.create_token command output: {0}'.format(cmd_output))
    r = p.returncode

    if r == 0:
        return True
    else:
        return False


def upload_join_info(ca_hash, cert_key, cluster_name, token, pillar_encrypt_key="kubeadm:join_info_encrypt_key"):
    '''
    Populate Salt mine with the items needed to join a cluster

    Parameters:
      args:
        ca_hash - The clusters CA certificate hash
        cert_key - The encryption key to use on certs uploaded for joining control nodes
        cluster_name - name of the k8s cluster
        token - can be gotten from kubeadm token generate
        encrypt - whether to encrypt join info in salt-mine or not

    Returns:
      True or False based on success
    '''
     
    join_info = {'ca_hash': ca_hash, 'cert_key': cert_key, 'token': token}
    allow_tgt = 'I@kubeadm:cluster_name:{0}'.format(cluster_name)
    data = json.dumps(join_info)
    encrypt_key = __salt__["pillar.get"](pillar_encrypt_key, None)
    if encrypt_key:
        f = Fernet(encrypt_key)
        data = f.encrypt(data)
    r = __salt__["mine.send"](cluster_name, mine_function="test.arg", join_info=data, allow_tgt=allow_tgt, allow_tgt_type='compound')
    log.debug(r)

    if r:
        return True
    else:
        return False

def get_join_info(cluster_name, primary_controller, pillar_encrypt_key="kubeadm:join_info_encrypt_key"):
    '''
    Retrieve the info needed to join a cluster from Salt mine

    Parameters:
      args:
        cluster_name - name of the k8s cluster
        primary_controller - The control node that put the join info into Salt mine

    Returns:
      A dict with the join info on success, or False on failure
    '''

    r = __salt__["mine.get"](primary_controller, cluster_name)
    data = r[primary_controller]['kwargs']['join_info']
    encrypt_key = __salt__["pillar.get"](pillar_encrypt_key, None)
    if encrypt_key:
        f = Fernet(encrypt_key)
        data = f.decrypt(data)
    join_info = json.loads(data)
    log.debug('kubeadm.get_join_info: "{0}"'.format(join_info))
    
    if join_info:
        return join_info
    else:
        return False

def remove_join_info(cluster_name):
    '''
    Remove the cluster join info from Salt mine

    Parameters:
      args:
        cluster_name - name of the k8s cluster

    Returns:
      True or False based on success
    '''

    r = __salt__["mine.delete"](cluster_name)

    if r:
        return True
    else:
        return False


def create_join_info(cluster_name, v="0"):
    '''
    Creates the items necessary to join a K8s clsuter and uploads them to Salt mine

    Parameters:
      args:
        cluster_name - name of the k8s cluster

    Returns:
      True or False based on success
    '''

    token=generate_token(v=v)
    if not create_token(token):
        log.warning('kubeadm.create_join_info: create_token failed ')
        return False
    cert_key=generate_cert_key(v=v)
    if not cert_key:
        log.warning('kubeadm.create_join_info: generate_cert_key failed ')
        return False
    if not upload_certs(cert_key, v=v):
        log.warning('kubeadm.create_join_info: upload_certs failed ')
        return False
    ca_hash=get_ca_hash()
    if not ca_hash:
        log.warning('kubeadm.create_join_info: get_ca_hash failed ')
        return False

    if upload_join_info(ca_hash, cert_key, cluster_name, token):
        return True
    else:
        log.warning('kubeadm.create_join_info: upload_join_info failed ')
        return False

def initialize(advertise_address, 
               cert_key, 
               control_endpoint, 
               token,
               cluster_name="k8s", 
               pod_network="172.16.0.0/16",
               service_cidr="10.96.0.0/12",
               v="0"
              ):
    '''
    Initialize a kubernetes cluster on the first control node with kubeadm

    Parameters:
      args:
        advertise_address - The IP etcd will listen on
        cert_key - The encryption key to use on certs uploaded for joining control nodes
        control_endpoint  - The VIP that serves the cluster API
        token - can be gotten from kubeadm token generate
      kwargs:
        cluster_name - Name of the k8s cluster
        pod_network - CIDR network that the cluster will use for its pod net

    Returns:
      True or False based on success
    '''

    args = ["kubeadm"]
    args.append("--v={0}".format(v))
    args.append("init")
    args.append("--upload-certs")
    args.append("--skip-token-print")
    args.append("--skip-certificate-key-print")
#    args.append("--skip-phases=bootstrap-token") https://github.com/kubernetes-sigs/kubespray/issues/4117
    args.append("--token={0}".format(token))
    args.append("--pod-network-cidr={0}".format(pod_network))
    args.append("--service-cidr={0}".format(pod_network))
    args.append("--control-plane-endpoint={0}".format(control_endpoint))
    args.append("--certificate-key={0}".format(cert_key))
    args.append("--apiserver-advertise-address={0}".format(advertise_address))
    return execute_cmd(args) 


def join(control_endpoint, 
         primary_controller, 
         advertise_address="", 
         ca_hash="",  
         cert_key="", 
         cluster_name="k8s", 
         control=False, 
         token="",
         v="0"):
    '''
    join a control, or worker, node to an initialized kubernetes cluster

    Parameters:
      args:
        control_endpoint  - The VIP that serves the cluster API
        primary_controller - The control node that put the join info into Salt mine
      kwargs:
        advertise_address - The IP etcd will listen on
        ca_hash - The clusters CA certificate hash
        cert_key - The encryption key to use on certs uploaded for joining control nodes
        cluster_name - Name of the k8s cluster
        control - Whether the node is a control node or not
        token - can be gotten from kubeadm token generate

    Returns:
      True or False based on success
    '''

    args = ["kubeadm", "join", control_endpoint]

    if control:
        args.append("--control-plane")
        args.append("--certificate-key={0}".format(cert_key))
        args.append("--apiserver-advertise-address={0}".format(advertise_address))

    args.append("--v={0}".format(v))
    args.append("--token={0}".format(token))
    args.append("--discovery-token-ca-cert-hash={0}".format(ca_hash))
    return execute_cmd(args) 
