# Define datasets and directories
CFGPATH="fastdata/appdata/arr"
DOCKER_COMPOSE_PATH="/mnt/fastdata/docker"

# Ask the user if they want to launch the Docker containers
read -p "Would you like to setup the arr-stack Docker containers now? (yes/no): " LAUNCH_CONTAINERS
# Launch Docker containers
if [[ "$LAUNCH_CONTAINERS" =~ ^[Yy]es$ ]]; then

    if [[ "$LAUNCH_CONTAINERS" =~ ^[Yy]es$ ]]; then
        echo "Docker containers launched successfully!"

        # Modify qBittorrent.conf after the container is running
        QBITTORRENT_CONF_FILE="/mnt/$CFGPATH/qbittorrent/config/qBittorrent.conf"
        echo "Waiting for qBittorrent to generate its configuration file..."
        while [ ! -f "$QBITTORRENT_CONF_FILE" ]; do
            sleep 5
            echo "Waiting for $QBITTORRENT_CONF_FILE to be created..."
        done

        # Update or add the DefaultSavePath in the [BitTorrent] section
        if grep -q "\[BitTorrent\]" "$QBITTORRENT_CONF_FILE"; then
            echo "[BitTorrent] section found in $QBITTORRENT_CONF_FILE"
            if grep -q "Session\\DefaultSavePath=" "$QBITTORRENT_CONF_FILE"; then
                echo "Updating Session\\DefaultSavePath in $QBITTORRENT_CONF_FILE"
                sed -i "/\[BitTorrent\]/,/^\[/ s|Session\\DefaultSavePath=.*|Session\\DefaultSavePath=/media/downloads|" "$QBITTORRENT_CONF_FILE"
            else
                echo "Adding Session\\DefaultSavePath under [BitTorrent] section in $QBITTORRENT_CONF_FILE"
                sed -i "/\[BitTorrent\]/a Session\\DefaultSavePath=/media/downloads" "$QBITTORRENT_CONF_FILE"
            fi
        else
            echo "[BitTorrent] section not found in $QBITTORRENT_CONF_FILE"
            echo "Adding [BitTorrent] section and Session\\DefaultSavePath to $QBITTORRENT_CONF_FILE"
            echo -e "\n[BitTorrent]\nSession\\DefaultSavePath=/media/downloads" >> "$QBITTORRENT_CONF_FILE"
        fi

        echo "qBittorrent default save path set to /media/downloads in $QBITTORRENT_CONF_FILE"

        # Restart the qBittorrent container to apply the changes
        echo "Restarting qBittorrent container to apply the new configuration..."
        docker restart qbittorrent

        echo "qBittorrent configuration updated and container restarted."

        # Ask the user if they want to configure recyclarr
        read -p "Would you like to sync recyclarr to radarr and sonarr? (yes/no): " CONFIGURE_RECYCLARR

        if [[ "$CONFIGURE_RECYCLARR" =~ ^[Yy]es$ ]]; then
            echo "Configuring recyclarr..."

            # Paths to Radarr and Sonarr config files
            RADARR_CONFIG_FILE="/mnt/$CFGPATH/radarr/config.xml"
            SONARR_CONFIG_FILE="/mnt/$CFGPATH/sonarr/config.xml"

            # Function to extract API key from config file
            extract_api_key() {
                local config_file="$1"
                if [ -f "$config_file" ]; then
                    grep -oP '(?<=<ApiKey>)[^<]+' "$config_file"
                else
                    echo ""
                fi
            }

            # Extract Radarr API key
            RADARR_API_KEY=$(extract_api_key "$RADARR_CONFIG_FILE")
            if [ -z "$RADARR_API_KEY" ]; then
                echo "⚠️ Error: Radarr API key not found in $RADARR_CONFIG_FILE"
                exit 1
            fi

            # Extract Sonarr API key
            SONARR_API_KEY=$(extract_api_key "$SONARR_CONFIG_FILE")
            if [ -z "$SONARR_API_KEY" ]; then
                echo "⚠️ Error: Sonarr API key not found in $SONARR_CONFIG_FILE"
                exit 1
            fi

            echo "Radarr API key: $RADARR_API_KEY"
            echo "Sonarr API key: $SONARR_API_KEY"

            # Step 1: Run `recyclarr config create` inside the recyclarr container
            echo "Creating recyclarr configuration..."
            docker exec -it recyclarr recyclarr config create

            # Step 2: Overwrite the recyclarr.yml file with the provided template
            RECYCLARR_YML="/mnt/$CFGPATH/recyclarr/recyclarr.yml"
            echo "Updating $RECYCLARR_YML with API keys..."

            cat > "$RECYCLARR_YML" <<EOF
sonarr:
  web-1080p-v4:
    base_url: http://sonarr:8989
    api_key: $SONARR_API_KEY
    delete_old_custom_formats: true
    replace_existing_custom_formats: true
    include:
      # Comment out any of the following includes to disable them
      - template: sonarr-quality-definition-series
      - template: sonarr-v4-quality-profile-web-1080p
      - template: sonarr-v4-custom-formats-web-1080p
      - template: sonarr-v4-quality-profile-web-2160p
      - template: sonarr-v4-custom-formats-web-2160p

# Custom Formats: https://recyclarr.dev/wiki/yaml/config-reference/custom-formats/
    custom_formats:
      # HDR Formats
      - trash_ids:
          # Comment out the next line if you and all of your users' setups are fully DV compatible
          - 9b27ab6498ec0f31a3353992e19434ca # DV (WEBDL)
          # HDR10Plus Boost - Uncomment the next line if any of your devices DO support HDR10+
          # - 0dad0a507451acddd754fe6dc3a7f5e7 # HDR10Plus Boost
        assign_scores_to:
          - name: WEB-2160p


      # Optional
      - trash_ids:
           - 32b367365729d530ca1c124a0b180c64 # Bad Dual Groups
           - 82d40da2bc6923f41e14394075dd4b03 # No-RlsGroup
           - e1a997ddb54e3ecbfe06341ad323c458 # Obfuscated
           - 06d66ab109d4d2eddb2794d21526d140 # Retags
           - 1b3994c551cbb92a2c781af061f4ab44 # Scene
        assign_scores_to:
          - name: WEB-2160p

      - trash_ids:
          # Uncomment the next six lines to allow x265 HD releases with HDR/DV
          - 47435ece6b99a0b477caf360e79ba0bb # x265 (HD)
        assign_scores_to:
          - name: WEB-2160p
            score: 0
      - trash_ids:
          - 9b64dff695c2115facf1b6ea59c9bd07 # x265 (no HDR/DV)
        assign_scores_to:
          - name: WEB-2160p

      - trash_ids:
          - 2016d1676f5ee13a5b7257ff86ac9a93 # SDR
        assign_scores_to:
          - name: WEB-2160p
            # score: 0 # Uncomment this line to enable SDR releases

      # Optional
      - trash_ids:
           - 32b367365729d530ca1c124a0b180c64 # Bad Dual Groups
           - 82d40da2bc6923f41e14394075dd4b03 # No-RlsGroup
           - e1a997ddb54e3ecbfe06341ad323c458 # Obfuscated
           - 06d66ab109d4d2eddb2794d21526d140 # Retags
           - 1b3994c551cbb92a2c781af061f4ab44 # Scene
        assign_scores_to:
          - name: WEB-1080p

      - trash_ids:
          # Uncomment the next six lines to allow x265 HD releases with HDR/DV
          - 47435ece6b99a0b477caf360e79ba0bb # x265 (HD)
        assign_scores_to:
          - name: WEB-1080p
            score: 0
      - trash_ids:
          - 9b64dff695c2115facf1b6ea59c9bd07 # x265 (no HDR/DV)
        assign_scores_to:
          - name: WEB-1080p

# Configuration specific to Radarr.
radarr:
 uhd-bluray-web:
    base_url: http://radarr:7878
    api_key: $RADARR_API_KEY
    delete_old_custom_formats: true
    replace_existing_custom_formats: true
    include:
     # Comment out any of the following includes to disable them
     - template: radarr-quality-definition-movie
     - template: radarr-quality-profile-uhd-bluray-web
     - template: radarr-custom-formats-uhd-bluray-web
     - template: radarr-quality-definition-movie
     - template: radarr-quality-profile-hd-bluray-web
     - template: radarr-custom-formats-hd-bluray-web

# Custom Formats: https://recyclarr.dev/wiki/yaml/config-reference/custom-formats/
    custom_formats:
     # Audio
     - trash_ids:
         # Uncomment the next section to enable Advanced Audio Formats
         # - 496f355514737f7d83bf7aa4d24f8169 # TrueHD Atmos
         # - 2f22d89048b01681dde8afe203bf2e95 # DTS X
         # - 417804f7f2c4308c1f4c5d380d4c4475 # ATMOS (undefined)
         # - 1af239278386be2919e1bcee0bde047e # DD+ ATMOS
         # - 3cafb66171b47f226146a0770576870f # TrueHD
         # - dcf3ec6938fa32445f590a4da84256cd # DTS-HD MA
         # - a570d4a0e56a2874b64e5bfa55202a1b # FLAC
         # - e7c2fcae07cbada050a0af3357491d7b # PCM
         # - 8e109e50e0a0b83a5098b056e13bf6db # DTS-HD HRA
         # - 185f1dd7264c4562b9022d963ac37424 # DD+
         # - f9f847ac70a0af62ea4a08280b859636 # DTS-ES
         # - 1c1a4c5e823891c75bc50380a6866f73 # DTS
         # - 240770601cc226190c367ef59aba7463 # AAC
         # - c2998bd0d90ed5621d8df281e839436e # DD
       assign_scores_to:
         - name: UHD Bluray + WEB

     # Movie Versions
     - trash_ids:
         - 9f6cbff8cfe4ebbc1bde14c7b7bec0de # IMAX Enhanced
       assign_scores_to:
         - name: UHD Bluray + WEB
           # score: 0 # Uncomment this line to disable prioritised IMAX Enhanced releases

     # Optional
     - trash_ids:
         # Comment out the next line if you and all of your users' setups are fully DV compatible
         - 923b6abef9b17f937fab56cfcf89e1f1 # DV (WEBDL)
         # HDR10Plus Boost - Uncomment the next line if any of your devices DO support HDR10+
         # - b17886cb4158d9fea189859409975758 # HDR10Plus Boost
       assign_scores_to:
         - name: UHD Bluray + WEB

     - trash_ids:
         - 9c38ebb7384dada637be8899efa68e6f # SDR
       assign_scores_to:
         - name: UHD Bluray + WEB
           # score: 0 # Uncomment this line to allow SDR releases

     - trash_ids:
         - 9f6cbff8cfe4ebbc1bde14c7b7bec0de # IMAX Enhanced
       assign_scores_to:
         - name: HD Bluray + WEB
           # score: 0 # Uncomment this line to disable prioritised IMAX Enhanced releases
EOF

            echo "recyclarr.yml file updated successfully!"

            # Step 3: Run `recyclarr sync` inside the recyclarr container
            echo "Running recyclarr sync..."
            docker exec -it recyclarr recyclarr sync

            echo "recyclarr configuration and sync completed!"
        else
            echo "Skipping recyclarr configuration."
        fi

        # Add root folders to Radarr and Sonarr using their APIs
        echo "Adding root folders to Radarr and Sonarr..."

        # Wait for Radarr and Sonarr to be fully initialized
        echo "Waiting for Radarr and Sonarr to be ready..."
        until curl -s "http://localhost:7878/api/v3/system/status" -o /dev/null; do sleep 5; done
        until curl -s "http://localhost:8989/api/v3/system/status" -o /dev/null; do sleep 5; done

        # Add root folder to Radarr
        echo "Adding root folder to Radarr..."
        curl -X POST "http://localhost:7878/api/v3/rootfolder" \
          -H "X-Api-Key: $RADARR_API_KEY" \
          -H "Content-Type: application/json" \
          -d '{
                "path": "/media/movies"
              }'

        # Add root folder to Sonarr
        echo "Adding root folder to Sonarr..."
        curl -X POST "http://localhost:8989/api/v3/rootfolder" \
          -H "X-Api-Key: $SONARR_API_KEY" \
          -H "Content-Type: application/json" \
          -d '{
                "path": "/media/tv"
              }'

        echo "Root folders added successfully!"
    else
        echo "⚠️ Failed to launch Docker containers. Check the logs for errors."
    fi
else
    echo "Docker containers were not launched. You can start them manually by running:"
    echo "cd $DOCKER_COMPOSE_PATH && docker compose up -d"
fi
# Print running containers and their accessible URLs
if [[ "$LAUNCH_CONTAINERS" =~ ^[Yy]es$ ]]; then
    echo "Listing all running containers and their accessible URLs:"

    # Get the host's IP address
    host_ip=$(hostname -I | awk '{print $1}')

    # Get a list of all running containers
    docker ps --format "{{.Names}}" | while read -r container_name; do
        # Get the container's exposed ports
        ports=$(docker inspect -f '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{ (index $conf 0).HostPort }} {{end}}{{end}}' "$container_name")

        # Print the container name and its accessible URL
        if [ -n "$ports" ]; then
            for port in $ports; do
                echo "$container_name | http://$host_ip:$port"
            done
        else
            echo "$container_name | No exposed port found"
        fi
    done

    # Extract and print the qBittorrent password from the logs
    qbittorrent_container="qbittorrent"
    if docker ps --format "{{.Names}}" | grep -q "$qbittorrent_container"; then
        echo "Fetching qBittorrent password from logs..."
        qbittorrent_password=$(docker logs "$qbittorrent_container" 2>&1 | grep "The WebUI administrator password was not set." | awk -F ': ' '{print $NF}')
        if [ -n "$qbittorrent_password" ]; then
            echo "qBittorrent WebUI password: $qbittorrent_password"
        else
            echo "qBittorrent WebUI password not found in logs."
        fi
    else
        echo "qBittorrent container is not running."
    fi
fi
