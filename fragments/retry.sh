#!/bin/bash

for i in {1..5}; do
    $@ && exit || true
done
exit 1
