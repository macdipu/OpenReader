# Draws the background of the macOS installer window (macos/dmg/background.png): a hint, and an
# arrow from where the app icon sits to where the Applications folder sits. The icon positions are
# the ones make-dmg.sh passes to create-dmg, so change them together.
#
#   powershell -ExecutionPolicy Bypass -File tool/generate_dmg_background.ps1
Add-Type -AssemblyName System.Drawing

$width = 660; $height = 400
$appX = 180; $dropX = 480; $iconY = 190   # window coordinates of the two icon centres
$out = Join-Path $PSScriptRoot '..\macos\dmg\background.png'
New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null

$bmp = New-Object Drawing.Bitmap $width, $height
$g = [Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'

# Soft vertical gradient.
$bg = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(0, 0)), ([Drawing.Point]::new(0, $height)), ([Drawing.ColorTranslator]::FromHtml('#F8FAFD')), ([Drawing.ColorTranslator]::FromHtml('#E9EEF7'))
$g.FillRectangle($bg, 0, 0, $width, $height)

$ink = [Drawing.ColorTranslator]::FromHtml('#0B1220')
$muted = [Drawing.ColorTranslator]::FromHtml('#64748B')
$accent = [Drawing.ColorTranslator]::FromHtml('#2563EB')
$center = New-Object Drawing.StringFormat; $center.Alignment = 'Center'

$title = New-Object Drawing.Font 'Segoe UI Semibold', 20, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$hint = New-Object Drawing.Font 'Segoe UI', 14, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$g.DrawString('Install OpenReader', $title, (New-Object Drawing.SolidBrush $ink), ($width / 2), 44, $center)
$g.DrawString('Drag the app onto the Applications folder', $hint, (New-Object Drawing.SolidBrush $muted), ($width / 2), 76, $center)

# The arrow between the two icons (icons are about 120px wide, so leave room around them).
$from = $appX + 95; $to = $dropX - 95
$pen = New-Object Drawing.Pen $accent, 5
$pen.StartCap = 'Round'; $pen.EndCap = 'Round'
$g.DrawLine($pen, $from, $iconY, $to - 8, $iconY)
$head = @([Drawing.PointF]::new($to, $iconY), [Drawing.PointF]::new($to - 20, $iconY - 13), [Drawing.PointF]::new($to - 20, $iconY + 13))
$g.FillPolygon((New-Object Drawing.SolidBrush $accent), $head)

$note = New-Object Drawing.Font 'Segoe UI', 12, ([Drawing.FontStyle]::Regular), ([Drawing.GraphicsUnit]::Pixel)
$g.DrawString('First launch: right-click OpenReader, then Open (the app is not notarised yet).', $note, (New-Object Drawing.SolidBrush $muted), ($width / 2), 350, $center)

$bmp.Save($out, [Drawing.Imaging.ImageFormat]::Png)
Write-Host "Wrote $out"
