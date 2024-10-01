{ config, pkgs, lib, ... }:
let
  backupScript = pkgs.writeShellScript "media-backup" ''
    #! /usr/bin/env bash
    
    BACKUP_NAME="drive-backups"
    BACKUP_DIR="/tmp/$BACKUP_NAME"
    LOCAL_BACKUP="/var/backups"
    
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$LOCAL_BACKUP"
    mkdir -p "$LOCAL_BACKUP/tars"
    
    # Delete everything in BACKUP_DIR
    rm -rf "$BACKUP_DIR"/*
    
    dirs=(
    	"${config.services.jellyfin.dataDir}/data"
    	"${config.services.jellyfin.configDir}"
    	"/srv/docker/kavita/data/backups"
    	"/srv/docker/romm/data"
    	"${config.services.sonarr.dataDir}/Backups"
    	"${config.services.radarr.dataDir}/Backups"
    	"/var/lib/prowlarr/Backups"
    	"/var/lib/sabnzbd"
    	"/srv/docker/lazylibrarian/data"
    	"/srv/docker/qbittorrent/config/qBittorrent/BT_backup"
    	"/home/elpis/.local/state/syncthing/config.xml"
    	"/var/secrets"
    )
    
    excludes=(
    	"${config.services.jellyfin.cacheDir}"
    	"${config.services.jellyfin.logDir}"
    	"/var/lib/sabnzbd/Downloads"
    	"/srv/docker/lazylibrarian/data/cache"
    	"/srv/docker/lazylibrarian/data/tmp"
    )
    
    for dir in "''${dirs[@]}"; do
        # Create the corresponding directory structure in the backup directory
        target="$BACKUP_DIR$(dirname "$dir")"
        mkdir -p "$target"
    
        # Create the symlink in the backup directory
        ln -s "$dir" "$target/$(basename "$dir")"
    done
    
    echo "Created symlinks"
    
    # Prepare exclude options for rclone
    exclude_args=()
    for exclude in "''${excludes[@]}"; do
        exclude_args+=(--exclude "$exclude/**")
    done
    
    export RCLONE_CONFIG=/var/secrets/rclone.conf

    echo "Backing up .nfos"
    ${pkgs.rsync}/bin/rsync -av --relative /mnt/ext/Media/TV/*/*/*.nfo "$BACKUP_DIR"
    
    # Rsync locally (-LK to follow links, dir links)
    # "'''" (Fixing syntax highlighting issue)
    ${pkgs.rsync}/bin/rsync --delete -avLK "$BACKUP_DIR" "$LOCAL_BACKUP" "''${exclude_args[@]}" #--log-file="$BACKUP_DIR/rsync-local.log"
    
    cd "$LOCAL_BACKUP/$BACKUP_NAME/"
    
    file_count=$(ls ../tars/backup_*.tar.xz 2>/dev/null | wc -l)
    # If there are no backups locally, restore them from the cloud to avoid accidental deletion on sync
    if [ "$file_count" -eq 0 ]; then
      echo "Restoring backups from cloud"
      ${pkgs.rclone}/bin/rclone sync -v "gdrive:/Server Backups" "../tars"  --config "$RCLONE_CONFIG"
    fi
    
    BACKUP_FNAME="backup_$(date +%F%s).tar.xz"
    ${pkgs.gnutar}/bin/tar -I ${pkgs.xz}/bin/xz -cf "../tars/$BACKUP_FNAME" *
    
    # Count the number of tar files in the directory
    file_count=$(ls ../tars/backup_*.tar.xz 2>/dev/null | wc -l)
    
    # Only proceed if there are more than 5 files
    if [ "$file_count" -gt 5 ]; then
        # List the tar files sorted by name, oldest first
        # Then use head to select the files to delete, keeping only the last 5
        ls ../tars/backup_*.tar.xz | sort | head -n -"$((file_count - 5))" | while read -r file; do
            echo "Deleting $file"
            rm "$file"
        done
    else
        echo "There are $file_count files. No files to delete."
    fi
    
    ${pkgs.rclone}/bin/rclone sync -v "../tars" "gdrive:/Server Backups" --config "$RCLONE_CONFIG" --drive-use-trash=false #--log-file="$BACKUP_DIR/backups.log"
    
    echo "Done"
    
    # Delete everything in BACKUP_DIR except *.log* files directly under BACKUP_DIR
    find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 ! -name '*.log*' -exec rm -rf {} +
  '';
in
{
  systemd = {
    services = {
      "backup-metadata" = {
        description = "Back up server metadata to cloud";
        after = [ "network.target" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${backupScript}";
        };
        restartIfChanged = true;
      };
    };

    timers = {
      "backup-metadata" = {
        description = "Weekly backup timer for server metadata";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "Mon *-*-* 00:00:00"; # Runs at 00:00 every Monday
          Persistent = true;
          Unit = "backup-metadata.service";
        };
      };
    };
  };
}
