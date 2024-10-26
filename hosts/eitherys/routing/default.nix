{ inputs, outputs, config, pkgs, lib, ... }:
let
  subdomain = lib.strings.removeSuffix "\n" (builtins.readFile /var/secrets/subdomain);
  domain = "${subdomain}.duckdns.org";
in
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
    certs."${domain}" = {
      extraDomainNames = [ "suwayomi.${domain}" "romm.${domain}" ];
    };
  };

  services = {
    ddclient = {
      enable = true;
      use = "web, web=wtfismyip.com/text";
      protocol = "duckdns";
      domains = [ "${subdomain}" ];
      passwordFile = "/var/secrets/duckdns";
    };
  
    nginx = {
      enable = true;
      recommendedProxySettings = true;
      virtualHosts = {
		"${domain}" = {
          forceSSL = true;  # Enforce HTTPS redirection
          enableACME = true; # Auto-renew cert
          acmeRoot = null;
          listen = [
            { addr = "0.0.0.0"; port = 80; }
            { addr = "[::]"; port = 80; }
          ];
          locations = {
            "/" = {
              return = "301 https://$server_name$request_uri";
            };
          };
        };

        "suwayomi.${domain}" = {
           useACMEHost = "${domain}";
      	   sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
      	   sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
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

        "romm.${domain}" = {
           useACMEHost = "${domain}";
      	   sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
      	   sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
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

      	"${domain}-ssl" = {
      	 useACMEHost = "${domain}";
      	 acmeRoot = null; # Inherit from security.acme.webroot
      	 sslCertificate = "/var/lib/acme/${domain}/fullchain.pem";
      	 sslCertificateKey = "/var/lib/acme/${domain}/key.pem";
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
            return 301 https://suwayomi.${domain}$request_uri;
          }
          location = /romm {
          	return 301 /romm/;
          }
          location /romm/ {
            return 301 https://romm.${domain};
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

  networking.firewall.allowedTCPPorts = [
    80
    443
  ];
}
