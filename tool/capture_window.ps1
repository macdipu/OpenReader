# Launches the Windows release build at a given window size, optionally opening a file, and saves a PNG of
# the window (title bar included). Used for the landing page / README screenshots and the UI audit.
#
#   powershell -ExecutionPolicy Bypass -File tool/capture_window.ps1 -Width 1280 -Height 760 -Out shot.png `
#       [-File "tool/screenshot_samples/Exploring the World.pdf"] [-Wait 4] [-Keep]
param(
  [int]$Width = 1280, [int]$Height = 760, [Parameter(Mandatory)][string]$Out,
  [string]$File = '', [int]$Wait = 4, [switch]$Keep, [string]$OpenPath = '', [string]$Keys = '',
  [string]$Exe = 'build\windows\x64\runner\Release\openreader.exe'   # run from the repo root
)
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public static class W {
  [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
  [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int w, int hh, uint f);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("dwmapi.dll")] public static extern int DwmGetWindowAttribute(IntPtr h, int a, out RECT r, int s);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
'@
[void][W]::SetProcessDPIAware()
$args2 = @(); if ($File) { $q = [char]34; $args2 += ($q + (Resolve-Path $File).Path + $q) }   # quoted: sample names contain spaces
$exe = (Resolve-Path $Exe).Path
$p = if ($args2.Count) { Start-Process -FilePath $exe -ArgumentList $args2 -PassThru } else { Start-Process -FilePath $exe -PassThru }
$deadline = (Get-Date).AddSeconds(30)
while ($p.MainWindowHandle -eq 0 -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 300; $p.Refresh() }
$h = $p.MainWindowHandle
[void][W]::SetWindowPos($h, [IntPtr]::Zero, 40, 40, $Width, $Height, 0x0040)
[void][W]::SetForegroundWindow($h)
Add-Type -AssemblyName System.Windows.Forms
Start-Sleep -Seconds 3
[void][W]::SetForegroundWindow($h); [Windows.Forms.SendKeys]::SendWait("{ESC}"); Start-Sleep -Milliseconds 800   # closes the one-time "default reader" prompt without saving a choice
if ($OpenPath) {   # Ctrl+O, type the path into the file dialog, Enter
  [void][W]::SetForegroundWindow($h); [Windows.Forms.SendKeys]::SendWait("^o"); Start-Sleep -Seconds 2
  [Windows.Forms.SendKeys]::SendWait((Resolve-Path $OpenPath).Path + "{ENTER}")
}
if ($Keys) { [void][W]::SetForegroundWindow($h); Start-Sleep -Seconds 1; [Windows.Forms.SendKeys]::SendWait($Keys) }
Start-Sleep -Seconds $Wait
$r = New-Object W+RECT
[void][W]::DwmGetWindowAttribute($h, 9, [ref]$r, 16)   # DWMWA_EXTENDED_FRAME_BOUNDS: no invisible resize border
$w = New-Object W+RECT; [void][W]::GetWindowRect($h, [ref]$w)
$full = New-Object Drawing.Bitmap ($w.R - $w.L), ($w.B - $w.T)
$g = [Drawing.Graphics]::FromImage($full)
$dc = $g.GetHdc(); [void][W]::PrintWindow($h, $dc, 2); $g.ReleaseHdc($dc)   # renders the window itself, even when another window overlaps it
$bmp = $full.Clone([Drawing.Rectangle]::new($r.L - $w.L, $r.T - $w.T, $r.R - $r.L, $r.B - $r.T), $full.PixelFormat)
$bmp.Save((Join-Path (Get-Location) $Out), [Drawing.Imaging.ImageFormat]::Png)
"$Out  $($bmp.Width)x$($bmp.Height)"
if (-not $Keep) { Stop-Process -Id $p.Id -Force }
