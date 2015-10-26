#!/usr/bin/env python

import yaml


CONFIG_PATH = "/etc/origin/master/master-config.yaml"

KEYSTONE_URL = 'http://openstack.demorack.lab.eng.rdu.redhat.com:5000/v3'

with open(CONFIG_PATH, 'r') as f:
    config = yaml.safe_load(f)

identity_provider = {
    'name': 'keystone_auth',
    'challenge': True,
    'login': True,
    'provider': {
        'apiVersion': 'v1',
        'url': KEYSTONE_URL,
        'domainName': 'default',
        'kind': 'KeystonePasswordIdentityProvider'
    }
}

config['oauthConfig']['identityProviders'] = [identity_provider]

config_string = yaml.dump(config, default_flow_style=False)

with open(CONFIG_PATH, 'w') as f:
    f.write(config_string)
