{ lib, stdenv, fetchFromGitHub, buildGoModule }:

buildGoModule rec {
  pname = "glauth";
  version = "2.3.0";

  src = fetchFromGitHub {
    owner = "glauth";
    repo = "glauth";
    rev = "v${version}";
    hash = "sha256-XYNNR3bVLNtAl+vbGRv0VhbLf+em8Ay983jqcW7KDFU=";
  };

  vendorHash = "sha256-GHn2xRJLayJCd08nj6seT1z7tvrhyri9aSpDUiR3YIs=";

  modRoot = "v2";

  postPatch = ''
    pattern='replace github.com/hydronica/toml => ./vendored/toml'
    replace='replace github.com/hydronica/toml => ./_vendored/toml'
    if grep -q "$pattern" ${modRoot}/go.mod; then
      mv ${modRoot}/vendored ${modRoot}/_vendored
      sed -e "s,$pattern,$replace," -i ${modRoot}/go.mod
    else
      echo "error: couldn't fine \"$pattern\" in ${modRoot}/go.mod -- please update Nix expr" >&2
      exit 1
    fi
  '';

  GOWORK = "off";

  doCheck = false;
}
