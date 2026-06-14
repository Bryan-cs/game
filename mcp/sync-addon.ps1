# Copia el addon al proyecto del juego. Uso: .\sync-addon.ps1
$dest = "C:\Users\braya\OneDrive\Documents\create and edit\nuevo-proyecto-de-juego\addons\claude_bridge"
robocopy "addons\claude_bridge" $dest /MIR /XF *.uid /NJH /NJS
if ($LASTEXITCODE -le 7) { Write-Host "Sync OK -> $dest"; exit 0 } else { Write-Host "Sync FALLO ($LASTEXITCODE)"; exit 1 }
