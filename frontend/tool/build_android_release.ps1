$ErrorActionPreference = 'Stop'

$env:PUB_CACHE = 'D:\flutter_pub_cache'
$env:GRADLE_USER_HOME = 'D:\gradle_home'

flutter.bat pub get
if ($LASTEXITCODE -ne 0) {
  exit $LASTEXITCODE
}

flutter.bat build apk --release
exit $LASTEXITCODE
