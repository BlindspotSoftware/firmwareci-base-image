{ lib
, buildPythonPackage
, fetchFromGitHub
, setuptools
, dbus-fast
, dbus-python
, pyudev
, packaging
, pandas
, jinja2
, tabulate
, seaborn
, matplotlib
,
}:

buildPythonPackage rec {
  pname = "amd-debug-tools";
  version = "0.2.9";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "superm1";
    repo = "amd-debug-tools";
    rev = version;
    sha256 = "sha256-RrXo1045M+2D/xycO74ExeFhqBJL9mE6OPy0MSLmEFc=";
  };

  build-system = [
    setuptools
  ];

  postPatch = ''
    # Replace dynamic versioning with static version
    substituteInPlace pyproject.toml \
      --replace-fail 'dynamic = ["version"]' 'version = "${version}"' \
      --replace-fail ', "setuptools-git-versioning>=2.0,<3"' ""

    # Remove the git-versioning configuration section
    sed -i '/\[tool\.setuptools-git-versioning\]/,/^$/d' pyproject.toml
  '';

  dependencies = [
    dbus-fast
    dbus-python
    pyudev
    packaging
    pandas
    jinja2
    tabulate
    seaborn
    matplotlib
  ];

  # Tests require additional setup
  doCheck = false;

  # Skip runtime dependency check (cysystemd is optional)
  dontCheckRuntimeDeps = true;

  meta = with lib; {
    description = "AMD debug tools for firmware development";
    homepage = "https://github.com/superm1/amd-debug-tools";
    license = licenses.mit;
  };
}
