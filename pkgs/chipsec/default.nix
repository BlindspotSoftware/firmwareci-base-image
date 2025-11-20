{ lib
, stdenv
, fetchFromGitHub
, kernel ? null
, elfutils
, nasm
, python3
, withDriver ? false
, makeWrapper
,
}:

python3.pkgs.buildPythonApplication rec {
  pname = "chipsec";
  version = "1.13.17";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "chipsec";
    repo = "chipsec";
    tag = version;
    hash = "sha256-8QiFIk9bq/yX26jw9aOd6wtt+WDUwfLBUVD5hL30RKE=";
  };

  patches = [
    ./log-path.diff
  ];

  KSRC = lib.optionalString withDriver "${kernel.dev}/lib/modules/${kernel.modDirVersion}/build";

  nativeBuildInputs = [
    nasm
    makeWrapper
  ]
  ++ lib.optionals (lib.meta.availableOn stdenv.buildPlatform elfutils) [
    elfutils
  ]
  ++ lib.optionals withDriver kernel.moduleBuildDependencies;

  build-system = [ python3.pkgs.setuptools ];
  dependencies = with python3.pkgs; [
    brotli
  ];

  # Marker file preventing driver from being built
  preBuild = lib.optionals (!withDriver) ''
    touch README.NO_KERNEL_DRIVER
  '';

  # Replace module_ids.json with a symlink to a writable location
  postInstall =
    let
      module_ids = "/var/lib/chipsec/module_ids.json";
      module_ids_default = "${placeholder "out"}/${python3.pkgs.python.sitePackages}/chipsec/library/module_ids_default.json";
      createModuleIdsFile = ''
        if [ ! -e ${module_ids} ]; then
          mkdir -p $(dirname ${module_ids})
          cp ${module_ids_default} ${module_ids}
        fi
      '';
    in
    ''
      # Rename original module_ids.json to module_ids_default.json
      mv $out/${python3.pkgs.python.sitePackages}/chipsec/library/module_ids.json \
         $out/${python3.pkgs.python.sitePackages}/chipsec/library/module_ids_default.json

      # Create symlink to writable location
      ln -s ${module_ids} $out/${python3.pkgs.python.sitePackages}/chipsec/library/module_ids.json

      # Wrap chipsec_main to ensure the writable file exists
      mv $out/bin/chipsec_main $out/bin/.chipsec_main-wrapped
      makeWrapper $out/bin/.chipsec_main-wrapped $out/bin/chipsec_main \
        --run '${createModuleIdsFile}'
    '';

  nativeCheckInputs = with python3.pkgs; [
    distro
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "chipsec"
  ];

  meta = with lib; {
    description = "Platform Security Assessment Framework";
    longDescription = ''
      CHIPSEC is a framework for analyzing the security of PC platforms
      including hardware, system firmware (BIOS/UEFI), and platform components.
      It includes a security test suite, tools for accessing various low level
      interfaces, and forensic capabilities. It can be run on Windows, Linux,
      Mac OS X and UEFI shell.
    '';
    license = licenses.gpl2Only;
    homepage = "https://github.com/chipsec/chipsec";
    maintainers = with maintainers; [
      johnazoidberg
      erdnaxe
    ];
    platforms = if withDriver then [ "x86_64-linux" ] else with lib.platforms; linux ++ darwin;
    # https://github.com/chipsec/chipsec/issues/1793
    broken = withDriver && kernel.kernelOlder "5.4" && kernel.isHardened;
  };
}
