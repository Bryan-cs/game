# Construye el ZIP vendible en dist/. Uso: .\package-dist.ps1 [-Version 1.0.0]
param([string]$Version = "1.0.0")

$ErrorActionPreference = "Stop"
$name = "claude-bridge-godot-v$Version"
$stage = Join-Path $env:TEMP $name
$dist = Join-Path $PSScriptRoot "dist"

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force "$stage\server" | Out-Null
New-Item -ItemType Directory -Force $dist | Out-Null

# Plugin de Godot (sin .uid: Godot los regenera por proyecto)
robocopy "$PSScriptRoot\addons\claude_bridge" "$stage\addons\claude_bridge" /MIR /XF *.uid /NJH /NJS | Out-Null
if ($LASTEXITCODE -gt 7) { throw "robocopy addon fallo ($LASTEXITCODE)" }

# Servidor MCP (sin node_modules: el cliente hace npm install)
Copy-Item "$PSScriptRoot\server\index.js" "$stage\server\"
Copy-Item -Recurse "$PSScriptRoot\server\tools" "$stage\server\tools"
Copy-Item "$PSScriptRoot\server\package.json" "$stage\server\"
Copy-Item "$PSScriptRoot\server\package-lock.json" "$stage\server\"

# Documentación y licencia obligatoria (MIT de los modulos portados)
Copy-Item "$PSScriptRoot\instalacion.md" "$stage\"
Copy-Item "$PSScriptRoot\README.md" "$stage\"
Copy-Item "$PSScriptRoot\docs\superpowers\reference\godot-mcp-ck\LICENSE" "$stage\LICENSE-godot-mcp-ck.txt"

$zip = Join-Path $dist "$name.zip"
if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path "$stage\*" -DestinationPath $zip
Remove-Item -Recurse -Force $stage

$size = [math]::Round((Get-Item $zip).Length / 1KB)
Write-Host "OK -> $zip ($size KB)"
exit 0
