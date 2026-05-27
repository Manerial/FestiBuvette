flutter build apk --split-per-abi

$src = "build\app\outputs\flutter-apk"
$out = "APK"

New-Item -ItemType Directory -Force $out | Out-Null

$renames = @{
    "app-arm64-v8a-release.apk"   = "FestiBuvette_64.apk"
    "app-armeabi-v7a-release.apk" = "FestiBuvette_32.apk"
    "app-x86_64-release.apk"      = "FestiBuvette_x86_64.apk"
}

foreach ($entry in $renames.GetEnumerator()) {
    $origin = Join-Path $src $entry.Key
    $dest   = Join-Path $out $entry.Value
    if (Test-Path $origin) {
        Copy-Item $origin $dest -Force
        Write-Host "[OK] APK\$($entry.Value)"
    }
}
