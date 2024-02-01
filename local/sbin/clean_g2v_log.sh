#!/bin/bash

XARGS_OPT="--null --no-run-if-empty"  # Optionen für "xargs"

# Lösche alte g2v_log_*-Dateien die älter als 14 Tage sind
find /var/log -maxdepth 1 -type f -mtime +14 -name "g2v_log_[0-9]*.*" \
    -print0 | xargs $XARGS_OPT rm

# Lösche alte dmesg.*-Dateien die älter als 14 Tage sind
find /var/log/dmsg -maxdepth 1 -type f -mtime +14 -name "dmesg.*" \
     -print0 | xargs $XARGS_OPT rm

exit
