<#
  Registers OpenReader in Explorer's "Open with" list for the document types it
  reads, with a separate icon per type (PDF red, DOC blue, XLS green, ...).
  Per-user (HKCU), no admin rights needed, and it does not change any default
  app. Run from the folder that holds openreader.exe:

    powershell -ExecutionPolicy Bypass -File register-file-types.ps1
    powershell -ExecutionPolicy Bypass -File register-file-types.ps1 -Unregister

  Files you already set to "always open with OpenReader" before running this
  keep the app icon until you pick OpenReader again from Open with > Choose
  another app.
#>
param(
  [string]$ExePath = (Join-Path $PSScriptRoot 'openreader.exe'),
  [string]$IconDir = (Join-Path $PSScriptRoot 'file_icons'),
  [switch]$Unregister
)

$ErrorActionPreference = 'Stop'
$extensions = '.pdf', '.docx', '.xlsx', '.pptx', '.txt', '.md', '.csv'
$classes = 'HKCU:\Software\Classes'

# An earlier version registered one shared handler; clean it up.
Remove-Item "$classes\Applications\openreader.exe" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$classes\OpenReader.Document" -Recurse -Force -ErrorAction SilentlyContinue
foreach ($e in $extensions) {
  Remove-ItemProperty "$classes\$e\OpenWithProgids" -Name 'OpenReader.Document' -ErrorAction SilentlyContinue
}

# Capabilities make OpenReader show up in Settings > Default apps, where the
# user can pick it per file type (Windows does not let an app set defaults itself).
$capabilities = 'HKCU:\Software\OpenReader\Capabilities'
if ($Unregister) {
  Remove-Item 'HKCU:\Software\OpenReader' -Recurse -Force -ErrorAction SilentlyContinue
  Remove-ItemProperty 'HKCU:\Software\RegisteredApplications' -Name 'OpenReader' -ErrorAction SilentlyContinue
} else {
  New-Item "$capabilities\FileAssociations" -Force | Out-Null
  Set-ItemProperty $capabilities -Name 'ApplicationName' -Value 'OpenReader'
  Set-ItemProperty $capabilities -Name 'ApplicationDescription' -Value 'Read PDF, Word, Excel, PowerPoint, text and CSV files.'
  New-Item 'HKCU:\Software\RegisteredApplications' -Force | Out-Null
  Set-ItemProperty 'HKCU:\Software\RegisteredApplications' -Name 'OpenReader' -Value 'Software\OpenReader\Capabilities'
}

foreach ($e in $extensions) {
  $progId = "OpenReader$e"
  if (-not $Unregister) {
    Set-ItemProperty "$capabilities\FileAssociations" -Name $e -Value $progId
  }
  if ($Unregister) {
    Remove-Item "$classes\$progId" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-ItemProperty "$classes\$e\OpenWithProgids" -Name $progId -ErrorAction SilentlyContinue
    continue
  }
  $ExePath = (Resolve-Path $ExePath).Path
  $icon = Join-Path $IconDir ($e.TrimStart('.') + '.ico')
  if (-not (Test-Path $icon)) { $icon = "$ExePath,0" }

  New-Item "$classes\$progId\shell\open\command" -Force | Out-Null
  Set-ItemProperty "$classes\$progId" -Name '(default)' -Value 'OpenReader'
  Set-ItemProperty "$classes\$progId\shell\open\command" -Name '(default)' -Value "`"$ExePath`" `"%1`""
  New-Item "$classes\$progId\DefaultIcon" -Force | Out-Null
  Set-ItemProperty "$classes\$progId\DefaultIcon" -Name '(default)' -Value "`"$icon`""

  New-Item "$classes\$e\OpenWithProgids" -Force | Out-Null
  New-ItemProperty "$classes\$e\OpenWithProgids" -Name $progId -Value '' -PropertyType String -Force | Out-Null
}

# Tell Explorer the associations changed (SHCNE_ASSOCCHANGED).
Add-Type -Namespace Win32 -Name Shell -MemberDefinition '[DllImport("shell32.dll")] public static extern void SHChangeNotify(int e, uint f, IntPtr a, IntPtr b);'
[Win32.Shell]::SHChangeNotify(0x08000000, 0, [IntPtr]::Zero, [IntPtr]::Zero)
Write-Host ($(if ($Unregister) { 'OpenReader unregistered.' } else { "OpenReader registered for: $($extensions -join ' ')" }))
