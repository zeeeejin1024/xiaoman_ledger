Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$geometryPath = Join-Path $root 'lib/widgets/brand_mark_geometry.dart'
$geometrySource = Get-Content -Raw $geometryPath
$launcher = Join-Path $root 'assets/icon.png'
$foreground = Join-Path $root 'assets/icon_foreground.png'

function Get-GeometryValue([string]$name) {
  $pattern = "static const double $name = (-?[0-9.]+);"
  $match = [regex]::Match($geometrySource, $pattern)
  if (-not $match.Success) {
    throw "BrandMarkGeometry.$name was not found in $geometryPath"
  }
  return [double]::Parse(
    $match.Groups[1].Value,
    [System.Globalization.CultureInfo]::InvariantCulture
  )
}

$centerRatio = Get-GeometryValue 'center'
$radiusRatio = Get-GeometryValue 'radius'
$strokeRatio = Get-GeometryValue 'strokeWidth'
$startAngle = Get-GeometryValue 'startAngle'
$gap = Get-GeometryValue 'gap'
$markerProgress = Get-GeometryValue 'markerProgress'
$markerRadiusRatio = Get-GeometryValue 'markerRadius'
$gapMarkerOffset = Get-GeometryValue 'gapMarkerAngleOffset'
$gapMarkerRadiusRatio = Get-GeometryValue 'gapMarkerRadius'
$tickInnerRatio = Get-GeometryValue 'tickInnerRadius'
$tickOuterRatio = Get-GeometryValue 'tickOuterRadius'
$tickStrokeRatio = Get-GeometryValue 'tickStrokeWidth'
$launcherScale = Get-GeometryValue 'launcherScale'
$tickProgresses = @(
  (Get-GeometryValue 'tickOneProgress'),
  (Get-GeometryValue 'tickTwoProgress'),
  (Get-GeometryValue 'tickThreeProgress')
)

$cream = [System.Drawing.Color]::FromArgb(255, 244, 244, 240)
$graphite = [System.Drawing.Color]::FromArgb(255, 39, 54, 64)
$berry = [System.Drawing.Color]::FromArgb(255, 180, 91, 108)
$tickColor = [System.Drawing.Color]::FromArgb(105, 244, 244, 240)

function New-Canvas([bool]$includeBackground) {
  $size = 1024.0
  $unit = $size * $launcherScale
  $center = $size * $centerRatio
  $radius = $unit * $radiusRatio
  $stroke = $unit * $strokeRatio
  $sweep = (2.0 * [Math]::PI) - $gap
  $startDegrees = $startAngle * 180.0 / [Math]::PI
  $sweepDegrees = $sweep * 180.0 / [Math]::PI

  $bitmap = [System.Drawing.Bitmap]::new(1024, 1024)
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.Clear([System.Drawing.Color]::Transparent)

  if ($includeBackground) {
    $path = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $corner = 232
    $rect = [System.Drawing.Rectangle]::new(48, 48, 928, 928)
    $path.AddArc($rect.X, $rect.Y, $corner, $corner, 180, 90)
    $path.AddArc($rect.Right - $corner, $rect.Y, $corner, $corner, 270, 90)
    $path.AddArc($rect.Right - $corner, $rect.Bottom - $corner, $corner, $corner, 0, 90)
    $path.AddArc($rect.X, $rect.Bottom - $corner, $corner, $corner, 90, 90)
    $path.CloseFigure()
    $backgroundBrush = [System.Drawing.SolidBrush]::new($graphite)
    $graphics.FillPath($backgroundBrush, $path)
    $backgroundBrush.Dispose()
    $path.Dispose()
  }

  $ring = [System.Drawing.Pen]::new($cream, [single]$stroke)
  $ring.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $ring.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  $graphics.DrawArc(
    $ring,
    [single]($center - $radius),
    [single]($center - $radius),
    [single]($radius * 2),
    [single]($radius * 2),
    [single]$startDegrees,
    [single]$sweepDegrees
  )
  $ring.Dispose()

  $markerAngle = $startAngle + ($sweep * $markerProgress)
  $markerRadius = $unit * $markerRadiusRatio
  $markerX = $center + ([Math]::Cos($markerAngle) * $radius)
  $markerY = $center + ([Math]::Sin($markerAngle) * $radius)
  $markerBrush = [System.Drawing.SolidBrush]::new($berry)
  $graphics.FillEllipse(
    $markerBrush,
    [single]($markerX - $markerRadius),
    [single]($markerY - $markerRadius),
    [single]($markerRadius * 2),
    [single]($markerRadius * 2)
  )
  $markerBrush.Dispose()

  $gapAngle = $startAngle + $sweep + $gapMarkerOffset
  $gapMarkerRadius = $unit * $gapMarkerRadiusRatio
  $gapX = $center + ([Math]::Cos($gapAngle) * $radius)
  $gapY = $center + ([Math]::Sin($gapAngle) * $radius)
  $gapBrush = [System.Drawing.SolidBrush]::new(
    [System.Drawing.Color]::FromArgb(210, $berry)
  )
  $graphics.FillEllipse(
    $gapBrush,
    [single]($gapX - $gapMarkerRadius),
    [single]($gapY - $gapMarkerRadius),
    [single]($gapMarkerRadius * 2),
    [single]($gapMarkerRadius * 2)
  )
  $gapBrush.Dispose()

  $ticks = [System.Drawing.Pen]::new($tickColor, [single]($unit * $tickStrokeRatio))
  $ticks.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $ticks.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
  foreach ($tickProgress in $tickProgresses) {
    $angle = $startAngle + ($sweep * $tickProgress)
    $innerRadius = $unit * $tickInnerRatio
    $outerRadius = $unit * $tickOuterRatio
    $graphics.DrawLine(
      $ticks,
      [single]($center + [Math]::Cos($angle) * $innerRadius),
      [single]($center + [Math]::Sin($angle) * $innerRadius),
      [single]($center + [Math]::Cos($angle) * $outerRadius),
      [single]($center + [Math]::Sin($angle) * $outerRadius)
    )
  }
  $ticks.Dispose()

  return @{ Bitmap = $bitmap; Graphics = $graphics }
}

function Save-Icon([System.Drawing.Bitmap]$source, [int]$size, [string]$path) {
  $target = [System.Drawing.Bitmap]::new($size, $size)
  $graphics = [System.Drawing.Graphics]::FromImage($target)
  $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $graphics.DrawImage($source, 0, 0, $size, $size)
  $graphics.Dispose()
  $target.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $target.Dispose()
}

$full = New-Canvas $true
$full.Bitmap.Save($launcher, [System.Drawing.Imaging.ImageFormat]::Png)
$full.Graphics.Dispose()

$front = New-Canvas $false
$front.Bitmap.Save($foreground, [System.Drawing.Imaging.ImageFormat]::Png)
$front.Graphics.Dispose()

$sizes = @{
  'icon_48.png' = 48
  'icon_72.png' = 72
  'icon_96.png' = 96
  'icon_144.png' = 144
  'icon_192.png' = 192
  'icon_512.png' = 512
  'icon_1024.png' = 1024
}
foreach ($entry in $sizes.GetEnumerator()) {
  Save-Icon $full.Bitmap $entry.Value (Join-Path $root "assets/$($entry.Key)")
}

$densities = @{
  'mipmap-mdpi' = 48
  'mipmap-hdpi' = 72
  'mipmap-xhdpi' = 96
  'mipmap-xxhdpi' = 144
  'mipmap-xxxhdpi' = 192
}
foreach ($entry in $densities.GetEnumerator()) {
  $directory = Join-Path $root "android/app/src/main/res/$($entry.Key)"
  foreach ($name in @('ic_launcher.png', 'ic_launcher_round.png')) {
    Save-Icon $full.Bitmap $entry.Value (Join-Path $directory $name)
  }
}

$full.Bitmap.Dispose()
$front.Bitmap.Dispose()
