# Installs the latest OpenReader release on Windows (x64, per user, no admin rights).
#   irm https://raw.githubusercontent.com/macdipu/OpenReader/main/install.ps1 | iex
# Runs the setup.exe from the latest release; if that release has none, extracts the
# portable zip to %LOCALAPPDATA%\OpenReader and registers "Open with".
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'macdipu/OpenReader'
$release = Invoke-RestMethod "https://api.github.com/repos/$repo/releases/latest" -Headers @{ 'User-Agent' = 'OpenReader-install' }
$setup = $release.assets | Where-Object { $_.name -like '*windows-x64-setup.exe' } | Select-Object -First 1
$zip = $release.assets | Where-Object { $_.name -like 'openreader-windows-x64-*.zip' } | Select-Object -First 1

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("openreader-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  if ($setup) {
    $file = Join-Path $tmp $setup.name
    Write-Host "Downloading $($setup.name)"
    Invoke-WebRequest $setup.browser_download_url -OutFile $file
    Start-Process $file -ArgumentList '/SILENT', '/TASKS=openwith' -Wait
  } elseif ($zip) {
    $file = Join-Path $tmp $zip.name
    $dest = Join-Path $env:LOCALAPPDATA 'OpenReader'
    Write-Host "Downloading $($zip.name)"
    Invoke-WebRequest $zip.browser_download_url -OutFile $file
    New-Item -ItemType Directory -Path $dest -Force | Out-Null
    Expand-Archive $file -DestinationPath $dest -Force
    & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dest 'register-file-types.ps1')
    Write-Host "Installed to $dest"
  } else {
    throw "No Windows download found in release $($release.tag_name)."
  }
  Write-Host 'OpenReader installed.'
} finally {
  Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
