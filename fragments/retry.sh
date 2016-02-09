#!/bin/bash

for i in {1..5}; do
    $@ && exit || true
    sleep 2
done
exit 1
