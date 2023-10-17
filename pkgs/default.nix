{ pkgs, ... }:

{
  glauth = pkgs.callPackage ./glauth.nix { };
}
