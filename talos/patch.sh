#!/bin/bash


talosctl apply-config -n 192.168.111.65 -f controlplane.yaml --config-patch @vixens-emy.yaml
talosctl apply-config -n 192.168.111.66 -f controlplane.yaml --config-patch @vixens-ruby.yaml
talosctl apply-config -n 192.168.111.63 -f controlplane.yaml --config-patch @vixens-jade.yaml
