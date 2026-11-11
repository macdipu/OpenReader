# Writes the showcase document in two formats, with the same text and picture, so every device in
# the landing page and the README shows the same content:
#   Exploring the World.pdf   and   Exploring the World.docx
# The picture is drawn here (a sunrise over mountains and a lake), so there is nothing to license.
#
#   powershell -ExecutionPolicy Bypass -File tool/screenshot_samples/make_showcase_samples.ps1 [-Out <dir>]
param([string]$Out = $PSScriptRoot)
Add-Type -AssemblyName System.Drawing, System.IO.Compression, System.IO.Compression.FileSystem

$title = 'Exploring the World'
$lead = 'A short guide to places worth the journey.'
$paras = @(
  'Some of the best trips begin with a simple question: what is over that ridge? This guide collects a handful of landscapes that reward the effort of getting there, from alpine lakes to quiet coastlines.',
  'Plan around the light. Early mornings and late afternoons soften every view, and the weather is usually calmer. Pack for changing conditions, carry water, and leave no trace.',
  'Take your time. The best moments are rarely on the schedule: a clearing in the clouds, a trail that opens onto a valley, a lake so still it holds the whole sky.'
)
$caption = 'Figure 1. Dawn over the lake.'
$w = 480; $h = 270

# ---- the picture -------------------------------------------------------------------------------
$bmp = New-Object Drawing.Bitmap $w, $h
$g = [Drawing.Graphics]::FromImage($bmp); $g.SmoothingMode = 'AntiAlias'
$sky = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(0, 0)), ([Drawing.Point]::new(0, 170)), ([Drawing.ColorTranslator]::FromHtml('#7FB2F0')), ([Drawing.ColorTranslator]::FromHtml('#FBD7A8'))
$g.FillRectangle($sky, 0, 0, $w, 175)
$g.FillEllipse((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(230, 255, 240, 200))), 330, 95, 56, 56)
function Mountain($points, $color) { $g.FillPolygon((New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml($color))), [Drawing.PointF[]]$points) }
Mountain @([Drawing.PointF]::new(0, 175), [Drawing.PointF]::new(90, 70), [Drawing.PointF]::new(170, 175)) '#7B8DB5'
Mountain @([Drawing.PointF]::new(120, 175), [Drawing.PointF]::new(250, 38), [Drawing.PointF]::new(400, 175)) '#566A94'
Mountain @([Drawing.PointF]::new(250, 38), [Drawing.PointF]::new(226, 76), [Drawing.PointF]::new(250, 70), [Drawing.PointF]::new(268, 82)) '#F4F7FC'
Mountain @([Drawing.PointF]::new(300, 175), [Drawing.PointF]::new(400, 90), [Drawing.PointF]::new(480, 175)) '#6F82AB'
$water = New-Object Drawing.Drawing2D.LinearGradientBrush ([Drawing.Point]::new(0, 175)), ([Drawing.Point]::new(0, $h)), ([Drawing.ColorTranslator]::FromHtml('#9CC6E8')), ([Drawing.ColorTranslator]::FromHtml('#2E5E88'))
$g.FillRectangle($water, 0, 175, $w, $h - 175)
$g.FillPolygon((New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(70, 40, 50, 90))), [Drawing.PointF[]]@([Drawing.PointF]::new(120, 176), [Drawing.PointF]::new(250, 268), [Drawing.PointF]::new(400, 176)))
foreach ($t in 0..13) { $x = 4 + $t * 36; $hgt = 30 + ($t * 7 % 26); $g.FillPolygon((New-Object Drawing.SolidBrush ([Drawing.ColorTranslator]::FromHtml('#1F4A3A'))), [Drawing.PointF[]]@([Drawing.PointF]::new($x, 196), [Drawing.PointF]::new($x + 11, 196 - $hgt), [Drawing.PointF]::new($x + 22, 196))) }
$png = New-Object IO.MemoryStream; $bmp.Save($png, [Drawing.Imaging.ImageFormat]::Png); $pngBytes = $png.ToArray()

# ---- PDF (the picture as hex-encoded RGB, so no compression library is needed) ----------------
$hex = New-Object Text.StringBuilder
for ($y = 0; $y -lt $h; $y++) { for ($x = 0; $x -lt $w; $x++) { $c = $bmp.GetPixel($x, $y); [void]$hex.Append(('{0:X2}{1:X2}{2:X2}' -f $c.R, $c.G, $c.B)) } }
[void]$hex.Append('>')
function Wrap([string]$text, [int]$max) {
  $lines = @(); $line = ''
  foreach ($word in $text.Split(' ')) { if (($line + ' ' + $word).Trim().Length -gt $max) { $lines += $line; $line = $word } else { $line = ($line + ' ' + $word).Trim() } }
  $lines + $line
}
$cs = "BT /F2 30 Tf 56 770 Td ($title) Tj ET`nBT /F1 13 Tf 56 746 Td ($lead) Tj ET`n"
$y = 712
foreach ($p in $paras[0..1]) { foreach ($l in (Wrap $p 78)) { $cs += "BT /F1 11.5 Tf 56 $y Td ($l) Tj ET`n"; $y -= 17 }; $y -= 9 }
$imgTop = $y - 4; $imgW = 480; $imgH = 270
$cs += "q $imgW 0 0 $imgH 56 $($imgTop - $imgH) cm /Im1 Do Q`n"
$cs += "BT /F1 9.5 Tf 56 $($imgTop - $imgH - 16) Td ($caption) Tj ET`n"
$y = $imgTop - $imgH - 44
foreach ($l in (Wrap $paras[2] 78)) { $cs += "BT /F1 11.5 Tf 56 $y Td ($l) Tj ET`n"; $y -= 17 }
$objs = @(
  '<< /Type /Catalog /Pages 2 0 R >>',
  '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
  '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents 4 0 R /Resources << /Font << /F1 5 0 R /F2 6 0 R >> /XObject << /Im1 7 0 R >> >> >>',
  "<< /Length $($cs.Length) >>`nstream`n$cs`nendstream",
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
  '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
  "<< /Type /XObject /Subtype /Image /Width $w /Height $h /ColorSpace /DeviceRGB /BitsPerComponent 8 /Filter /ASCIIHexDecode /Length $($hex.Length) >>`nstream`n$($hex.ToString())`nendstream"
)
$pdf = New-Object Text.StringBuilder; [void]$pdf.Append("%PDF-1.4`n"); $offs = @()
for ($i = 0; $i -lt $objs.Count; $i++) { $offs += $pdf.Length; [void]$pdf.Append("$($i + 1) 0 obj`n$($objs[$i])`nendobj`n") }
$xref = $pdf.Length
[void]$pdf.Append("xref`n0 $($objs.Count + 1)`n0000000000 65535 f `n")
foreach ($o in $offs) { [void]$pdf.Append(('{0:D10} 00000 n ' -f $o) + "`n") }
[void]$pdf.Append("trailer`n<< /Size $($objs.Count + 1) /Root 1 0 R >>`nstartxref`n$xref`n%%EOF`n")
[IO.File]::WriteAllBytes("$Out\Exploring the World.pdf", [Text.Encoding]::ASCII.GetBytes($pdf.ToString()))

# ---- DOCX --------------------------------------------------------------------------------------
$ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
$rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
function P($t, $sz, $bold, $col, $after = 160) {
  $b = if ($bold) { '<w:b/>' } else { '' }
  "<w:p><w:pPr><w:spacing w:after=`"$after`"/></w:pPr><w:r><w:rPr>$b<w:color w:val=`"$col`"/><w:sz w:val=`"$sz`"/></w:rPr><w:t xml:space=`"preserve`">$t</w:t></w:r></w:p>"
}
$emuW = 4572000; $emuH = [int]($emuW * $h / $w)
$drawing = "<w:p><w:pPr><w:spacing w:after=`"60`"/></w:pPr><w:r><w:drawing><wp:inline xmlns:wp=`"http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing`" distT=`"0`" distB=`"0`" distL=`"0`" distR=`"0`"><wp:extent cx=`"$emuW`" cy=`"$emuH`"/><wp:docPr id=`"1`" name=`"Dawn over the lake`" descr=`"Dawn over mountains and a lake`"/><a:graphic xmlns:a=`"http://schemas.openxmlformats.org/drawingml/2006/main`"><a:graphicData uri=`"http://schemas.openxmlformats.org/drawingml/2006/picture`"><pic:pic xmlns:pic=`"http://schemas.openxmlformats.org/drawingml/2006/picture`"><pic:nvPicPr><pic:cNvPr id=`"0`" name=`"lake.png`"/><pic:cNvPicPr/></pic:nvPicPr><pic:blipFill><a:blip xmlns:r=`"$rel`" r:embed=`"rIdImg`"/><a:stretch><a:fillRect/></a:stretch></pic:blipFill><pic:spPr><a:xfrm><a:off x=`"0`" y=`"0`"/><a:ext cx=`"$emuW`" cy=`"$emuH`"/></a:xfrm><a:prstGeom prst=`"rect`"><a:avLst/></a:prstGeom></pic:spPr></pic:pic></a:graphicData></a:graphic></wp:inline></w:drawing></w:r></w:p>"
$body = (P $title 56 $true '0B1220' 80) + (P $lead 26 $false '64748B' 280) + (P $paras[0] 24 $false '1F2937') + (P $paras[1] 24 $false '1F2937') + $drawing + (P $caption 18 $false '64748B' 240) + (P $paras[2] 24 $false '1F2937')
$path = "$Out\Exploring the World.docx"; [IO.File]::Delete($path)
$z = [IO.Compression.ZipFile]::Open($path, 'Create')
function Add-Entry($name, $text) { $e = $z.CreateEntry($name); $wr = New-Object IO.StreamWriter($e.Open(), (New-Object Text.UTF8Encoding $false)); $wr.Write($text); $wr.Dispose() }
Add-Entry '[Content_Types].xml' "$ct<Types xmlns=`"http://schemas.openxmlformats.org/package/2006/content-types`"><Default Extension=`"rels`" ContentType=`"application/vnd.openxmlformats-package.relationships+xml`"/><Default Extension=`"xml`" ContentType=`"application/xml`"/><Default Extension=`"png`" ContentType=`"image/png`"/><Override PartName=`"/word/document.xml`" ContentType=`"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml`"/></Types>"
Add-Entry '_rels/.rels' "$ct<Relationships xmlns=`"http://schemas.openxmlformats.org/package/2006/relationships`"><Relationship Id=`"rId1`" Type=`"$rel/officeDocument`" Target=`"word/document.xml`"/></Relationships>"
Add-Entry 'word/_rels/document.xml.rels' "$ct<Relationships xmlns=`"http://schemas.openxmlformats.org/package/2006/relationships`"><Relationship Id=`"rIdImg`" Type=`"$rel/image`" Target=`"media/lake.png`"/></Relationships>"
Add-Entry 'word/document.xml' "$ct<w:document xmlns:w=`"http://schemas.openxmlformats.org/wordprocessingml/2006/main`"><w:body>$body<w:sectPr><w:pgSz w:w=`"11906`" w:h=`"16838`"/><w:pgMar w:top=`"1440`" w:right=`"1440`" w:bottom=`"1440`" w:left=`"1440`"/></w:sectPr></w:body></w:document>"
$img = $z.CreateEntry('word/media/lake.png'); $s = $img.Open(); $s.Write($pngBytes, 0, $pngBytes.Length); $s.Dispose()
$z.Dispose()
Write-Host "Wrote Exploring the World.pdf and .docx to $Out"
