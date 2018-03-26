{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.graphite-ng;
  writeTextOrNull = f: t: mapNullable (pkgs.writeTextDir f) t;

  configDir = pkgs.buildEnv {
    name = "graphite-config";
    paths = lists.filter (el: el != null) [
      (writeTextOrNull "carbon.conf" cfg.carbon.config)
      (writeTextOrNull "storage-aggregation.conf" cfg.carbon.storageAggregation)
      (writeTextOrNull "storage-schemas.conf" cfg.carbon.storageSchemas)
      (writeTextOrNull "blacklist.conf" cfg.carbon.blacklist)
      (writeTextOrNull "whitelist.conf" cfg.carbon.whitelist)
      (writeTextOrNull "rewrite-rules.conf" cfg.carbon.rewriteRules)
      (writeTextOrNull "relay-rules.conf" cfg.carbon.relayRules)
      (writeTextOrNull "aggregation-rules.conf" cfg.carbon.aggregationRules)
    ];
  };

  carbonOpts = name: with config.ids; ''
    --nodaemon --syslog --prefix=${name} --pidfile /run/${name}/${name}.pid ${name}
  '';

  mkPidFileDir = name: ''
    mkdir -p /run/${name}
    chmod 0700 /run/${name}
    chown -R graphite:graphite /run/${name}
  '';

  carbonEnv = {
    PYTHONPATH = let
      cenv = pkgs.python.buildEnv.override {
        extraLibs = [ pkgs.python27Packages.carbon ];
      };
      cenvPack =  "${cenv}/${pkgs.python.sitePackages}";
    # opt/graphite/lib contains twisted.plugins.carbon-cache
    in "${cenvPack}/opt/graphite/lib:${cenvPack}";
    GRAPHITE_ROOT = dataDir;
    GRAPHITE_CONF_DIR = configDir;
    GRAPHITE_STORAGE_DIR = dataDir;
  };

in {

  ###### interface

  options.services.graphite-ng = {
    dataDir = mkOption {
      type = types.path;
      default = "/var/db/graphite";
      description = ''
        Data directory for graphite.
      '';
    };

    relay = {
      enable = mkOption {
        description = ''
          Enable the carbon relay service.

        '';
        default = false;
        type = types.bool;
      };

      package = mkOption {
        description = "Package to use for graphite api.";
        default = pkgs.carbon-relay-ng;
        defaultText = "pkgs.carbon-relay-ng";
        type = types.package;
      };

      storageSchemasConf = mkOption {
        description = "Storage Schema Configuration.";
        default = ''
          [default]
            pattern = .*
            retentions = 10s:1d
        '';
        example = ''
          [default]
            pattern = .*
            retentions = 10s:1d
        '';
        type = types.lines;
      };



      config = mkOption {
        description = "Configuration for carbon-relay-ng.";
        default = ''
          ## Global settings ##
          instance = "${HOST}"
          max_procs = 2
          
          spool_dir = "spool"
          pid_file = "carbon-relay-ng.pid"
          
          ## Logging ##
          # one of critical error warning notice info debug
          # see docs/logging.md for level descriptions
          log_level = "notice"
          
          # you can also validate that each series has increasing timestamps
          validate_order = false
          
          # How long to keep track of invalid metrics seen
          # Useful time units are "s", "m", "h"
          bad_metrics_max_age = "24h"
          
          ## Inputs ##
          
          ### plaintext Carbon ###
          listen_addr = "0.0.0.0:2003"
          
          ### Pickle Carbon ###
          pickle_addr = "0.0.0.0:2013"
          
        '';
        example = ''
          ## Global settings ##
          instance = "${HOST}"
          max_procs = 2
          ### plaintext Carbon ###
          listen_addr = "0.0.0.0:2003"
          ### Pickle Carbon ###
          pickle_addr = "0.0.0.0:2013"
        '';
        type = types.lines;
      };
    };

  ###### implementation

  config = mkMerge [
    (mkIf cfg.graphite-ng.relay.enable {
      systemd.services.carbonRelayNg = let name = "carbon-relay-ng"; in {
        # https://github.com/graphite-ng/carbon-relay-ng/blob/master/examples/carbon-relay-ng.service
        description = "Carbon Data Relay Next Generation";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        environment = carbonEnv;
        serviceConfig = {
          ExecStart = "${pkgs.carbon-relay-ng}/bin/carbon-relay-ng ${carbonOpts name}";
          Type=simple
          Restart=on-failure
          WorkingDirectory=/run/carbon-relay-ng
          User = "graphite";
          Group = "graphite";
          PIDFile="/run/${name}/${name}.pid";
        };
        preStart = mkPidFileDir name;
      };
    })

    (mkIf (cfg.carbon.enableCache || cfg.carbon.enableAggregator || cfg.carbon.enableRelay) {
      environment.systemPackages = [
        pkgs.pythonPackages.carbon
      ];
    })


    (mkIf cfg.carbon.relay.enable {
      users.extraUsers = singleton {
        name = "graphite";
        uid = config.ids.uids.graphite;
        description = "Graphite daemon user";
        home = dataDir;
      };
      users.extraGroups.graphite.gid = config.ids.gids.graphite;
    })
  ];
}
