# Resizes the raw captures in docs/ui-audit/shots into the files the landing page uses (docs/assets/devices).
#   powershell -ExecutionPolicy Bypass -File tool/make_device_assets.ps1
Add-Type -AssemblyName System.Drawing
$src = 'docs/ui-audit/shots'; $dst = 'docs/assets/devices'
function Save($in, $out, $w, $cropTop = 0) {
  $img = [Drawing.Image]::FromFile((Resolve-Path "$src/$in").Path)
  $h = [int](($img.Height - $cropTop) * $w / $img.Width)
  $bmp = New-Object Drawing.Bitmap $w, $h
  $g = [Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = 'HighQualityBicubic'; $g.SmoothingMode = 'HighQuality'; $g.PixelOffsetMode = 'HighQuality'
  $g.DrawImage($img, [Drawing.Rectangle]::new(0, 0, $w, $h), 0, $cropTop, $img.Width, $img.Height - $cropTop, 'Pixel')
  $bmp.Save((Join-Path (Get-Location) "$dst/$out"), [Drawing.Imaging.ImageFormat]::Png)
  $img.Dispose(); $bmp.Dispose()
  "{0}  {1}x{2}  {3} KB" -f $out, $w, $h, [int]((Get-Item "$dst/$out").Length / 1KB)
}
Save 'win-1440-pdf.png'   'windows-desktop.png'  1280
Save 'win-1280-docx.png'  'macos-laptop.png'     1200 31   # the native title bar is dropped; the page draws the laptop frame
Save 'tablet-pdf.png'     'android-tablet.png'   1280
Save 'fold-pdf.png'       'android-foldable.png' 1104
Save 'phone-pdf.png'      'android-phone.png'    540
