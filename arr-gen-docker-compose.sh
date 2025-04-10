#!/bin/bash

# Define datasets and directories
CFGPATH="fastdata/appdata/arr"
MEDIAPATH="media/store"
DOCKER_COMPOSE_PATH="/mnt/fastdata/docker"


# Ensure Docker Compose directory exists
create_directory "$DOCKER_COMPOSE_PATH"

# Ensure the Docker Compose file path exists
DOCKER_COMPOSE_FILE="$DOCKER_COMPOSE_PATH/arr-docker-compose.yml"
if [ ! -d "$DOCKER_COMPOSE_PATH" ]; then
    echo "⚠️ Docker Compose directory missing, creating: $DOCKER_COMPOSE_PATH"
    mkdir -p "$DOCKER_COMPOSE_PATH"
fi

# Generate arr-docker-compose.yml
cat > "$DOCKER_COMPOSE_FILE" <<EOF
networks:
  media_network:
    driver: bridge

services:
  gluetun:
    container_name: gluetun
    image: qmcgaw/gluetun:latest
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    networks:
      - media_network
    ports:
      - 9696:9696       # Prowlarr
      - 7878:7878       # Radarr
      - 8989:8989       # Sonarr
      - 5055:5055       # Jellyseerr
      - 8191:8191       # Flaresolverr
      - 6767:6767       # Bazarr
      - 8265:8265       # Tdarr webUI
      - 8266:8266       # Tdarr server
      - 8096:8096       # Jellyfin
      - 32400:32400/tcp # Plex
      - 8324:8324/tcp   # Plex Companion
      - 32469:32469/tcp # Plex DLNA
      - 1900:1900/udp   # Plex DLNA
      - 32410:32410/udp # Plex GDM
      - 32412:32412/udp # Plex GDM
      - 32413:32413/udp # Plex GDM
      - 32414:32414/udp # Plex GDM
      - 8080:8080/tcp   # qBittorrent
      - 6881:6881/udp   # qBittorrent DHT
      - 8888:8080       # Dozzle
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
      - VPN_SERVICE_PROVIDER=nordvpn
      - VPN_TYPE=wireguard
      - WIREGUARD_PRIVATE_KEY=4Y2x8ZtblodezemvseylnJ2uGmqdZFx133zeF+QJPW0=
      - SERVER_COUNTRIES=Hong Kong
	  - SERVER_CATEGORIES="Standard VPN servers","P2P"
      - FIREWALL_OUTBOUND_SUBNETS=192.168.0.0/16
      # - FIREWALL_VPN_INPUT_PORTS=8080,7878,8989,9696,32400 # Explicit allowed ports on the internet
      - UPDATER_PERIOD=24h
      - DNS_SERVERS=1.1.1.1,9.9.9.9
      - FIREWALL_DEBUG=true
    devices:
      - /dev/net/tun:/dev/net/tun
    volumes:
      - /mnt/$CFGPATH/gluetun:/gluetun

  prowlarr:
    container_name: prowlarr
    image: linuxserver/prowlarr:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
    volumes:
      - /mnt/$CFGPATH/prowlarr:/config
      - /mnt/$MEDIAPATH:/media

  radarr:
    container_name: radarr
    image: linuxserver/radarr:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
    volumes:
      - /mnt/$CFGPATH/radarr:/config
      - /mnt/$MEDIAPATH:/media

  sonarr:
    container_name: sonarr
    image: linuxserver/sonarr:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
    volumes:
      - /mnt/$CFGPATH/sonarr:/config
      - /mnt/$MEDIAPATH:/media

  jellyseerr:
    container_name: jellyseerr
    image: fallenbagel/jellyseerr:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
    volumes:
      - /mnt/$CFGPATH/jellyseerr:/app/config
      
  flaresolverr:
    container_name: flaresolverr
    image: ghcr.io/flaresolverr/flaresolverr:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
      - LOG_LEVEL=info
      - LOG_HTML=false
      - CAPTCHA_SOLVER=none

  recyclarr:
    container_name: recyclarr
    image: ghcr.io/recyclarr/recyclarr:latest
    user: 568:568
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      CRON_SCHEDULE: 0 0 * * *
    volumes:
      - /mnt/$CFGPATH/recyclarr:/config

  bazarr:
    container_name: bazarr
    image: linuxserver/bazarr:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
    volumes:
      - /mnt/$CFGPATH/bazarr:/config
      - /mnt/$MEDIAPATH:/media

  tdarr:
    container_name: tdarr
    image: ghcr.io/haveagitgat/tdarr:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
      - UMASK_SET=002
      - serverIP=0.0.0.0
      - serverPort=8266
      - webUIPort=8265
      - internalNode=true
      - inContainer=true
      - ffmpegVersion=6
      - nodeName=MyInternalNode
      - NVIDIA_DRIVER_CAPABILITIES=all
      - NVIDIA_VISIBLE_DEVICES=all
    volumes:
      - /mnt/$CFGPATH/tdarr:/app/config
      - /mnt/$CFGPATH/tdarr/server:/app/server
      - /mnt/$CFGPATH/tdarr/logs:/app/logs
      - /mnt/$CFGPATH/tdarr/transcode_cache:/temp
      - /mnt/$MEDIAPATH:/media
    devices:
      - /dev/dri:/dev/dri
    deploy:
      resources:
        reservations:
          devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]

  jellyfin:
    container_name: jellyfin
    image: lscr.io/linuxserver/jellyfin:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
    volumes:
      - /mnt/$CFGPATH/jellyfin:/config
      - /mnt/$MEDIAPATH:/media

  plex:
    container_name: plex
    image: lscr.io/linuxserver/plex:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
    volumes:
      - /mnt/$CFGPATH/plex:/config
      - /mnt/$MEDIAPATH/tv:/tv
      - /mnt/$MEDIAPATH/movies:/movies
      - /mnt/$MEDIAPATH/music:/music

  qbittorrent:
    container_name: qbittorrent
    image: linuxserver/qbittorrent:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    environment:
      - PUID=568
      - PGID=568
      - TZ=Asia/Hong_Kong
      - UMASK=002
      - WEBUI_PORTS=8080/tcp,8080/udp
    sysctls:
      - net.ipv4.conf.all.src_valid_mark=1
      - net.ipv6.conf.all.disable_ipv6=1
    volumes:
      - /mnt/$CFGPATH/qbittorrent:/config
      - /mnt/$MEDIAPATH:/media

  dozzle:
    container_name: dozzle
    image: amir20/dozzle:latest
    depends_on:
      - gluetun
    restart: unless-stopped
    network_mode: "service:gluetun"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
      - /mnt/$CFGPATH/dozzle:/data

  watchtower:
    container_name: watchtower
    image: containrrr/watchtower:latest
    restart: unless-stopped
	network_mode: host # Required for Docker socket access
    environment:
      - TZ=Asia/Hong_Kong
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_NOTIFICATIONS_HOSTNAME=TrueNAS
      - WATCHTOWER_INCLUDE_STOPPED=true
      - WATCHTOWER_DISABLE_CONTAINERS=ix*
      - WATCHTOWER_NO_STARTUP_MESSAGE=true
      - WATCHTOWER_SCHEDULE=0 0 3 * * *
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
EOF

echo "Docker Compose file created at $DOCKER_COMPOSE_FILE"
echo "Script completed."

