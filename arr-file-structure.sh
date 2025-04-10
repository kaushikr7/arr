#!/bin/bash

# Define datasets and directories
CFGPATH = "fastdata/appdata/arr"
APP_DATASETS=("prowlarr" "radarr" "sonarr" "jellyseerr" "recyclarr" "bazarr" "tdarr" "jellyfin" "qbittorrent" "dozzle")
TDARR_SUBDIRS=("server" "logs" "transcode_cache")
MEDIAPATH = "media/store"
MEDIA_SUBDIRECTORIES=("movies" "tv" "downloads")


# Function to create and set up a dataset
create_dataset() {
    local dataset_path="$1"
    local mountpoint="/mnt/$dataset_path"

    if ! zfs list "$dataset_path" >/dev/null 2>&1; then
        echo "Creating dataset: $dataset_path"
        zfs create "$dataset_path"
    fi

    # Ensure dataset is mounted
    if ! mountpoint -q "$mountpoint"; then
        echo "Mounting dataset: $dataset_path"
        zfs mount "$dataset_path"
    fi

    # Verify mount exists before applying permissions
    if [ -d "$mountpoint" ]; then
        chown apps:apps "$mountpoint"
        chmod 770 "$mountpoint"
    else
        echo "⚠️ Warning: $mountpoint does not exist after mounting. Check dataset status."
    fi
}

# Function to create a directory if it doesn't exist
create_directory() {
    local dir_path="$1"
    if [ ! -d "$dir_path" ]; then
        echo "Creating directory: $dir_path"
        mkdir -p "$dir_path"
        chown apps:apps "$dir_path"
        chmod 770 "$dir_path"
    else
        echo "Directory already exists: $dir_path, skipping..."
    fi
}

# Create the "configs" dataset (parent)
create_dataset $CFGPATH

# Create the config datasets
for dataset in "${APP_DATASETS[@]}"; do
    create_dataset "$CFGPATH/$dataset"
done

# Create the "media" dataset (instead of a directory)
create_dataset $MEDIAPATH

# Create subdirectories inside the media dataset
for subdir in "${MEDIA_SUBDIRECTORIES[@]}"; do
    create_directory "/mnt/$MEDIAPATH/$subdir"
done

# Ensure Tdarr subdirectories exist (only if tdarr dataset is properly mounted)
TDARR_MOUNTPOINT="/mnt/$CFGPATH/tdarr"
if mountpoint -q "$TDARR_MOUNTPOINT"; then
    for subdir in "${TDARR_SUBDIRS[@]}"; do
        create_directory "$TDARR_MOUNTPOINT/$subdir"
    done
else
    echo "⚠️ Skipping tdarr subdirectory creation; dataset is not mounted."
fi

