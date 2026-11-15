# Renders tool/feature_graphic.html to the 1024x500 Play feature graphic with
# headless Edge (2x, then downscaled for crisp edges).
#   powershell -ExecutionPolicy Bypass -File tool/render_feature_graphic.ps1
Add-Type -AssemblyName System.Drawing
$repo = Resolve-Path (Join-Path $PSScriptRoot '..')
$html = Join-Path $repo 'tool/feature_graphic.html'
$out = Join-Path $repo 'fastlane/metadata/android/en-US/images/featureGraphic.png'
$tmp = Join-Path ([IO.Path]::GetTempPath()) 'featureGraphic@2x.png'

$edge = (Get-Command msedge -ErrorAction SilentlyContinue).Source
if (-not $edge) { $edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe' }
& $edge --headless --disable-gpu --hide-scrollbars --force-device-scale-factor=2 `
  --screenshot="$tmp" --window-size=1024,500 "file:///$($html -replace '\\','/')" 2>&1 | Out-Null

$src = [Drawing.Image]::FromFile($tmp)
$dst = New-Object Drawing.Bitmap 1024, 500
$g = [Drawing.Graphics]::FromImage($dst)
$g.InterpolationMode = 'HighQualityBicubic'
$g.DrawImage($src, 0, 0, 1024, 500)
$g.Dispose(); $src.Dispose()
$dst.Save($out, [Drawing.Imaging.ImageFormat]::Png); $dst.Dispose()
"Wrote $out"
