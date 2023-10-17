{ config, lib, pkgs, ... }:

let
  cfg = config.programs.shikane;

  settingsFormat = pkgs.formats.toml { };
  settingsFile = if cfg.settings == null
    then null
    else settingsFormat.generate "config.toml" cfg.settings;
in
{
  options.programs.shikane = {
    enable = lib.mkEnableOption (lib.mdDoc "shikanle");

    package = lib.mkPackageOptionMD pkgs "shikane" { };

    settings = lib.mkOption {
      type = lib.types.nullOr settingsFormat.type;
      default = null;
      description = lib.mdDoc ''
        If set start the shikane systemd user service with this config.
        Otherwise use the config in $XDG_CONFIG_HOME. See `man 5 shikane for configuration.
      '';
      example = {
        profile = [ {
          name = "default";
          output = [ {
            name = "eDP-1";
            enable = true;
          } ];
        } {
          name = "docking";
          exec = [ ''notify-send "shikane" "profile $SHIKANE_PROFILE_NAME active"'' ];
          output = [{
            match = "eDP-1";
            enable = false;
          } {
            match = "/DP-[1-9]/";
            enable = true;
          }];
        } ];
      };
    };

    environment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = lib.mkDoc ''
        Additional environment variables to provide to shikane.
      '';
      example = {
        SHIKANE_LOG = "debug";
      };
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = [ pkgs.libnotify ];
      description = lib.mdDoc ''
        List of extra packages to include in shikanes search path
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.shikane = {
      description = "shikane - dynamic output configuration";
      wantedBy = [ "graphical-session.target" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${cfg.package}/bin/shikane"
          + lib.optionalString (settingsFile != null) " -c ${settingsFile}";
      };
      environment = cfg.environment;
      path = cfg.extraPackages;
    };
  };
}
