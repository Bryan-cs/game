# Genera los concepts de UI de Nightfall Survivors con Gemini (Nano Banana).
$ErrorActionPreference = "Stop"
$key = (Get-Content "$env:USERPROFILE\.claude\.env" | Where-Object { $_ -match '^GEMINI_API_KEY=' }) -replace '^GEMINI_API_KEY=', ''
$salida = Join-Path $PSScriptRoot "..\art\concepts"
New-Item -ItemType Directory -Force $salida | Out-Null

$estilo = @"
Ultra detailed AAA indie dark fantasy game UI concept art for a 3D survivor roguelike called "NIGHTFALL SURVIVORS".
Style: dark fantasy, gothic atmosphere, cinematic UI, premium Steam-quality, inspired by Diablo, V Rising, Hades, Soulstone Survivors.
High contrast, purple and crimson magical energy, dark blue moonlight, volumetric fog, dramatic shadows, floating embers and particles, soft bloom.
Color palette: dark black, midnight blue, purple glow; crimson red, silver metal, dark gray stone; gold legendary highlights.
Clean modern fantasy typography, thin gothic borders, black metallic button textures with purple hover glow.
16:9 widescreen, 4K quality, highly polished professional game UI showcase. Looks like a real released game.
"@

$secciones = @(
    @{ nombre = "menu_principal"; prompt = "$estilo`nSCENE: Cinematic MAIN MENU screen. Background: massive gothic castle in the distance, giant blood moon, dark dead forest, purple mist, floating embers, rain, ruined stones. A dark armored knight seen from behind standing on a cliff, purple glowing sword, cape in the wind, corruption aura. Left vertical menu with elegant dark metallic buttons labeled exactly: JUGAR, PERSONAJES, MEJORAS, RELIQUIAS, BESTIARIO, DESAFIOS, AJUSTES, SALIR. Top: metallic gothic logo 'NIGHTFALL SURVIVORS' with purple magical cracks on dark silver texture." },
    @{ nombre = "seleccion_personajes"; prompt = "$estilo`nSCENE: CHARACTER SELECTION screen in an epic circular dark stone chamber with giant pillars, purple fire braziers, rolling floor fog, corrupted altar aesthetic. Five characters on elevated stone pedestals: Shadow Knight (dark heavy armor, purple glowing sword, hero spotlight), Blood Mage (hooded robe, floating blood orbs), Moon Huntress (dual daggers, silver moon armor), Plague Alchemist (plague doctor mask, toxic green flasks, poison smoke), Infernal Berserker (huge axe, fire cracks, massive silhouette). Right UI panel showing character name, difficulty stars, stat bars, passive ability, starting weapon, short lore. Bottom button: 'SELECCIONAR'. Cinematic angle, depth of field on selected character." },
    @{ nombre = "arbol_talentos"; prompt = "$estilo`nSCENE: TALENT TREE / UPGRADES screen. Background: dark void with ancient glowing runes and flowing magical energy. Circular node layout talent tree with connected glowing lines: purple unlocked nodes, dark locked nodes, golden legendary nodes, animated magical pulse. UI side panels with upgrade descriptions, gold cost display, skill categories, reset button, currency counters. Arcane, elegant dark fantasy HUD." },
    @{ nombre = "reliquias"; prompt = "$estilo`nSCENE: RELIC MENU. Center: giant floating corrupted crystal radiating purple energy with a rotating wheel of relics around it: fire relic, shadow relic, poison relic, ice relic, blood relic, lightning relic — each with distinct elemental glow. UI showing relic rarity tiers, stats, upgrade buttons, equipped slots. Ancient forbidden magic atmosphere, floating dust, glowing symbols on stone." },
    @{ nombre = "ajustes"; prompt = "$estilo`nSCENE: SETTINGS menu. Background: blurred dark gothic environment with a large magical circular rune symbol. Elegant minimal dark settings panel with tabs: Graficos, Audio, Controles, Idioma. Purple sliders for brightness, camera shake toggle, damage numbers toggle, tutorials toggle. Metallic thin borders, clean readable modern fantasy UI." }
)

foreach ($modelo in @("gemini-3-pro-image-preview", "gemini-2.5-flash-image")) {
    $fallos = 0
    foreach ($s in $secciones) {
        $destino = Join-Path $salida "$($s.nombre).png"
        if (Test-Path $destino) { continue }
        $cuerpo = @{
            contents = @(@{ parts = @(@{ text = $s.prompt }) })
            generationConfig = @{ responseModalities = @("IMAGE"); imageConfig = @{ aspectRatio = "16:9" } }
        } | ConvertTo-Json -Depth 8
        try {
            $r = Invoke-RestMethod -Method Post -Uri "https://generativelanguage.googleapis.com/v1beta/models/${modelo}:generateContent?key=$key" -ContentType "application/json" -Body $cuerpo -TimeoutSec 180
            $b64 = ($r.candidates[0].content.parts | Where-Object { $_.inlineData }).inlineData.data
            if ($b64) {
                [IO.File]::WriteAllBytes($destino, [Convert]::FromBase64String($b64))
                Write-Output "ok $($s.nombre) ($modelo)"
            } else { Write-Output "sin imagen: $($s.nombre)"; $fallos++ }
        } catch {
            Write-Output "fallo $($s.nombre) con ${modelo}: $($_.Exception.Message)"
            $fallos++
        }
    }
    if ($fallos -eq 0) { break }
}
Get-ChildItem $salida | Select-Object Name, @{n='KB';e={[math]::Round($_.Length/1KB)}}
