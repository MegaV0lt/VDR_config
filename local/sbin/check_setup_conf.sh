#!/usr/bin/env bash

# Skript to check values in setup.conf

VDR_CONF='/etc/vdr/setup.conf'      # VDR's setup.conf
KEYS_TO_CHECK=(Setup.CurrentDolby)  # Setupkey to check
INTERVALL=10                        # Intervall to check

trap f_exit EXIT

# shellcheck disable=SC2317  # Don't warn about unreachable commands in this function
f_exit() {
  KEY=$(grep --max-count=1 "Setup.CurrentDolby" "$VDR_CONF")
  logger -t check_setup_conf.sh "Value at 'EXIT': $KEY"
}

logger -t check_setup_conf.sh "Start with pid $$"
while : ; do  # pidof vdr >/dev/null ; do
  for key in "${KEYS_TO_CHECK[@]}" ; do
    KEY=$(grep --max-count=1 "$key" "$VDR_CONF")
    if [[ "$KEY" != "$LAST_KEY" ]] ; then
        logger -t check_setup_conf.sh "Value changed: ${LAST_KEY:-First check before vdr start} to $KEY"
        LAST_KEY="$KEY"
    fi
  done
  sleep 10  # Wait 10 seconds before next check
done

exit  # Ende
