param(
  [string]$OutIco = '',
  [string]$InstallerPng = ''
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

function Draw-Mark([System.Drawing.Graphics]$g, [int]$size) {
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
  $pad = [int]($size * 0.06)
  $rect = New-Object System.Drawing.Rectangle ($pad, $pad, ($size - $pad * 2), ($size - $pad * 2))
  $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush ($rect, [System.Drawing.Color]::FromArgb(255, 76, 29, 149), [System.Drawing.Color]::FromArgb(255, 30, 27, 75), 45)
  $g.FillRectangle($brush, $rect)
  $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 216, 180, 254)), ([float]($size * 0.024))
  $g.DrawRectangle($pen, $rect)
  $tri = @(
    [System.Drawing.Point]::new([int]($size * 0.28), [int]($size * 0.72)),
    [System.Drawing.Point]::new([int]($size * 0.50), [int]($size * 0.28)),
    [System.Drawing.Point]::new([int]($size * 0.72), [int]($size * 0.72))
  )
  $triBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(56, 192, 132, 252))
  $g.FillPolygon($triBrush, $tri)
  $triPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 196, 181, 253)), ([float]($size * 0.05))
  $g.DrawPolygon($triPen, $tri)
  $font = [System.Drawing.Font]::new('Segoe UI', [float]($size * 0.26), [System.Drawing.FontStyle]::Bold)
  $sf = New-Object System.Drawing.StringFormat
  $sf.Alignment = [System.Drawing.StringAlignment]::Center
  $sf.LineAlignment = [System.Drawing.StringAlignment]::Center
  $g.DrawString('L', $font, [System.Drawing.Brushes]::White, ($size / 2.0), ($size * 0.52), $sf)
}

if ([string]::IsNullOrWhiteSpace($OutIco)) {
  $OutIco = Join-Path $PSScriptRoot '..\client\windows\runner\resources\app_icon.ico'
}
if ([string]::IsNullOrWhiteSpace($InstallerPng)) {
  $InstallerPng = Join-Path $PSScriptRoot 'installer\lynx_launcher.png'
}

$size = 256
$bmp = New-Object System.Drawing.Bitmap $size, $size
$g = [System.Drawing.Graphics]::FromImage($bmp)
Draw-Mark $g $size
$g.Dispose()

$pngPath = [System.IO.Path]::ChangeExtension($OutIco, '.png')
$bmp.Save($pngPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Save($InstallerPng, [System.Drawing.Imaging.ImageFormat]::Png)

$icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
$fs = [System.IO.File]::Open($OutIco, [System.IO.FileMode]::Create)
try { $icon.Save($fs) } finally { $fs.Close(); $icon.Dispose(); $bmp.Dispose() }
Write-Host "Icon: $OutIco"
