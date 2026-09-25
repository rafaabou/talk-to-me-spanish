# Portable launcher for Windows WITHOUT Python (uses built-in .NET HttpListener).
# Double-click via RUN.bat, or right-click > Run with PowerShell.
# Serves the prebuilt web app fully offline. Use Chrome or Edge.
param([int]$Port = 8002)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$AppName = 'Talk To Me Spanish'
$WebDir = Join-Path $PSScriptRoot 'app\build\web'

if (-not (Test-Path (Join-Path $WebDir 'index.html'))) {
  Write-Host 'ERROR: prebuilt web app not found. On a Flutter machine run: cd app; flutter build web --release'
  Read-Host 'Press Enter to exit'; exit 1
}

# Fix double-nested assets if symlinks were lost in the copy (plain copy, no admin needed)
foreach ($d in @('audio', 'course')) {
  $link = Join-Path $WebDir "assets\$d"
  $real = Join-Path $WebDir "assets\assets\$d"
  if ((Test-Path $real) -and -not (Test-Path $link)) {
    Write-Host "Fixing $d paths..."
    Copy-Item $real $link -Recurse -Force
  }
}

$mime = @{
  '.opus' = 'audio/ogg; codecs=opus'; '.wasm' = 'application/wasm'
  '.woff2' = 'font/woff2'; '.woff' = 'font/woff'; '.js' = 'text/javascript'
  '.json' = 'application/json'; '.html' = 'text/html'
  '.css' = 'text/css'; '.svg' = 'image/svg+xml'; '.png' = 'image/png'
  '.jpg' = 'image/jpeg'; '.ico' = 'image/x-icon'; '.ttf' = 'font/ttf'
  '.bin' = 'application/octet-stream'; '.map' = 'application/json'
}
# Only real files inside the web directory may be served: a crafted path must
# not reach the keystore, key.properties or anything else next to it.
$webRoot = [IO.Path]::GetFullPath($WebDir).TrimEnd('\') + '\'
function Resolve-Inside([string]$candidate) {
  try { $full = [IO.Path]::GetFullPath($candidate) } catch { return $null }
  if ($full -eq $WebDir) { return $null }
  if (-not $full.StartsWith($webRoot, [StringComparison]::OrdinalIgnoreCase)) { return $null }
  if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { return $null }
  return $full
}
# First free port starting at $Port
while ($true) {
  try { $t = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Loopback, $Port); $t.Start(); $t.Stop(); break }
  catch { $Port++ ; if ($Port -gt 8021) { Write-Host 'ERROR: no free port'; Read-Host 'Enter'; exit 1 } }
}

$listener = New-Object Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Starting $AppName on http://localhost:$Port/ ..."
Start-Process "http://localhost:$Port/"
Write-Host 'Press Ctrl+C to stop.'
try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.LocalPath.TrimStart('/')) -replace '/', '\'
    if ($rel -eq '') { $rel = 'index.html' }
    $file = Resolve-Inside (Join-Path $WebDir $rel)
    # transparent double-nested fallback
    if ($null -eq $file) {
      foreach ($p in @('assets\audio\', 'assets\course\')) {
        if ($rel.StartsWith($p)) {
          $file = Resolve-Inside (Join-Path $WebDir ('assets\assets\' + $rel.Substring(7)))
          if ($null -ne $file) { break }
        }
      }
    }
    $res = $ctx.Response
    # No wildcard CORS: this is a single-origin local bundle.
    $res.Headers.Add('X-Content-Type-Options', 'nosniff')
    $res.Headers.Add('X-Frame-Options', 'SAMEORIGIN')
    $res.Headers.Add('Referrer-Policy', 'no-referrer')
    $res.Headers.Add('Cache-Control', 'no-cache')
    if ($null -ne $file) {
      $ext = [IO.Path]::GetExtension($file).ToLower()
      $res.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { 'application/octet-stream' }
      $bytes = [IO.File]::ReadAllBytes($file)
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } else { $res.StatusCode = 404 }
    $res.OutputStream.Close()
  }
} finally { $listener.Stop() }
