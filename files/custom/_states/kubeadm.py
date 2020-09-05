import logging

def initialized(name, 
                advertise_address="", 
                control_endpoint="", 
                service_cidr="10.96.0.0/12", 
                pod_network="172.16.0.0/16", 
                v="0"):
    '''
    '''

    cluster_name = name 
    minion_id = __opts__['id']
    ret = {
        'name': name,
        'changes': {},
        'result': False,
        'comment': '',
        'pchanges': {},
        }
     
    r = __salt__['kubeadm.is_joined']()

    if r:
        ret['result'] = True
        ret['comment'] = '{0} is already joined to the {1} cluster'.format(minion_id, name)
        return ret
  
    if __opts__['test']:
        ret['comment'] = '{0} will be joined to the {1} cluster'.format(minion_id, name)
        ret['result'] =  None
        return ret
    
    token = __salt__['kubeadm.generate_token'](v=v)

    if not token:
        ret['comment'] = 'kubeadm.generate_token failed'
        ret['result'] = False
        return ret
        
    cert_key = __salt__['kubeadm.generate_cert_key'](v=v)

    if not cert_key:
        ret['comment'] = 'kubeadm.generate_cert_key failed'
        ret['result'] = False
        return ret

    r = __salt__['kubeadm.initialize'](advertise_address=advertise_address, 
                                       control_endpoint=control_endpoint, 
                                       cluster_name=cluster_name,
                                       cert_key=cert_key,
                                       token=token,
                                       pod_network=pod_network,
                                       service_cidr=service_cidr,
                                       v=v)
    if not r:
        # Reset the node, and get it ready for another attempt
        __salt__['kubeadm.reset'](v=v)
        ret['comment'] = 'Primary controller {0} failed to initialized the {1} cluster'.format(minion_id, cluster_name)
        ret['result'] = False
        return ret

    ca_hash = __salt__['kubeadm.get_ca_hash']()

    if not ca_hash:
        ret['comment'] = 'kubeadm.get_ca_hash failed'
        ret['result'] = False
        return ret

    r = __salt__['kubeadm.upload_join_info'](ca_hash, cert_key, cluster_name, token)

    if not r:
        ret['comment'] = 'kubeadm.upload_join_info failed'
        ret['result'] = False
        return ret

    ret['comment'] = 'Primary controller {0} initialized the {1} cluster'.format(minion_id, cluster_name)
    ret['changes'].update({'Cluster {0}'.format(cluster_name):{'old': '', 'new': 'Initialized on {0}'.format(minion_id)}})
    ret['result'] = True
    return ret

def joined(name,
           primary_controller="",
           advertise_address="", 
           control_endpoint="", 
           control=False, 
           v="0"):
    '''
    '''
    
    cluster_name = name 
    minion_id = __opts__['id']
    ret = {
        'name': name,
        'changes': {},
        'result': False,
        'comment': '',
        'pchanges': {},
        }
     
    r = __salt__['kubeadm.is_joined']()

    if r:
        ret['result'] = True
        ret['comment'] = '{0} is already joined to the {1} cluster'.format(minion_id, name)
        return ret
  
    if __opts__['test']:
        ret['comment'] = '{0} will be joined to the {1} cluster'.format(minion_id, name)
        ret['result'] =  None
        return ret
    
    join_info = __salt__['kubeadm.get_join_info'](cluster_name, primary_controller)

    if not join_info:
        ret['comment'] = 'kubeadm.get_join_info failed'
        ret['result'] = False
        return ret
    else:
        token = join_info['token']
        ca_hash = join_info['ca_hash']
        cert_key = join_info['cert_key']

    r = __salt__['kubeadm.join'](control_endpoint=control_endpoint, 
                                 primary_controller=primary_controller, 
                                 advertise_address=advertise_address, 
                                 control=control, 
                                 cluster_name=cluster_name,
                                 token=token,
                                 ca_hash=ca_hash,
                                 cert_key=cert_key,
                                 v=v) 
    if not r:
        # Reset the node, and get it ready for another attempt
        __salt__['kubeadm.reset'](v=v)
        ret['result'] = False
        if control:  
          ret['comment'] = 'Controller {0} failed to join the {1} cluster'.format(minion_id, cluster_name)
        else:
          ret['comment'] = 'Worker {0} failed to join the {1} cluster'.format(minion_id, cluster_name)
    else:
        ret['result'] = True
        ret['changes'].update({'Cluster {0}'.format(cluster_name):{'old': '', 'new': '{0} joined'.format(minion_id)}})
        if control:  
          ret['comment'] = 'Controller {0} joined the {1} cluster.'.format(minion_id, cluster_name)
        else:
          ret['comment'] = 'Worker {0} joined the {1} cluster.'.format(minion_id, cluster_name)

    return ret
