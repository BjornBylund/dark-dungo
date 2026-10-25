# Serves the web export (build/web) at http://localhost:8060 for local testing.
# Browsers can't run a Godot web export from file://; it has to come from a web server.
param(
    [int]$Port = 8060,
    [string]$Root = (Join-Path (Split-Path $PSScriptRoot -Parent) "build\web")
)
$ErrorActionPreference = "Stop"
$Root = [IO.Path]::GetFullPath($Root)
$types = @{
    ".html" = "text/html"; ".js" = "application/javascript"; ".wasm" = "application/wasm"
    ".pck" = "application/octet-stream"; ".png" = "image/png"; ".svg" = "image/svg+xml"
    ".json" = "application/json"; ".ico" = "image/x-icon"
}
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add("http://localhost:$Port/")
$listener.Start()
Write-Host "Serving $Root at http://localhost:$Port/ (Ctrl+C to stop)"
try {
    while ($listener.IsListening) {
        $context = $listener.GetContext()
        $response = $context.Response
        $path = [Uri]::UnescapeDataString($context.Request.Url.AbsolutePath.TrimStart("/"))
        if ($path -eq "") { $path = "index.html" }
        $file = [IO.Path]::GetFullPath((Join-Path $Root $path))
        if ($file.StartsWith($Root) -and (Test-Path $file -PathType Leaf)) {
            $bytes = [IO.File]::ReadAllBytes($file)
            $extension = [IO.Path]::GetExtension($file).ToLower()
            $response.ContentType = if ($types.ContainsKey($extension)) { $types[$extension] } else { "application/octet-stream" }
            $response.ContentLength64 = $bytes.Length
            $response.OutputStream.Write($bytes, 0, $bytes.Length)
        } else {
            $response.StatusCode = 404
        }
        $response.Close()
    }
} finally {
    $listener.Stop()
}
