# Nydusd benchmark

1. Install [Nix](https://nixos.org) on a Linux box. You don't need NixOS.
2. Run `./build-and-run-vm.sh` to launch a VM running nydus snapshotter, containerd, and minio set up with 30ms network delay between minio and containerd.
3. Inside the VM, log in with `nydus` as username and `password` as password.
4. Run `create-container` to create a Nydus image with many small files and a few large ones, and write it to a local registry.
5. Run the various `benchmark-*` scripts to run access speed benchmarks.
6. To kill the VM, run `pkill qemu` from another terminal (though be careful, it might kill other VMs too).
7. If you want to reset the VM state (you'll have to run `create-container` again), delete the `.qcow2` files created in PWD.
