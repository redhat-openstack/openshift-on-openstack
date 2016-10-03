#!/usr/bin/python

import collections
import json
import yaml
import os
import sys


def dict_merge(dct, merge_dct):
    """ Recursive dict merge. Inspired by :meth:``dict.update()``, instead of
    updating only top-level keys, dict_merge recurses down into dicts nested
    to an arbitrary depth, updating keys. The ``merge_dct`` is merged into
    ``dct``.
    :param dct: dict onto which the merge is executed
    :param merge_dct: dct merged into dct
    :return: None
    """
    for k, v in merge_dct.iteritems():
        if (k in dct and isinstance(dct[k], dict)
                and isinstance(merge_dct[k], collections.Mapping)):
            dict_merge(dct[k], merge_dct[k])
        else:
            dct[k] = merge_dct[k]


def load_file(filename):
    name, extension = os.path.splitext(filename.lower())
    extension = extension.lstrip('.')
    if extension == "json":
        return json.load(open(filename))
    elif extension in ['yml', 'yaml']:
        return yaml.load(open(filename))
    raise Exception("Invalid format " + extension)


def save_file(dct, filename):
    name, extension = os.path.splitext(filename.lower())
    extension = extension.lstrip('.')
    if extension == "json":
        return json.dump(dct, open(filename, 'w'))
    elif extension in ['yml', 'yaml']:
        return yaml.safe_dump(dct, open(filename, 'w'))
    raise Exception("Invalid format " + extension)


if len(sys.argv) < 3:
    print("Usage: %s infile [infile...] outfile" % (sys.argv[0],))
    sys.exit(1)

merged = load_file(sys.argv[1])
for filename in sys.argv[2:-1]:
    dict_merge(merged, load_file(filename))

if os.path.exists(sys.argv[-1]):
    dict_merge(merged, load_file(sys.argv[-1]))

save_file(merged, sys.argv[-1])
