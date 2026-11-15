# Renders tool/play_screenshots.html (#1..#8) to the Play phone screenshots
# (1080x1920) with headless Edge.
#   powershell -ExecutionPolicy Bypass -File tool/render_play_screenshots.ps1
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$html = (Join-Path $repo 'tool/play_screenshots.html') -replace '\\', '/'
$out = Join-Path $repo 'fastlane/metadata/android/en-US/images/phoneScreenshots'
New-Item -ItemType Directory -Force $out | Out-Null
$names = '01_home', '02_pdf', '03_word', '04_excel', '05_markdown', '06_split', '07_files', '08_dark'

$edge = (Get-Command msedge -ErrorAction SilentlyContinue).Source
if (-not $edge) { $edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' }

for ($i = 0; $i -lt $names.Count; $i++) {
  $file = Join-Path $out "$($names[$i]).png"
  & $edge --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
    --screenshot="$file" --window-size=1080,1920 "file:///$html#$($i + 1)" 2>&1 | Out-Null
  "Wrote $file"
}
