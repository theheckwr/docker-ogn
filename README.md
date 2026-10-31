# docker version of [ogn-pi34 standard install script](https://github.com/VirusPilot/ogn-pi34?tab=readme-ov-file#automatic-setup-standard-script)

### supported operating systems
Debian-based Linux Operating Systems (64bit Debian 13 Trixie or newer)
- Debian
- Ubuntu
- DietPi
- RaspiOS

### supported hardware architectures
- arm64 (64-bit ARM CPUs with hardware floating point processor)
- x64 (64-bit AMD/Intel CPUs)
- SDRs: native support of RTL-SDR Blog v4 SDR since Debian 13 Trixie
---
### prepare system and docker
- `sudo apt update && sudo apt install --yes git wget`
- `bash <(wget -q -O - https://raw.githubusercontent.com/sdr-enthusiasts/docker-install/main/docker-install.sh)`
- you may be asked `Y/n` a couple of times, it is safe to answer all of them with `Y`
- `sudo reboot`

### prepare SDR_868_SERIAL
- identify or set your SDR serial (e.g. `868`), it is are required for the `config.vars` below
- issue the following command (with no second SDR plugged in):
  - `docker run --rm -it --device /dev/bus/usb --entrypoint rtl_eeprom ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder -s 868`

### prepare SDR_868_PPM
- to find out the appropriate ppm for your SDR, leave only the SDR to be used for 868 MHz reception plugged in, then issue the following command:
  - `docker run --rm -it --device /dev/bus/usb --entrypoint rtl_test ghcr.io/sdr-enthusiasts/docker-adsb-ultrafeeder -p`
  - let it run for 10-15 min (important so that the SDR warms up)
  - note the ppm listed in the related output, e.g. `... cumulative PPM: -1` and use that for SDR_868_PPM
  - modern SDRs have a TCXO, therefore SDR_868_PPM = 0 is the default

### prepare ogn
- `git clone https://github.com/VirusPilot/docker-ogn`

### configuration
- `cd ./docker-ogn`
- `nano config.vars`
  - save changes with `CTRL O`
  - exit nano with `CTRL X`

| variable | example | description |
| :--- | :--- | :--- |
| STATION_LAT | 50.0 | your station latitude |
| STATION_LON | 10.0 | your station longitude |
| STATION_ALT_MSL_M | 300 | your sattion altitude AMSL [m] |
| STATION_NAME | OGNTEST | your max. 9 letter station name, please comply with [naming convention](http://wiki.glidernet.org/receiver-naming-convention) |
| STATION_COMMENT_ANTENNA | VINNANT CC868/8-PEL | optional information about your station antenna | 
| STATION_COMMENT_FILTER |  | optional information about your station filter | 
| STATION_COMMENT_AMPLIFIER | Uputronics HAB-FPA868 | optional information about your station amplifier | 
| STATION_COMMENT_DONGLE | rtl-sdr v3 silver | optional information about your station dongle| 
| STATION_COMMENT_CLUB |  | optional name of your Flight Club | 
| STATION_COMMENT_EMAIL |  | optional station email contact| 
| STATION_COMMENT_WEBSITE |  | optional station website | 
| STATION_COMMENT_NOTE |  | optional notes about your station | 
| FREQ_PLAN | 0 | 0=automatic (default), 1=EU/Africa, 2=USA/Canada, 3=South America/Australia, 4=New Zealand, 5=Israel, 6=EU/Africa 433MHz, 7=Japan |
| GSM_CENTER_FREQ | 935.8 | default = 0, change only if you know your closest GSM900 station frequency [MHz] |
| SDR_868_SERIAL | 868 | enter your OGN SDR serial |
| SDR_868_PPM | 0 | change only if you know your SDR's ppm |
| SDR_868_BIAS_T_ENABLE | 0 | set to 1 to enable Bias Tee on your SDR, e.g. to power a LNA |
| ADSB_AVR | ultrafeeder:30002 | optional: address of a raw/AVR output (e.g. your readsb `--net-ro-port`) to additionally feed your own 1090 MHz ADS-B traffic into OGN - leave empty to keep the ADS-B feed **off** |
| ADSB_MAX_ALT_FT | 18000 | only used together with `ADSB_AVR`: ADS-B traffic above this altitude [ft] is not shared |

### build / pull
- `cd ./docker-ogn`
- `docker compose pull && docker compose up -d`
---
### apply configuration changes (e.g. station coordinates)
- `cd ./docker-ogn2readsb`
- `nano config.vars`
- `docker compose up -d`

### monitor OGN details
- `http://yourReceiverIP:8080`
- `http://yourReceiverIP:8081`

### monitor docker container
- `docker logs -f rtlsdr-ogn` (`CTRL C` to exit)

### monitor docker statistics
- `docker stats` (`CTRL C` to exit)

### open a shell inside your container
- `docker exec -it <yourDockerContainer> bash`

### useful docker commands
- `docker ps -a` list all docker containers, including stopped ones
- docker **container** related commands
  - `docker stop <container_name_or_id>` stop a running container
  - `docker rm <container_name_or_id>` deactivate a stopped container
  - `docker container prune` remove all stopped containers
  - `docker compose down` stop and remove all containers and networks
  - `docker compose pull` pull the latest image from GHCR
  - `docker compose up -d ` recreate and start containers
- docker **image** related commands
  - `docker image ls` list docker images
  - `docker rmi <image_id_or_name>` delete docker image
  - `docker image prune` delete all unused docker images
- docker **system** related commands
  - `docker system prune` clean your docker environment
- clean your entire docker environment e.g. for a fresh setup
  - `docker rm -f $(docker ps -aq)` force remove ALL containers
  - `docker system prune -af --volumes` clean your entire docker environment

 ### docker terms and related meaning
| Term       | Meaning                                              |
| ---------- | ---------------------------------------------------- |
| Dockerfile | Build instructions                                   |
| Image      | Built / immutable system image                       |
| Container  | Running instance of an image                         |
| Compose    | Orchestration / startup plan for multiple containers |
