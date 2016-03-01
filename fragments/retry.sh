#!/bin/bash
#
# Make 5 attempts to execute a command at 2 sec intervals or until passed
#

for i in {1..5}; do
    $@ && exit || true
    sleep 2
done
exit 1
