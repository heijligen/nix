{ config, lib, pkgs, ... }:

let
  cfg = config.services.dendrite-heijligen;
  settingsFormat = pkgs.formats.yaml { };
  settingsFile = settingsFormat.generate "dendrite.yaml" cfg.settings;
in

{
  options.services.dendrite-heijligen = {
    enable = lib.mkEnableOption (lib.mdDoc "matrix.org dendrite");

    package = lib.mkPackageOptionMD pkgs "dendrite" { };

    user = lib.mkOption {
      type = lib.types.str;
      default = "dendrite";
      description = lib.mdDoc ''
        User account under which dendrite runs.
      '';
    };

    group = lib.mkOption {
      type = lib.types.str;
      default = "dendrite";
      description = lib.mdDoc ''
        Group account under which dendrite runs.
      '';
    };

    settings = lib.mkOption {
      type = settingsFormat.type;
      default = {};
      description = lib.mdDoc ''
        Configuration for dendrite.
      '';
    };

    listen = {
      socket = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = lib.mdDoc "";
        };
        path = lib.mkOption {
          type = lib.types.str;
          default = "/run/dendrite/dendrite.sock";
          description = lib.mdDoc "";
        };
        mode = lib.mkOption {
          type = lib.types.str;
          default = "755";
          description = lib.mdDoc "";
        };
      };
      http = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = lib.mdDoc "";
        };
        address = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = lib.mdDoc "";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8008;
          description = lib.mdDoc "";
        };
      };
      https = {
        enable = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = lib.mdDoc "";
        };
        address = lib.mkOption {
          type = lib.types.str;
          default = cfg.listen.http.address;
          description = lib.mdDoc "";
        };
        port = lib.mkOption {
          type = lib.types.port;
          default = 8448;
          description = lib.mdDoc "";
        };
        tls = {
          cert = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = lib.mdDoc "";
          };
          key = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = lib.mdDoc "";
          };
        };
      };
    };

    localDatabase = lib.mkOption {
      type = lib.types.enum [ "none" "sqlite" "postgresql" ];
      default = "none";
      description = lib.mdDoc "";
    };

    openRegistration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = lib.mdDoc "";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [ {
      assertion = cfg.listen.socket.enable -> !cfg.listen.http.enable && !cfg.listen.https.enable;
      message = "Dendrite cannot use socket and http[s] at the same time.";
    }{
      assertion = cfg.listen.https.enable -> (cfg.listen.https.cert != null && cfg.listen.https.key != null);
      message = "To use https set the path to the tls certificate and key.";
    }{
      assertion = cfg.settings.global.server_name or null != null;
      message = "Dendrite must have a server_name.";
    }{
      assertion = cfg.settings.global.private_key or null != null;
      message = "Dendrite must have a private_key.";
    } ];

    users.users = lib.optionalAttrs (cfg.user == "dendrite") {
      dendrite = {
        home = "/var/lib/dendrite";
        group = cfg.group;
        isSystemUser = true;
      };
    };

    users.groups = lib.optionalAttrs (cfg.group == "dendrite") {
      dendrite = { };
    };

    services.postgresql = lib.mkIf (cfg.localDatabase == "postgresql") {
      enable = true;
      ensureDatabases = [
        "dendrite"
      ];
      ensureUsers = [{
        name = cfg.user;
        ensurePermissions = {
          "DATABASE dendrite" = "ALL PRIVILEGES";
        };
      }];
    };

    services.dendrite-heijligen.settings = {
      version = lib.mkOptionDefault 2;
      global = {
        database.connection_string = lib.mkIf (cfg.localDatabase == "postgresql") (lib.mkForce "postgresql:///dendrite?host=/run/postgresql");
        metrics.enable = lib.mkOptionDefault false;
      };
      tracing = {
        enable = lib.mkOptionDefault false;
      };
      logging = lib.mkOptionDefault [ ];
      key_server = {
        database.connection_string = lib.mkIf (cfg.localDatabase == "sqlite") (lib.mkForce "file:key_server.sqlite");
      };
      media_api = {
        base_path = lib.mkOptionDefault "./media_store";
        database.connection_string = lib.mkIf (cfg.localDatabase == "sqlite") (lib.mkForce "file:media_api.sqlite");
      };
      room_server = {
        database.connection_string = lib.mkIf (cfg.localDatabase == "sqlite") (lib.mkForce "file:room_server.sqlite");
      };
      sync_api = {
        database.connection_string = lib.mkIf (cfg.localDatabase == "sqlite") (lib.mkForce "file:sync_api.sqlite");
      };
      user_api = {
        account_database.connection_string = lib.mkIf (cfg.localDatabase == "sqlite") (lib.mkForce "file:user_api_account.sqlite");
      };
      relay_api = {
        database.connection_string = lib.mkIf (cfg.localDatabase == "sqlite") (lib.mkForce "file:relay_api.sqlite");
      };
      mscs = {
        database.connection_string = lib.mkIf (cfg.localDatabase == "sqlite") (lib.mkForce "file:mscs.sqlite");
      };
      federation_api = {
        database.connection_string = lib.mkIf (cfg.localDatabase == "sqlite") (lib.mkForce "file:federation_api.sqlite");
      };
    };

    systemd.services.dendrite = {
      description = "Dendrite Matrix Server";
      after = [ 
        "network.target"
      ] ++ lib.optionals (cfg.localDatabase == "postgrsql") [
        "postgrsql.service"
      ];
      wantedBy = [
        "multi-user.target"
      ] ++ lib.optionals (cfg.localDatabase == "postgresql") [
        "postgresql.service"
      ];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = "~";
        RuntimeDirectory = "dendrite";
        PrivateTmp = true;
        ExecStart = lib.strings.concatStringsSep " " ([
          "${cfg.package}/bin/dendrite"
          "-logtostderr"
          "-config ${settingsFile}"
        ] ++ lib.optionals cfg.listen.http.enable [
          "-http-bind-address ${cfg.listen.http.address}:${toString cfg.listen.http.port}"
        ] ++ lib.optionals cfg.listen.https.enable [
          "-https-bind-address ${cfg.listen.https.address}:${toString cfg.listen.https.port}"
          "-tls-cert $(cat ${cfg.listen.https.cert})"
          "-tls-key $(cat ${cfg.listen.https.key})"
        ] ++ lib.optionals cfg.listen.socket.enable [
          "-unix-socket ${cfg.listen.socket.path}"
          "-unix-socket-permission ${cfg.listen.socket.mode}"
        ] ++ lib.optionals cfg.openRegistration [
          "-really-enable-open-registration"
        ]);
      };
    };
  };
}
