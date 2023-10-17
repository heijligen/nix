{ pkgs, ... }:

{
  pkgs = import ./pkgs { inherit pkgs; };
  modules = import ./modules {inherit pkgs; };
}
