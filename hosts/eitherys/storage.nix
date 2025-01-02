{ pkgs, lib, ... }:
let
  # List of devices for Btrfs scrub and SMART monitoring
  btrfsDevices = [ "/" "/mnt/emet" ];  # Adjust paths as needed
  smartDevices = [ "/dev/disk/by-id/usb-WD_My_Passport_2626_575839324435334152364A43-0:0" ];  # Adjust device names as needed

  # Create a script for the Btrfs scrub status check
  smartStatusScript = pkgs.writeShellScript "smart-mon-status" ''
    #!/usr/bin/env bash
    device="$1"

    sleep 5
    while true; do
      smart_output=$(${pkgs.smartmontools}/bin/smartctl -a $device)
      if ! echo "$smart_output" | grep -q "test remaining"; then
        break
      fi
      trimmed=$(echo "$smart_output" | grep "test remaining" | ${pkgs.findutils}/bin/xargs)
      echo "$trimmed"
      sleep 600
    done
  '';
in
{
  environment.systemPackages = with pkgs; [
    smartmontools
  ];

  services.smartd = {
    enable = true;
    devices = lib.concatMap (device: [
      { device = device; }
    ]) smartDevices;
  };
#echo -e "Content-Type: text/plain\r\nSubject: Test\r\n\r\nHello World" | tee >(sudo sendmail dom32400@gmail.com)
  systemd = {
    services = lib.mkMerge (lib.concatMap (device: [
      {
        "btrfs-scrub-${lib.replaceStrings ["/"] ["_"] device}" = {
          description = "Btrfs Scrub Monitoring Service for ${device}";
          after = [ "network.target" ];
          serviceConfig = {
            Type = "forking";
            ExecStart = "${pkgs.btrfs-progs}/bin/btrfs scrub start ${device}";
            ExecStop = "${pkgs.bash}/bin/bash -c 'status=$(${pkgs.btrfs-progs}/bin/btrfs scrub status ${device}); echo \"$status\" | grep -q \"Time left\" && ${pkgs.btrfs-progs}/bin/btrfs scrub cancel ${device} || echo \"$status\" && echo -e \"Content-Type: text/plain\\r\\nSubject: BTRFS Scrub Status: ${device}\\r\\n\\r\\n$status\" | ${pkgs.msmtp}/bin/sendmail dom32400@gmail.com'";
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
            Type = "forking";
            ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.smartmontools}/bin/smartctl -t long ${device} && ${smartStatusScript} ${device} &'";
            ExecStop = "${pkgs.bash}/bin/bash -c '${pkgs.smartmontools}/bin/smartctl -X ${device} && status=$(${pkgs.smartmontools}/bin/smartctl -a ${device}); echo \"$status\" && echo -e \"Content-Type: text/plain\\r\\nSubject: SMART Status: ${device}\\r\\n\\r\\n$status\" | ${pkgs.msmtp}/bin/sendmail dom32400@gmail.com'";
          };
          restartIfChanged = true;
        };
      }
    ]) smartDevices);

    timers = lib.mkMerge (lib.concatMap (device: [
      {
        "btrfs-scrub-${lib.replaceStrings ["/"] ["_"] device}" = {
          description = "Monthly Btrfs Scrub Timer for ${device}";
          wantedBy = [ "timers.target" ];
          timerConfig = {
          	OnCalendar = "*-*-01 01:00:00";  # Runs at 1:00 AM on the first of each month
          	Persistent = true;
          	Unit = "btrfs-scrub-${lib.replaceStrings ["/"] ["_"] device}.service";
          };
        };
      }
    ]) btrfsDevices ++ lib.concatMap (device: [
      {
        "smart-monitor-${lib.replaceStrings ["/"] ["_"] device}" = {
          description = "Monthly SMART Test Timer for ${device}";
          wantedBy = [ "timers.target" ];
          timerConfig = {
          	OnCalendar = "*-*-01 04:00:00";  # Runs at 4:00 AM on the first of each month
          	Persistent = true;
          	Unit = "smart-monitor-${lib.replaceStrings ["/"] ["_"] device}.service";
          };
        };
      }
    ]) smartDevices);
  };
}
