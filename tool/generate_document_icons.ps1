# Draws one Windows .ico per document type (page with a coloured format badge)
# into windows/runner/resources/file_icons. Colours follow DocumentCategory.
#   powershell -ExecutionPolicy Bypass -File tool/generate_document_icons.ps1
Add-Type -AssemblyName System.Drawing
$out = Join-Path $PSScriptRoot '..\windows\runner\resources\file_icons'
New-Item -ItemType Directory -Force $out | Out-Null

$types = [ordered]@{
  pdf  = @('PDF', '#DC2626'); docx = @('DOC', '#2563EB'); xlsx = @('XLS', '#059669')
  pptx = @('PPT', '#D97706'); txt  = @('TXT', '#64748B'); csv  = @('CSV', '#0891B2')
  md   = @('MD',  '#7C3AED')
}

function New-Page([string]$label, [string]$hex, [int]$s) {
  $c = [Drawing.ColorTranslator]::FromHtml($hex)
  $b = New-Object Drawing.Bitmap $s, $s
  $g = [Drawing.Graphics]::FromImage($b)
  $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'AntiAliasGridFit'
  $u = $s / 256.0
  $x0 = 44*$u; $y0 = 16*$u; $w = 168*$u; $h = 224*$u; $fold = 52*$u; $r = 14*$u
  $path = New-Object Drawing.Drawing2D.GraphicsPath
  $path.AddLine($x0 + $r, $y0, $x0 + $w - $fold, $y0)
  $path.AddLine($x0 + $w - $fold, $y0, $x0 + $w, $y0 + $fold)
  $path.AddArc($x0 + $w - 2*$r, $y0 + $h - 2*$r, 2*$r, 2*$r, 0, 90)
  $path.AddArc($x0, $y0 + $h - 2*$r, 2*$r, 2*$r, 90, 90)
  $path.AddArc($x0, $y0, 2*$r, 2*$r, 180, 90)
  $path.CloseFigure()
  $g.FillPath([Drawing.Brushes]::White, $path)
  $g.DrawPath((New-Object Drawing.Pen ([Drawing.Color]::FromArgb(255, 203, 213, 225)), (3*$u)), $path)
  $fp = @([Drawing.PointF]::new($x0 + $w - $fold, $y0), [Drawing.PointF]::new($x0 + $w - $fold, $y0 + $fold), [Drawing.PointF]::new($x0 + $w, $y0 + $fold))
  $g.FillPolygon((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 226, 232, 240))), $fp)
  # text lines
  $lp = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 226, 232, 240))
  foreach ($i in 0..1) { $g.FillRectangle($lp, $x0 + 22*$u, $y0 + (78 + 18*$i)*$u, (124 - 30*$i)*$u, 8*$u) }
  # badge
  $bx = $x0 - 10*$u; $by = $y0 + 118*$u; $bw = $w + 20*$u; $bh = 70*$u
  $g.FillRectangle((New-Object Drawing.SolidBrush $c), $bx, $by, $bw, $bh)
  $font = New-Object Drawing.Font 'Segoe UI', (40*$u), ([Drawing.FontStyle]::Bold), ([Drawing.GraphicsUnit]::Pixel)
  $sf = New-Object Drawing.StringFormat; $sf.Alignment = 'Center'; $sf.LineAlignment = 'Center'
  $g.DrawString($label, $font, [Drawing.Brushes]::White, (New-Object Drawing.RectangleF $bx, $by, $bw, $bh), $sf)
  $g.Dispose(); $b
}

$sizes = 16, 24, 32, 48, 64, 128, 256
foreach ($k in $types.Keys) {
  $pngs = foreach ($s in $sizes) {
    $bmp = New-Page $types[$k][0] $types[$k][1] $s
    $ms = New-Object IO.MemoryStream; $bmp.Save($ms, [Drawing.Imaging.ImageFormat]::Png); ,$ms.ToArray()
  }
  $ms = New-Object IO.MemoryStream; $w = New-Object IO.BinaryWriter $ms
  $w.Write([uint16]0); $w.Write([uint16]1); $w.Write([uint16]$sizes.Count)
  $off = 6 + 16 * $sizes.Count
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $s = $sizes[$i]
    $w.Write([byte]($s -band 255)); $w.Write([byte]($s -band 255)); $w.Write([byte]0); $w.Write([byte]0)
    $w.Write([uint16]1); $w.Write([uint16]32); $w.Write([uint32]$pngs[$i].Length); $w.Write([uint32]$off)
    $off += $pngs[$i].Length
  }
  foreach ($p in $pngs) { $w.Write($p) }
  [IO.File]::WriteAllBytes((Join-Path $out "$k.ico"), $ms.ToArray())
}
Write-Host "Wrote $($types.Count) icons to $out"
