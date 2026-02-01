Param(
  [Parameter(Mandatory = $false)]
  [int]$Width = 1200,

  [Parameter(Mandatory = $false)]
  [int]$Height = 675,

  [Parameter(Mandatory = $false)]
  [string]$SourceDir = "AppImages\\iOS",

  [Parameter(Mandatory = $false)]
  [string]$OutDir = "email",

  [Parameter(Mandatory = $false)]
  [ValidateSet("jpg", "png")]
  [string]$Format = "jpg",

  [Parameter(Mandatory = $false)]
  [switch]$PhoneOnly,

  [Parameter(Mandatory = $false)]
  [int]$Quality = 84
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

Add-Type -AssemblyName System.Drawing

function New-RoundedRectPath {
  param(
    [float]$X,
    [float]$Y,
    [float]$W,
    [float]$H,
    [float]$R
  )

  $path = New-Object System.Drawing.Drawing2D.GraphicsPath
  if ($R -le 0) {
    $path.AddRectangle((New-Object System.Drawing.RectangleF($X, $Y, $W, $H)))
    return $path
  }

  $diameter = [float]($R * 2.0)
  $arc = New-Object System.Drawing.RectangleF($X, $Y, $diameter, $diameter)
  $path.AddArc($arc, 180, 90) | Out-Null
  $arc.X = $X + $W - $diameter
  $path.AddArc($arc, 270, 90) | Out-Null
  $arc.Y = $Y + $H - $diameter
  $path.AddArc($arc, 0, 90) | Out-Null
  $arc.X = $X
  $path.AddArc($arc, 90, 90) | Out-Null
  $path.CloseFigure() | Out-Null
  return $path
}

function Get-JpegCodec {
  return [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" } | Select-Object -First 1
}

function Save-Jpeg {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][int]$Quality
  )

  $codec = Get-JpegCodec
  if (-not $codec) {
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Jpeg)
    return
  }

  $encParams = New-Object System.Drawing.Imaging.EncoderParameters 1
  $qualityParam = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$Quality)
  $encParams.Param[0] = $qualityParam
  $Bitmap.Save($Path, $codec, $encParams)
  $encParams.Dispose()
}

function Save-Image {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Bitmap]$Bitmap,
    [Parameter(Mandatory = $true)][string]$Path
  )

  if ($Format -eq "png") {
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    return
  }

  Save-Jpeg -Bitmap $Bitmap -Path $Path -Quality $Quality
}

function Draw-Background {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Graphics]$G,
    [Parameter(Mandatory = $true)][int]$W,
    [Parameter(Mandatory = $true)][int]$H,
    [Parameter(Mandatory = $true)][int]$Seed
  )

  $base = [System.Drawing.Color]::FromArgb(22, 27, 38)   # #161b26
  $top = [System.Drawing.Color]::FromArgb(28, 33, 44)    # #1c212c
  $mid = [System.Drawing.Color]::FromArgb(28, 34, 48)    # #1c2230

  $bgRect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
  $G.Clear($base)

  $brush1 = New-Object System.Drawing.Drawing2D.LinearGradientBrush($bgRect, $top, $mid, 45.0)
  $G.FillRectangle($brush1, $bgRect)
  $brush1.Dispose()

  $rand = New-Object System.Random $Seed
  $spotX = [int]($W * (0.2 + 0.6 * $rand.NextDouble()))
  $spotY = [int]($H * (0.15 + 0.5 * $rand.NextDouble()))
  $spotR = [int]([Math]::Min($W, $H) * (0.65 + 0.25 * $rand.NextDouble()))

  $radialRect = New-Object System.Drawing.Rectangle ($spotX - [int]($spotR / 2)), ($spotY - [int]($spotR / 2)), $spotR, $spotR
  $radialPath = New-Object System.Drawing.Drawing2D.GraphicsPath
  $radialPath.AddEllipse($radialRect) | Out-Null
  $radialBrush = New-Object System.Drawing.Drawing2D.PathGradientBrush($radialPath)
  $radialBrush.CenterColor = [System.Drawing.Color]::FromArgb(40, 240, 243, 247)
  $radialBrush.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 240, 243, 247))
  $G.FillPath($radialBrush, $radialPath)
  $radialBrush.Dispose()
  $radialPath.Dispose()
}

function Draw-ImageCard {
  param(
    [Parameter(Mandatory = $true)][System.Drawing.Graphics]$G,
    [Parameter(Mandatory = $true)][System.Drawing.Image]$Image,
    [Parameter(Mandatory = $true)][System.Drawing.RectangleF]$Rect,
    [Parameter(Mandatory = $true)][float]$Radius,
    [Parameter(Mandatory = $true)][float]$Angle,
    [Parameter(Mandatory = $true)][string]$FitMode
  )

  $shadowOffset = 6.0
  $shadowAlpha = 90
  $borderColor = [System.Drawing.Color]::FromArgb(255, 58, 66, 82) # #3a4252
  $cardBg = [System.Drawing.Color]::FromArgb(255, 28, 34, 48)      # #1c2230

  $centerX = $Rect.X + ($Rect.Width / 2.0)
  $centerY = $Rect.Y + ($Rect.Height / 2.0)
  $state = $G.Save()

  $G.TranslateTransform($centerX, $centerY)
  $G.RotateTransform($Angle)
  $G.TranslateTransform(-$centerX, -$centerY)

  $shadowRect = New-Object System.Drawing.RectangleF ($Rect.X + $shadowOffset), ($Rect.Y + $shadowOffset), $Rect.Width, $Rect.Height
  $shadowPath = New-RoundedRectPath -X $shadowRect.X -Y $shadowRect.Y -W $shadowRect.Width -H $shadowRect.Height -R $Radius
  $shadowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb($shadowAlpha, 0, 0, 0))
  $G.FillPath($shadowBrush, $shadowPath)
  $shadowBrush.Dispose()
  $shadowPath.Dispose()

  $cardPath = New-RoundedRectPath -X $Rect.X -Y $Rect.Y -W $Rect.Width -H $Rect.Height -R $Radius
  $cardBrush = New-Object System.Drawing.SolidBrush $cardBg
  $G.FillPath($cardBrush, $cardPath)
  $cardBrush.Dispose()

  $clipState = $G.Save()
  $G.SetClip($cardPath)

  $scaleX = $Rect.Width / [float]$Image.Width
  $scaleY = $Rect.Height / [float]$Image.Height
  if ($FitMode -eq "contain") {
    $scale = [Math]::Min($scaleX, $scaleY)
  } else {
    $scale = [Math]::Max($scaleX, $scaleY)
  }

  $destW = [float]$Image.Width * $scale
  $destH = [float]$Image.Height * $scale
  $destX = $Rect.X + (($Rect.Width - $destW) / 2.0)
  $destY = $Rect.Y + (($Rect.Height - $destH) / 2.0)
  $destRect = New-Object System.Drawing.RectangleF $destX, $destY, $destW, $destH

  $G.DrawImage($Image, $destRect)
  $G.Restore($clipState)

  $pen = New-Object System.Drawing.Pen $borderColor, 1.0
  $G.DrawPath($pen, $cardPath)
  $pen.Dispose()
  $cardPath.Dispose()

  $G.Restore($state)
}

function New-Collage {
  param(
    [Parameter(Mandatory = $true)][string]$OutPath,
    [Parameter(Mandatory = $true)][int]$Seed,
    [Parameter(Mandatory = $true)][System.Collections.ArrayList]$Images,
    [Parameter(Mandatory = $true)][hashtable]$Layout
  )

  $bmp = New-Object System.Drawing.Bitmap $Width, $Height, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

  Draw-Background -G $g -W $Width -H $Height -Seed $Seed

  $rand = New-Object System.Random $Seed
  $fitMode = $Layout.FitMode
  $radius = [float]$Layout.Radius
  $angleMax = [float]$Layout.AngleMax

  $tiles = $Layout.Tiles
  for ($i = 0; $i -lt $tiles.Count; $i++) {
    $imgIndex = $rand.Next(0, $Images.Count)
    $img = $Images[$imgIndex]

    $tile = $tiles[$i]
    $rect = New-Object System.Drawing.RectangleF ([float]$tile.X), ([float]$tile.Y), ([float]$tile.W), ([float]$tile.H)
    $angle = ([float]($rand.NextDouble() * 2.0 - 1.0)) * $angleMax
    Draw-ImageCard -G $g -Image $img -Rect $rect -Radius $radius -Angle $angle -FitMode $fitMode
  }

  Save-Image -Bitmap $bmp -Path $OutPath
  $g.Dispose()
  $bmp.Dispose()
}

function Build-StaggeredTiles {
  param(
    [Parameter(Mandatory = $true)][int]$Cols,
    [Parameter(Mandatory = $true)][int]$Rows,
    [Parameter(Mandatory = $true)][int]$CardW,
    [Parameter(Mandatory = $true)][int]$CardH,
    [Parameter(Mandatory = $true)][int]$GapX,
    [Parameter(Mandatory = $true)][int]$GapY,
    [Parameter(Mandatory = $true)][int[]]$RowXOffsets
  )

  $tiles = New-Object System.Collections.ArrayList

  $rowSpanW = ($Cols * $CardW) + (($Cols - 1) * $GapX)
  $colStartX = [int](($Width - $rowSpanW) / 2)

  $gridSpanH = ($Rows * $CardH) + (($Rows - 1) * $GapY)
  $rowStartY = [int](($Height - $gridSpanH) / 2)

  for ($r = 0; $r -lt $Rows; $r++) {
    $xOffset = 0
    if ($r -lt $RowXOffsets.Length) { $xOffset = $RowXOffsets[$r] }
    for ($c = 0; $c -lt $Cols; $c++) {
      $x = $colStartX + $xOffset + ($c * ($CardW + $GapX))
      $y = $rowStartY + ($r * ($CardH + $GapY))
      [void]$tiles.Add(@{ X = $x; Y = $y; W = $CardW; H = $CardH })
    }
  }

  return $tiles
}

function Build-GridTiles {
  param(
    [Parameter(Mandatory = $true)][int]$Cols,
    [Parameter(Mandatory = $true)][int]$Rows,
    [Parameter(Mandatory = $true)][int]$CardW,
    [Parameter(Mandatory = $true)][int]$CardH,
    [Parameter(Mandatory = $true)][int]$Gap
  )

  $tiles = New-Object System.Collections.ArrayList

  $spanW = ($Cols * $CardW) + (($Cols - 1) * $Gap)
  $startX = [int](($Width - $spanW) / 2)

  $spanH = ($Rows * $CardH) + (($Rows - 1) * $Gap)
  $startY = [int](($Height - $spanH) / 2)

  for ($r = 0; $r -lt $Rows; $r++) {
    for ($c = 0; $c -lt $Cols; $c++) {
      $x = $startX + ($c * ($CardW + $Gap))
      $y = $startY + ($r * ($CardH + $Gap))
      [void]$tiles.Add(@{ X = $x; Y = $y; W = $CardW; H = $CardH })
    }
  }

  return $tiles
}

if (-not (Test-Path -LiteralPath $SourceDir)) {
  throw "SourceDir not found: $SourceDir"
}

if (-not (Test-Path -LiteralPath $OutDir)) {
  New-Item -ItemType Directory -Path $OutDir | Out-Null
}

$sourceFiles = @(Get-ChildItem -Path $SourceDir -File -Filter *.png | Sort-Object Name)
if ($PhoneOnly) {
  $sourceFiles = $sourceFiles | Where-Object { $_.Name -match '^[0-9]+\.png$' }
}
$sourceFiles = @($sourceFiles)

if ($sourceFiles.Count -lt 1) {
  throw "No PNG files found in $SourceDir"
}

$loadedImages = New-Object System.Collections.ArrayList
try {
  foreach ($file in $sourceFiles) {
    $img = [System.Drawing.Image]::FromFile($file.FullName)
    [void]$loadedImages.Add($img)
  }

  $ext = if ($Format -eq "png") { "png" } else { "jpg" }

  $variants = @(
    @{
      Name = "email_collage-01.$ext"
      Seed = 101
      FitMode = "cover"
      Radius = 14
      AngleMax = 5
      Tiles = (Build-StaggeredTiles -Cols 7 -Rows 2 -CardW 165 -CardH 230 -GapX 12 -GapY 18 -RowXOffsets @(0, 36))
    },
    @{
      Name = "email_collage-02.$ext"
      Seed = 202
      FitMode = "cover"
      Radius = 16
      AngleMax = 6
      Tiles = (Build-StaggeredTiles -Cols 6 -Rows 2 -CardW 185 -CardH 255 -GapX 14 -GapY 18 -RowXOffsets @(0, 44))
    },
    @{
      Name = "email_collage-03.$ext"
      Seed = 303
      FitMode = "cover"
      Radius = 12
      AngleMax = 4
      Tiles = (Build-StaggeredTiles -Cols 8 -Rows 2 -CardW 145 -CardH 205 -GapX 10 -GapY 16 -RowXOffsets @(0, 28))
    },
    @{
      Name = "email_collage-04.$ext"
      Seed = 404
      FitMode = "contain"
      Radius = 12
      AngleMax = 2
      Tiles = (Build-GridTiles -Cols 5 -Rows 3 -CardW 210 -CardH 180 -Gap 14)
    },
    @{
      Name = "email_collage-05.$ext"
      Seed = 505
      FitMode = "cover"
      Radius = 14
      AngleMax = 7
      Tiles = (Build-StaggeredTiles -Cols 7 -Rows 3 -CardW 145 -CardH 195 -GapX 10 -GapY 14 -RowXOffsets @(0, 24, 12))
    }
  )

  foreach ($v in $variants) {
    $outPath = Join-Path $OutDir $v.Name
    New-Collage -OutPath $outPath -Seed $v.Seed -Images $loadedImages -Layout $v
  }

  Copy-Item -Path (Join-Path $OutDir "email_collage-01.$ext") -Destination (Join-Path $OutDir "email_collage.$ext") -Force
  Write-Host "Generated:" -ForegroundColor Green
  Get-ChildItem -Path $OutDir -File | Where-Object { $_.Name -like "email_collage*.$ext" } | Sort-Object Name | ForEach-Object { Write-Host " - $($_.FullName)" }
}
finally {
  foreach ($img in $loadedImages) {
    $img.Dispose()
  }
}
