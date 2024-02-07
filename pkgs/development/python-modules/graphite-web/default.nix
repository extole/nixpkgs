{ lib
, stdenv
, buildPythonPackage
, python
, cairocffi
, django
, django-tagging
, fetchFromGitHub
, fetchpatch
, gunicorn
, mock
, pyparsing
, python-memcached
, pythonOlder
, pytz
, six
, txamqp
, urllib3
, whisper
}:

buildPythonPackage rec {
  pname = "graphite-web";
  version = "0ec7201c42ac2c14485c4c7eaab8a644082dc687";
  format = "setuptools";

  disabled = pythonOlder "3.7";

  src = fetchFromGitHub {
    owner = "graphite-project";
    repo = pname;
    rev = version;
    hash = "sha256-gbPsg5w+Vtc6MSiNzTAz+9wxUL+KEnE67dlamYHhzww=";
  };

  propagatedBuildInputs = [
    cairocffi
    django
    django-tagging
    gunicorn
    pyparsing
    python-memcached
    pytz
    six
    txamqp
    urllib3
    whisper
  ];

  postPatch = ''
    substituteInPlace setup.py \
      --replace "Django>=1.8,<3.1" "Django" \
      --replace "django-tagging==0.4.3" "django-tagging"
  '';

  # Carbon-s default installation is /opt/graphite. This env variable ensures
  # carbon is installed as a regular Python module.
  GRAPHITE_NO_PREFIX = "True";

  preConfigure = ''
    substituteInPlace webapp/graphite/settings.py \
      --replace "join(WEBAPP_DIR, 'content')" "join('$out', 'webapp', 'content')"
  '';

  checkInputs = [ mock ];
  checkPhase = ''
    runHook preCheck

    pushd webapp/
    # avoid confusion with installed module
    rm -r graphite
    # redis not practical in test environment
    substituteInPlace tests/test_tags.py \
      --replace test_redis_tagdb _dont_test_redis_tagdb

    DJANGO_SETTINGS_MODULE=tests.settings ${python.interpreter} manage.py test
    popd

    runHook postCheck
  '';

  pythonImportsCheck = [
    "graphite"
  ];

  meta = with lib; {
    description = "Enterprise scalable realtime graphing";
    homepage = "http://graphiteapp.org/";
    license = licenses.asl20;
    maintainers = with maintainers; [ offline basvandijk ];
  };
}
