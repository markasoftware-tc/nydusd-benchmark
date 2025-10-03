{ system, nydus, pkgs, lib, ... }:

# We set up minio in a container so that we can more easily use netem. Containerd runs on the host.

let minioAddress = "10.99.0.1";
    latency = "30ms";
    latencyJitter = "5ms";
in
{
  virtualisation.vmVariant.virtualisation = {
    memorySize = 2048;
    cores = 4;
    graphics = false;
  };

  users.users.nydus = {
    isNormalUser = true;
    initialPassword = "password";
    extraGroups = [ "wheel" ];
  };

  environment.systemPackages = [
    pkgs.nerdctl
  ];

  networking.useNetworkd = true;
  systemd.network = {
    enable = true;
    networks."50-ve-minio" = {
      name = "ve-minio";
      networkEmulatorConfig = {
        DelaySec = latency;
        DelayJitterSec = latencyJitter;
        Parent = "root";
      };
    };
  };

  containers.minio = {
    privateNetwork = true;
    localAddress = minioAddress;
    autoStart = true;

    config = {
      services.minio = {
        enable = true;
        secretKey = "secretkey";
        accessKey = "accesskey";
      };
    };
  };

  virtualisation.containerd = {
    enable = true;
    configFile = ./containerd-config.toml;
  };

  systemd.tmpfiles.settings.nydus-snapshotter-work."/tmp/nydus-snapshotter-work" = { f = {}; };

  systemd.services = {
    nydus-snapshotter = {
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${nydus.apps.${system}.containerd-nydus-grpc.program} --config ${./nydus-snapshotter-config.toml} --nydusd-config ${./nydusd-config.json}
      '';
    };
  };

  system.stateVersion = "25.05";
}
