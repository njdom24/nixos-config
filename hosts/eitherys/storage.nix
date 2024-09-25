{ pkgs, lib, ... }:
let
  # List of devices for Btrfs scrub and SMART monitoring
  btrfsDevices = [ "/" ];  # Adjust paths as needed
  smartDevices = [ "/dev/disk/by-id/usb-WD_My_Passport_2626_575839324435334152364A43-0:0" ];  # Adjust device names as needed
in
{
  environment.systemPackages = with pkgs; [
    smartmontools
  ];

  services.smartd = {
    enable = true;
    devices = [
      { device = "/dev/disk/by-id/usb-WD_My_Passport_2626_575839324435334152364A43-0:0"; } 
    ];
  };

  systemd = {
    services = lib.mkMerge (lib.concatMap (device: [
      {
        "btrfs-scrub-${lib.replaceStrings ["/"] ["_"] device}" = {
          description = "Btrfs Scrub Monitoring Service for ${device}";
          after = [ "network.target" ];
          serviceConfig = {
            Type = "simple";
            ExecStart = [ "${pkgs.btrfs-progs}/bin/btrfs scrub start -B ${device}" ];
          };
          restartIfChanged = true;
        };
      }
    ]) btrfsDevices ++ lib.concatMap (device: [
      {
        "smart-monitor-${lib.replaceStrings ["/"] ["_"] device}" = {
          description = "SMART Monitoring Service for Extended Test on ${device}";
          after = [ "network.target" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = [ "${pkgs.smartmontools}/bin/smartctl -t long ${device}" ];
          };
          restartIfChanged = true;
        };
      }
    ]) smartDevices);

    timers = lib.mkMerge (lib.concatMap (device: [
      {
        "btrfs-scrub-${lib.replaceStrings ["/"] ["_"] device}.timer" = {
          description = "Monthly Btrfs Scrub Timer for ${device}";
          timerConfig.OnCalendar = "*-*-01 01:00:00";  # Runs at 1:00 AM on the first of each month
          wantedBy = [ "timers.target" ];
          timerConfig.Persistent = true;
          timerConfig.Unit = "btrfs-scrub-${lib.replaceStrings ["/"] ["_"] device}.service";
        };
      }
    ]) btrfsDevices ++ lib.concatMap (device: [
      {
        "smart-monitor-${lib.replaceStrings ["/"] ["_"] device}.timer" = {
          description = "Monthly SMART Test Timer for ${device}";
          timerConfig.OnCalendar = "*-*-01 04:00:00";  # Runs at 4:00 AM on the first of each month
          wantedBy = [ "timers.target" ];
          timerConfig.Persistent = true;
          timerConfig.Unit = "smart-monitor-${lib.replaceStrings ["/"] ["_"] device}.service";
        };
      }
    ]) smartDevices);
  };
}
