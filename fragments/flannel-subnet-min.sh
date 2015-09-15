#!/usr/bin/env python

import sys

network = sys.argv[1]
subnet_increments = int(sys.argv[2])

first_ip_address = network.split('/')[0]

subnet_min_address = first_ip_address.split('.')

new_c_segment = int(subnet_min_address[2]) + subnet_increments
assert 0 <= new_c_segment < 256

subnet_min_address[2] = str(new_c_segment)

print ".".join(subnet_min_address)
