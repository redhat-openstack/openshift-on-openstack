#!/usr/bin/python
# -*- coding: utf-8 -*-
# vim: expandtab:tabstop=4:shiftwidth=4
"""
Custom filters for use in openshift-ansible
"""

import os
import re
import json
from ansible.utils.unicode import to_unicode

class FilterModule(object):
    def filters(self):
        """ returns a mapping of filters to methods """
        return {
            "oo_parse_heat_stack_outputs": self.oo_parse_heat_stack_outputs,
        }

    @staticmethod
    def oo_parse_heat_stack_outputs(data):
        """ Formats the HEAT stack output into a usable form

            The goal is to transform something like this:

            +---------------+-------------------------------------------------+
            | Property      | Value                                           |
            +---------------+-------------------------------------------------+
            | capabilities  | [] |                                            |
            | creation_time | 2015-06-26T12:26:26Z |                          |
            | description   | OpenShift cluster |                             |
            | …             | …                                               |
            | outputs       | [                                               |
            |               |   {                                             |
            |               |     "output_value": "value_A"                   |
            |               |     "description": "This is the value of Key_A" |
            |               |     "output_key": "Key_A"                       |
            |               |   },                                            |
            |               |   {                                             |
            |               |     "output_value": [                           |
            |               |       "value_B1",                               |
            |               |       "value_B2"                                |
            |               |     ],                                          |
            |               |     "description": "This is the value of Key_B" |
            |               |     "output_key": "Key_B"                       |
            |               |   },                                            |
            |               | ]                                               |
            | parameters    | {                                               |
            | …             | …                                               |
            +---------------+-------------------------------------------------+

            into something like this:

            {
              "Key_A": "value_A",
              "Key_B": [
                "value_B1",
                "value_B2"
              ]
            }
        """
        # Extract the “outputs” JSON snippet from the pretty-printed array
        in_outputs = False
        outputs = ''

        line_regex = re.compile(r'\|\s*(.*?)\s*\|\s*(.*?)\s*\|')
        for line in data['stdout_lines']:
            match = line_regex.match(line)
            if match:
                if match.group(1) == 'outputs':
                    in_outputs = True
                elif match.group(1) != '':
                    in_outputs = False
                if in_outputs:
                    outputs += match.group(2)

        outputs = json.loads(outputs)

        # Revamp the “outputs” to put it in the form of a “Key: value” map
        revamped_outputs = {}
        for output in outputs:
            revamped_outputs[output['output_key']] = output['output_value']

        return revamped_outputs
