#!/bin/sh

nix --extra-experimental-features 'nix-command flakes' run .#nixosConfigurations.default.config.system.build.vm
