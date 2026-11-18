#!/usr/bin/env bash
if [ "$(cat /sys/class/power_supply/ACAD/online)" = "1" ]; then
  powerprofilesctl set performance
else
  powerprofilesctl set balanced
fi
