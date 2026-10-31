#!/bin/bash

# defaults for the optional ADS-B feed (see the ADSB block in ogn-template.conf)
export ADSB_AVR="${ADSB_AVR:-}"
export ADSB_MAX_ALT_FT="${ADSB_MAX_ALT_FT:-18000}"

envsubst < /app/ogn-template.conf > /app/rtlsdr-ogn/Template.conf

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
socat TCP-LISTEN:50001,fork,bind=$(hostname -i) TCP4:localhost:50001
