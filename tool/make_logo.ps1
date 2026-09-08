Add-Type -AssemblyName System.Drawing

$w = 1600; $h = 520
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAlias
$g.Clear([System.Drawing.Color]::Transparent)

$blue   = [System.Drawing.Color]::FromArgb(255, 37, 99, 235)    # #2563EB
$purple = [System.Drawing.Color]::FromArgb(255, 124, 58, 237)   # #7C3AED
$navy   = [System.Drawing.Color]::FromArgb(255, 30, 27, 75)     # #1E1B4B
$violet = [System.Drawing.Color]::FromArgb(255, 109, 40, 217)   # #6D28D9
$white  = [System.Drawing.Color]::White

# ---- Starburst above the book ----
$cx = 300; $cy = 120
$spikes = 10
$path = New-Object System.Drawing.Drawing2D.GraphicsPath
$pts = @()
for ($i = 0; $i -lt ($spikes * 2); $i++) {
    $angle = ($i * [Math]::PI / $spikes) - ([Math]::PI / 2)
    if ($i % 2 -eq 0) {
        if ($i -eq 0) { $r = 105 } elseif ($i % 4 -eq 0) { $r = 85 } else { $r = 65 }
    } else { $r = 22 }
    $pts += New-Object System.Drawing.PointF(($cx + $r * [Math]::Cos($angle)), ($cy + $r * [Math]::Sin($angle)))
}
$path.AddPolygon($pts)
$starBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(200, 20)), (New-Object System.Drawing.Point(400, 220)), $blue, $purple)
$g.FillPath($starBrush, $path)

# ---- Open book (two pages, gradient) ----
$bookBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
    (New-Object System.Drawing.Point(60, 300)), (New-Object System.Drawing.Point(560, 300)), $blue, $purple)

# Left page
$lp = New-Object System.Drawing.Drawing2D.GraphicsPath
$lp.AddBezier(70, 195, 150, 150, 230, 160, 295, 215)
$lp.AddLine(295, 215, 295, 490)
$lp.AddBezier(295, 490, 230, 435, 150, 425, 70, 465)
$lp.CloseFigure()
$g.FillPath($bookBrush, $lp)

# Right page
$rp = New-Object System.Drawing.Drawing2D.GraphicsPath
$rp.AddBezier(530, 195, 450, 150, 370, 160, 305, 215)
$rp.AddLine(305, 215, 305, 490)
$rp.AddBezier(305, 490, 370, 435, 450, 425, 530, 465)
$rp.CloseFigure()
$g.FillPath($bookBrush, $rp)

# ---- Circuit traces on the pages (white lines + node circles) ----
$pen = New-Object System.Drawing.Pen($white, 7)
$pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
$pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
$nodeBrush = New-Object System.Drawing.SolidBrush($white)

function Draw-Trace($g, $pen, $nodeBrush, $points) {
    $g.DrawLines($pen, $points)
    $p0 = $points[0]
    $g.FillEllipse($nodeBrush, $p0.X - 13, $p0.Y - 13, 26, 26)
}

# Left page traces (bend upward toward nodes)
Draw-Trace $g $pen $nodeBrush @(
    (New-Object System.Drawing.PointF(125, 280)), (New-Object System.Drawing.PointF(125, 330)), (New-Object System.Drawing.PointF(165, 370)), (New-Object System.Drawing.PointF(165, 430)))
Draw-Trace $g $pen $nodeBrush @(
    (New-Object System.Drawing.PointF(185, 255)), (New-Object System.Drawing.PointF(185, 310)), (New-Object System.Drawing.PointF(215, 340)), (New-Object System.Drawing.PointF(215, 450)))
Draw-Trace $g $pen $nodeBrush @(
    (New-Object System.Drawing.PointF(250, 280)), (New-Object System.Drawing.PointF(250, 460)))

# Right page traces
Draw-Trace $g $pen $nodeBrush @(
    (New-Object System.Drawing.PointF(475, 280)), (New-Object System.Drawing.PointF(475, 330)), (New-Object System.Drawing.PointF(435, 370)), (New-Object System.Drawing.PointF(435, 430)))
Draw-Trace $g $pen $nodeBrush @(
    (New-Object System.Drawing.PointF(415, 255)), (New-Object System.Drawing.PointF(415, 310)), (New-Object System.Drawing.PointF(385, 340)), (New-Object System.Drawing.PointF(385, 450)))
Draw-Trace $g $pen $nodeBrush @(
    (New-Object System.Drawing.PointF(350, 280)), (New-Object System.Drawing.PointF(350, 460)))

# ---- Text: "Learnova" navy + "AI" violet ----
$font = New-Object System.Drawing.Font("Segoe UI", 130, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$navyBrush = New-Object System.Drawing.SolidBrush($navy)
$violetBrush = New-Object System.Drawing.SolidBrush($violet)

$textY = 240
$g.DrawString("Learnova", $font, $navyBrush, 600, $textY)
$size = $g.MeasureString("Learnova", $font)
$g.DrawString("AI", $font, $violetBrush, (600 + $size.Width - 20), $textY)

$out = "c:\Users\VICTUS\Documents\Project final sem\ai_student_dev\assets\images\learnova_logo.png"
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)

$g.Dispose(); $bmp.Dispose()
Write-Output "Saved: $out"
