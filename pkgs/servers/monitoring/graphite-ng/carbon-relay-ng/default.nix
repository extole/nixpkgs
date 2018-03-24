{ stdenv, buildGoPackage, fetchFromGitHub, makeWrapper }:

buildGoPackage rec {
  name = "carbon-relay-ng-${version}";
  version = "0.9.4";
  goPackagePath = "github.com/graphite-ng/carbon-relay-ng";

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
  '';

  src = fetchFromGitHub {
    owner = "graphite-ng";
    repo = "carbon-relay-ng";
    rev = "v${version}";
    sha256 = "0nf5gq6jyp3v80ngqp1jfk26d1fm617sqnk78qnn25rjnd0lm2hr";
  };

  meta = with stdenv.lib; {
    homepage = https://github.com/graphite-ng/carbon-relay-ng/;
    description = "Fast carbon relay+aggregator with admin interfaces for making changes online - production ready";
    license = with licenses; [ mit ];
    maintainers = [ maintainers.polynomial ];
  };
}
