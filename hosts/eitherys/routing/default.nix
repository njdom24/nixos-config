{ inputs, outputs, config, pkgs, lib, ... }:
{
  imports =
    [
      ./wireguard.nix
    ];

  security.acme = {
    acceptTerms = true;
    defaults = {
      email = "dom32400@gmail.com";
      webroot = "/var/lib/acme/acme-challenge";
    };
    certs."daminop.duckdns.org" = {
      extraDomainNames = [ "suwayomi.daminop.duckdns.org" "romm.daminop.duckdns.org" ];
    };
  };

  services = {
    fail2ban.enable = true;
    ddclient = {
      enable = true;
      usev4 = "web, web=wtfismyip.com/text";
      usev6 = config.services.ddclient.usev4;
      protocol = "duckdns";
      domains = [ "daminop" ];
      passwordFile = "/var/secrets/duckdns";
    };
  
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
		"daminop.duckdns.org" = {
          forceSSL = true;  # Enforce HTTPS redirection
          enableACME = true; # Auto-renew cert
          #acmeRoot = null; # Commenting this fixed a temp issue, unsure why...
          listen = [
            { addr = "0.0.0.0"; port = 80; }
            { addr = "[::]"; port = 80; }
          ];
          locations = {
            "/" = {
              return = "301 https://$server_name$request_uri";
            };
            "/.well-known/acme-challenge".root = config.security.acme.defaults.webroot;
          };
        };

        "suwayomi.daminop.duckdns.org" = {
           useACMEHost = "daminop.duckdns.org";
      	   sslCertificate = "/var/lib/acme/daminop.duckdns.org/fullchain.pem";
      	   sslCertificateKey = "/var/lib/acme/daminop.duckdns.org/key.pem";
      	   acmeRoot = null;
      	   forceSSL = true;
           listen = [
           	 { addr = "0.0.0.0"; port = 443; ssl = true; }
      	     { addr = "[::]"; port = 443; ssl = true; }
           ];

           locations."/" = {
      	     proxyPass = "http://127.0.0.1:4568";
      	     proxyWebsockets = true;
      	     extraConfig = ''
      	       proxy_set_header Host $host;
      	       proxy_set_header X-Forwarded-Host $http_host;
      	       proxy_set_header X-Forwarded-For $remote_addr;
      	     '';
      	   };
        };

        "romm.daminop.duckdns.org" = {
           useACMEHost = "daminop.duckdns.org";
      	   sslCertificate = "/var/lib/acme/daminop.duckdns.org/fullchain.pem";
      	   sslCertificateKey = "/var/lib/acme/daminop.duckdns.org/key.pem";
      	   acmeRoot = null;
      	   forceSSL = true;
           listen = [
           	 { addr = "0.0.0.0"; port = 443; ssl = true; }
      	     { addr = "[::]"; port = 443; ssl = true; }
           ];

           locations."/" = {
             #proxyPass = "http://127.0.0.1:8597";
      	     proxyWebsockets = true;
      	     extraConfig = ''
      	       proxy_pass http://127.0.0.1:8597; # setting proxyPass option breaks; unsure why
      	       proxy_set_header Host $host;
      	       proxy_set_header X-Forwarded-Host $http_host;
      	       proxy_set_header X-Forwarded-For $remote_addr;
      	       proxy_set_header X-Forwarded-Server $host;
      	       proxy_cookie_path / "/; Secure";
      	     '';
      	   };
        };

      	"daminop.duckdns.org-ssl" = {
      	 useACMEHost = "daminop.duckdns.org";
      	 acmeRoot = null; # Inherit from security.acme.webroot
      	 sslCertificate = "/var/lib/acme/daminop.duckdns.org/fullchain.pem";
      	 sslCertificateKey = "/var/lib/acme/daminop.duckdns.org/key.pem";
      	 forceSSL = true;
      	 
      	 listen = [
      	   { addr = "0.0.0.0"; port = 443; ssl = true; }
      	   { addr = "[::]"; port = 443; ssl = true; }
      	 ];

      	 locations."/".extraConfig = "return 404;";
         locations."/.well-known/acme-challenge".root = config.security.acme.defaults.webroot;

      	 extraConfig = ''
          error_page 401 403 404 /404.html;
          # Deny access to .htaccess files
          location ~ /\.ht {
            deny all;
          }
          # Proxy configurations
          location /jellyfin/ {
            proxy_pass http://127.0.0.1:8096;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $http_connection;
            proxy_buffering off;
          }
          location = /qbt {
          	return 301 /qbt/;
          }
          location ~ /qbt(.*)$ {
            proxy_pass http://127.0.0.1:43000;
            rewrite /qbt(.*) $1 break;
            proxy_http_version 1.1;
            proxy_set_header Host 127.0.0.1:43000;
            proxy_set_header X-Forwarded-Host $http_host;
            proxy_set_header X-Forwarded-For $remote_addr;
            proxy_cookie_path / "/; Secure";
          }
          location /sonarr/ {
            proxy_pass http://127.0.0.1:8989;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
          location /radarr/ {
            proxy_pass http://127.0.0.1:7878;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection $http_connection;
          }
          location /lazylibrarian/ {
            proxy_pass http://127.0.0.1:5299;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
          location /prowlarr/ {
            proxy_pass http://127.0.0.1:9696;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
          location /bazarr/ {
            proxy_pass http://127.0.0.1:6767;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
          location /komga/ {
            proxy_pass http://127.0.0.1:25600;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
          location /kavita/ {
            proxy_pass http://127.0.0.1:5000;
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          }
          location = /suwayomi {
          	return 301 /suwayomi/;
          }
          location /suwayomi/ {
            return 301 https://suwayomi.daminop.duckdns.org$request_uri;
          }
          location = /romm {
          	return 301 /romm/;
          }
          location /romm/ {
            return 301 https://romm.daminop.duckdns.org;
          }
        '';
      	};

      	# Fixes security.acme.certs.extraDomainNames (See https://github.com/NixOS/nixpkgs/issues/180980)
        "defaultDummy404" = {
          default = true;
          serverName = "_";
          locations."/".extraConfig = "return 404;";
          locations."/.well-known/acme-challenge".root = config.security.acme.defaults.webroot;
        };
      };
    };
  };

  # Sourced from https://nixos.wiki/wiki/Fail2ban
  environment.etc = {
    # Defines a filter that detects URL probing by reading the Nginx access log
    "fail2ban/filter.d/nginx-url-probe.local".text = pkgs.lib.mkDefault (pkgs.lib.mkAfter ''
      [Definition]
      failregex = ^<HOST>.*(GET /(wp-|admin|boaform|phpmyadmin|\.env|\.git)|\.(dll|so|cfm|asp)|(\?|&)(=PHPB8B5F2A0-3C92-11d3-A3A9-4C7B08C10000|=PHPE9568F36-D428-11d2-A769-00AA001ACF42|=PHPE9568F35-D428-11d2-A769-00AA001ACF42|=PHPE9568F34-D428-11d2-A769-00AA001ACF42)|\\x[0-9a-zA-Z]{2})
    '');
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
