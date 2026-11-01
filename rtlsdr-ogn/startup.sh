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

# no ADS-B source configured -> drop the block, an empty AVR line is not valid
if [ -z "${ADSB_AVR}" ]; then
    awk '/^ADSB:/{skip=1} skip && /^};/{skip=0; next} !skip' \
        /app/rtlsdr-ogn/Template.conf > /app/rtlsdr-ogn/Template.conf.tmp
    mv /app/rtlsdr-ogn/Template.conf.tmp /app/rtlsdr-ogn/Template.conf
fi

# Start ogn-rf and ogn-decode under procServ directly instead of via the
# stock init script. This puts --logfile before the -c (chdir) option, which
# the init script cannot do for us (there --logfile ended up behind the
# command and -c swallowed it).
# Logs go to tmpfs (/dev/shm) only: no SD-card wear, wiped on restart.
LOGDIR=/dev/shm/rtlsdr-ogn
mkdir -p "$LOGDIR"
rm -f "$LOGDIR/50000.log" "$LOGDIR/50001.log"

# procServ options: ^X kills the child / ^C logs out / ^D is ignored,
# child auto-restart stays enabled (procServ default), cwd /app/rtlsdr-ogn
PROCSERV_OPTS="-p /tmp/procServ-PORT.pid --logfile $LOGDIR/PORT.log -k ^X --killsig 15 -x ^C -i ^D -c /app/rtlsdr-ogn"

for PORT in 50000 50001; do
    CHILD=ogn-rf
    [ "$PORT" = "50001" ] && CHILD=ogn-decode
    opts=${PROCSERV_OPTS//PORT/$PORT}
    # shellcheck disable=SC2086
    procServ $opts "$PORT" "./$CHILD" Template.conf &
done

# debians procServ can't listen publically.. proxy it
socat TCP-LISTEN:50000,fork,bind=$(hostname -i) TCP4:localhost:50000 &
socat TCP-LISTEN:50001,fork,bind=$(hostname -i) TCP4:localhost:50001 &

# mirror the procServ logs into the container's stdout so that `docker logs`
# shows the full ogn-rf / ogn-decode output. tail in the foreground keeps the
# container running; -F (not -f) survives log file recreation.
exec tail -n +1 -F "$LOGDIR/50000.log" "$LOGDIR/50001.log"