# Personal Nix modules and packages

```nixos
let
  # nixos-unstable
  heijligen = import <heijligen> { };
  
  # nixos-stable
  pkgsUnstable = import <nixos-unstable> { };
  heijligen = import <heijligen> { pkgs = pkgsUnstable };
in
{
  imports = [
    heijligen.modules
  ];
  
  environment.systemPackages = [
    pkgs.htop
    heijligen.pkgs.glauth
  ]
}
```
