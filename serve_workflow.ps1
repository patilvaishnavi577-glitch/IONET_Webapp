# 1. Paths
$htmlSource = "C:\Users\patil\.gemini\antigravity-ide\brain\0f6f15d4-b7a9-4248-b927-15a6536daf59\IONET_Workflow.html"
$workspaceDir = "c:\Users\patil\IONET_WebApp"
$htmlDest = Join-Path $workspaceDir "IONET_Workflow.html"
$pdfDest = Join-Path $workspaceDir "IONET_Workflow.pdf"

# Copy HTML to workspace root
if (Test-Path $htmlSource) {
    Copy-Item $htmlSource $htmlDest -Force
}

# 2. Try to generate real PDF using Edge headless
$edgePaths = @(
    "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
    "C:\Program Files\Microsoft\Edge\Application\msedge.exe"
)
$edge = $edgePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($edge) {
    Write-Host "Rendering PDF from HTML via Edge..."
    Start-Process -FilePath $edge -ArgumentList "--headless", "--disable-gpu", "--no-pdf-header-footer", "--print-to-pdf=`"$pdfDest`"", "`"$htmlDest`"" -Wait
    if (Test-Path $pdfDest) {
        Write-Host "PDF created successfully: $pdfDest"
    }
}

# 3. Start Web Server
$port = 8080
Write-Host "=========================================================="
Write-Host " SERVER RUNNING AT: http://localhost:$port"
Write-Host " View HTML:  http://localhost:$port/IONET_Workflow.html"
if (Test-Path $pdfDest) {
    Write-Host " View/Download PDF: http://localhost:$port/IONET_Workflow.pdf"
}
Write-Host "=========================================================="

# Auto-open browser
Start-Process "http://localhost:$port/IONET_Workflow.html"

# Run Python server if python is installed, else use PowerShell HTTP listener
if (Get-Command python -ErrorAction SilentlyContinue) {
    Set-Location $workspaceDir
    python -m http.server $port
} else {
    $listener = New-Object System.Net.HttpListener
    $listener.Prefixes.Add("http://localhost:$port/")
    $listener.Start()
    Write-Host "PowerShell Server listening on http://localhost:$port/"
    try {
        while ($listener.IsListening) {
            $context = $listener.GetContext()
            $request = $context.Request
            $response = $context.Response
            $filename = $request.Url.LocalPath.TrimStart('/')
            if ([string]::IsNullOrWhiteSpace($filename)) {
                $filename = "IONET_Workflow.html"
            }
            $target = Join-Path $workspaceDir $filename
            if (Test-Path $target -PathType Leaf) {
                $bytes = [System.IO.File]::ReadAllBytes($target)
                if ($target.EndsWith(".pdf")) {
                    $response.ContentType = "application/pdf"
                    $response.AddHeader("Content-Disposition", "inline; filename=IONET_Workflow.pdf")
                } elseif ($target.EndsWith(".html")) {
                    $response.ContentType = "text/html; charset=utf-8"
                } else {
                    $response.ContentType = "application/octet-stream"
                }
                $response.ContentLength64 = $bytes.Length
                $response.OutputStream.Write($bytes, 0, $bytes.Length)
            } else {
                $response.StatusCode = 404
                $err = [System.Text.Encoding]::UTF8.GetBytes("File not found")
                $response.OutputStream.Write($err, 0, $err.Length)
            }
            $response.Close()
        }
    } finally {
        $listener.Stop()
    }
}
