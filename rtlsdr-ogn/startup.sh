#!/bin/bash

# defaults for the optional ADS-B feed (see the ADSB block in ogn-template.conf)
export ADSB_AVR="${ADSB_AVR:-}"
export ADSB_MAX_ALT_FT="${ADSB_MAX_ALT_FT:-18000}"

# provide defaults so empty values do not produce an invalid config (envsubst
# cannot apply ${VAR:-default} itself, so FreqCorr = ; would make ogn-rf exit)
export FREQ_PLAN="${FREQ_PLAN:-0}"
export SDR_868_PPM="${SDR_868_PPM:-0}"
export GSM_CENTER_FREQ="${GSM_CENTER_FREQ:-0}"
# rtlsdr-ogn wants BiasTee as a number, but the UI stores Python bools
case "${SDR_868_BIAS_T_ENABLE}" in [Tt]rue|1) SDR_868_BIAS_T_ENABLE=1 ;; *) SDR_868_BIAS_T_ENABLE=0 ;; esac
export SDR_868_BIAS_T_ENABLE

envsubst < /app/ogn-template.conf > /app/rtlsdr-ogn/Template.conf

# Keep the ogn-rf / ogn-decode output visible while limiting disk impact:
# - write the procServ logs to tmpfs (/dev/shm) instead of /var/log, so
#   nothing grows on the SD card and it's wiped on container restart
# - tell procServ (2.8.0) to use --logfile, otherwise it does not forward
#   the child's output at all and the files stay empty
INIT=/etc/init.d/rtlsdr-ogn
if [ -f "$INIT" ]; then
    sed -i 's|^logdir=.*|logdir=/dev/shm/rtlsdr-ogn|' "$INIT"
    # move procServ's logfile into its options (where it belongs) instead of
    # the shell redirection at the end, which procServ 2.8.0 does not honor
    # for child output
    sed -i 's#$options $DIR $params $PORT $COMMAND >> $LOG 2>&1 < /dev/null#$options --logfile $LOG $DIR $params $PORT $COMMAND < /dev/null#' "$INIT"
fi

# no ADS-B source configured -> drop the block, an empty AVR line is not valid
if [ -z "${ADSB_AVR}" ]; then
    awk '/^ADSB:/{skip=1} skip && /^};/{skip=0; next} !skip' \
        /app/rtlsdr-ogn/Template.conf > /app/rtlsdr-ogn/Template.conf.tmp
    mv /app/rtlsdr-ogn/Template.conf.tmp /app/rtlsdr-ogn/Template.conf
fi

/etc/init.d/rtlsdr-ogn start

cd /app/rtlsdr-ogn

# debians procServ can't listen publically.. proxy it
socat TCP-LISTEN:50000,fork,bind=$(hostname -i) TCP4:localhost:50000 &
socat TCP-LISTEN:50001,fork,bind=$(hostname -i) TCP4:localhost:50001 &

# mirror the procServ logs (ogn-rf / ogn-decode output) into the container's
# stdout so that `docker logs` shows them; wait for the files to appear first.
# tail in the foreground keeps the container running.
LOGDIR=/dev/shm/rtlsdr-ogn
for _ in $(seq 1 60); do [ -f "$LOGDIR/50000" ] && [ -f "$LOGDIR/50001" ] && break; sleep 1; done
# -F (not -f) so tail retries if a log file disappears or recreates on restart
exec tail -n +1 -F "$LOGDIR/50000" "$LOGDIR/50001"
