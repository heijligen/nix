{ pkgs, ... }:

{
  imports = [
    ./dendrite.nix
    ./shikane.nix
  ];
}
