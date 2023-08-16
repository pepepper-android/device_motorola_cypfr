#!/bin/sh
PATCH_LOC=$PWD/device/motorola/cypfr/patch
cd frameworks/av
git am $PATCH_LOC/frameworks/av/01-APM-Optionally-force-load-audio-policy-for-system-si.patch
git am $PATCH_LOC/frameworks/av/02-APM-Remove-A2DP-audio-ports-from-the-primary-HAL.patch
cd ../../packages/modules/Bluetooth
git am $PATCH_LOC/packages/modules/Bluetooth/01-Optionally-use-sysbta-HAL.patch