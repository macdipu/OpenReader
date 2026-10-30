# Generates a 6-page PDF and a long DOCX for exercising scrolling and zoom.
param([string]$Out = $PSScriptRoot)
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
$words = 'reader document page layout margin scroll zoom column paragraph heading table image caption index summary'.Split(' ')
function Sentence($seed) { $r = New-Object Random $seed; (1..14 | ForEach-Object { $words[$r.Next($words.Length)] }) -join ' ' }

# PDF: 6 pages, 36 lines each
$objs = New-Object System.Collections.ArrayList
[void]$objs.Add('<< /Type /Catalog /Pages 2 0 R >>')
$kids = (0..5 | ForEach-Object { "$(3 + 2 * $_) 0 R" }) -join ' '
[void]$objs.Add("<< /Type /Pages /Kids [$kids] /Count 6 >>")
foreach ($pg in 0..5) {
  $cs = "BT /F2 22 Tf 56 780 Td (Page $($pg + 1) of 6) Tj ET`n"
  $y = 740
  foreach ($l in 0..35) { $cs += "BT /F1 11 Tf 56 $y Td ($(Sentence ($pg * 100 + $l))) Tj ET`n"; $y -= 19 }
  [void]$objs.Add("<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Contents $(4 + 2 * $pg) 0 R /Resources << /Font << /F1 15 0 R /F2 16 0 R >> >> >>")
  [void]$objs.Add("<< /Length $($cs.Length) >>`nstream`n$cs`nendstream")
}
[void]$objs.Add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>')
[void]$objs.Add('<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>')
$pdf = "%PDF-1.4`n"; $offs = @()
for ($i = 0; $i -lt $objs.Count; $i++) { $offs += $pdf.Length; $pdf += "$($i + 1) 0 obj`n$($objs[$i])`nendobj`n" }
$x = $pdf.Length
$pdf += "xref`n0 $($objs.Count + 1)`n0000000000 65535 f `n"
foreach ($o in $offs) { $pdf += ('{0:D10} 00000 n ' -f $o) + "`n" }
$pdf += "trailer`n<< /Size $($objs.Count + 1) /Root 1 0 R >>`nstartxref`n$x`n%%EOF`n"
[IO.File]::WriteAllBytes("$Out\Long Report.pdf", [Text.Encoding]::ASCII.GetBytes($pdf))

# DOCX: 120 paragraphs
$ct = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
$body = '<w:p><w:r><w:rPr><w:b/><w:sz w:val="44"/></w:rPr><w:t>Long Document</w:t></w:r></w:p>'
foreach ($i in 1..120) { $body += "<w:p><w:r><w:t>$i. $(Sentence $i) $(Sentence ($i + 500))</w:t></w:r></w:p>" }
$entries = [ordered]@{
  '[Content_Types].xml' = "$ct<Types xmlns=`"http://schemas.openxmlformats.org/package/2006/content-types`"><Default Extension=`"rels`" ContentType=`"application/vnd.openxmlformats-package.relationships+xml`"/><Default Extension=`"xml`" ContentType=`"application/xml`"/><Override PartName=`"/word/document.xml`" ContentType=`"application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml`"/></Types>"
  '_rels/.rels' = "$ct<Relationships xmlns=`"http://schemas.openxmlformats.org/package/2006/relationships`"><Relationship Id=`"rId1`" Type=`"http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument`" Target=`"word/document.xml`"/></Relationships>"
  'word/document.xml' = "$ct<w:document xmlns:w=`"http://schemas.openxmlformats.org/wordprocessingml/2006/main`"><w:body>$body<w:sectPr><w:pgSz w:w=`"11906`" w:h=`"16838`"/><w:pgMar w:top=`"1440`" w:right=`"1440`" w:bottom=`"1440`" w:left=`"1440`"/></w:sectPr></w:body></w:document>"
}
$path = "$Out\Long Document.docx"; [IO.File]::Delete($path)
$z = [IO.Compression.ZipFile]::Open($path, 'Create')
foreach ($k in $entries.Keys) { $e = $z.CreateEntry($k); $w = New-Object IO.StreamWriter($e.Open(), (New-Object Text.UTF8Encoding $false)); $w.Write($entries[$k]); $w.Dispose() }
$z.Dispose()
Write-Host "Wrote Long Report.pdf and Long Document.docx to $Out"
