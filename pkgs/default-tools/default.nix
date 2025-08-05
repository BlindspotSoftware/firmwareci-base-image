{ lib
, fetchurl
, stdenv
, gzip
}:

let
  pname = "default-tools";
  version = "v2";
  sha256 = "sha256-8PTGQ4g3N/ZnfJ+bhRYGO94jsIf6T+WVFe6NtLiDZ+8=";
in

stdenv.mkDerivation {
  inherit pname version;

  src = fetchurl {
    url = "https://fwci-assets.s3.eu-central-1.amazonaws.com/default-tools/default-tools-v2.tar.gz";
    inherit sha256;
  };

  nativeBuildInputs = [ gzip ];

  # Extract the files to $out/ instead of $out/default-tools
  installPhase = ''
    mkdir -p $out
        
    # Extract directly from src to destination
    gzip -dc $src > extracted.tar
    tar -xf extracted.tar -C $out
        
    # Make all binaries executable
    find $out -type f -exec chmod +x {} \;
  '';

  meta = with lib; {
    description = "Default FirmwareCI tools package. These tools are required for some of the FirmwareCI teststeps.";
  };
}
