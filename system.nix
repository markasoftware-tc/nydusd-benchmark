{ system, nydus, pkgs, lib, ... }:

# We set up minio in a container so that we can more easily use netem. Containerd runs on the host.

let latency = "30ms";
    latencyJitter = "5ms";
    image = "docker.io/pytorch/pytorch";
    make-container = pkgs.writeShellScriptBin "make-container" ''
      set -exuo pipefail
      echo 'Creating bucket'
      ${pkgs.rclone}/bin/rclone mkdir :s3:nydus --s3-provider=Other --s3-endpoint=http://10.99.0.1:6379 --s3-access-key-id=accesskey --s3-secret-access-key=secretkey
      echo 'Converting OCI image to nydus'
      ${nydus.packages.${system}.nydusify}/bin/nydusify convert --source ${image} --target localhost:5000/nydus-test-container --backend-type s3 --backend-config-file ${./backend.json}
    '';
    launch-container = pkgs.writeShellScriptBin "launch-container" ''
      set -exuo pipefail
      echo 'Launching container shell (will remove on exit)'
      ${pkgs.nerdctl}/bin/nerdctl run --snapshotter=nydus -it --rm localhost:4999/nydus-test-container:latest
    '';
    # ^^^ nerdctl always uses http for localhost, so we use the http port
    minio-logs = pkgs.writeShellScriptBin "minio-logs" ''
      machinectl shell minio ${pkgs.minio-client}/bin/mc alias set nydus-minio http://0.0.0.0:6379 accesskey secretkey
      machinectl shell minio ${pkgs.minio-client}/bin/mc admin trace nydus-minio
    '';
    in
{
  virtualisation.vmVariant.virtualisation = {
    # These are options under `virtualisation` that can only be set when in a VM, if provided on a normal nixos build they error out, so have to be in here.
    memorySize = 8192;
    cores = 4;
    graphics = false;
    diskSize = 32 * 1024;
    forwardPorts = [
      {
        from = "host";
        host.port = 2222;
        guest.port = 22;
      }
    ];
  };

  users.users.nydus = {
    isNormalUser = true;
    initialPassword = "password";
    extraGroups = [ "wheel" ];
  };
  services.openssh.enable = true;

  environment.systemPackages = [
    pkgs.nerdctl
    pkgs.docker
    make-container
    launch-container
    minio-logs
  ];

  security.pki.certificates = [ (builtins.readFile ./cert.pem) ];

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
    localAddress = "10.99.0.1";
    hostAddress = "10.99.0.0";
    autoStart = true;

    config = {
      environment.systemPackages = [
        pkgs.minio-client
      ];
      services.minio = {
        enable = true;
        listenAddress = "0.0.0.0:6379";
        secretKey = "secretkey";
        accessKey = "accesskey";
      };
      services.dockerRegistry = {
        enable = true;
        listenAddress = "0.0.0.0";
      };
      networking.firewall.allowedTCPPorts = [ 5000 6379 ];
      system.stateVersion = "25.05";
    };
  };

  # https reverse proxy to the registry
  services.caddy = {
    enable = true;
    virtualHosts."localhost:5000".extraConfig = ''
      reverse_proxy 10.99.0.1:5000
      tls ${./cert.pem} ${./key.pem}
    '';
    globalConfig = ''
      http_port 4999
    '';
  };

  virtualisation.containerd = {
    enable = true;
    configFile = ./containerd-config.toml;
  };

  systemd.services = {
    nydus-snapshotter = {
      wantedBy = [ "multi-user.target" ];
      script = ''
        ${nydus.apps.${system}.containerd-nydus-grpc.program} --config ${./nydus-snapshotter-config.toml} --nydusd-config ${./nydusd-config.json}
      '';
    };
  };

  environment.etc."/containers/policy.json".source = ./container-policy.json;

  nix.settings.experimental-features = "nix-command flakes";

  system.stateVersion = "25.05";
}
