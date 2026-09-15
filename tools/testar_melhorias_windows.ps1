param(
    [string]$Godot = "",
    [switch]$PularGeracaoGLB
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot

if (-not $PularGeracaoGLB) {
    & (Join-Path $PSScriptRoot "gerar_personagem_windows.ps1")
}

$Python = Get-Command python -ErrorAction SilentlyContinue
if (-not $Python) { $Python = Get-Command py -ErrorAction SilentlyContinue }
if ($Python) {
    & $Python.Source (Join-Path $PSScriptRoot "validar_glb.py")
    if ($LASTEXITCODE -ne 0) { throw "O GLB não passou na validação de rig/animações" }
}

if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = Get-ChildItem (Join-Path $env:USERPROFILE "Downloads") -Filter "Godot_v4*.exe" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
if ([string]::IsNullOrWhiteSpace($Godot) -or -not (Test-Path $Godot)) {
    throw "Godot não encontrado. Informe: -Godot 'C:\caminho\Godot_v4.6.1-stable_win64.exe'"
}

Write-Host "Importando recursos no Godot..." -ForegroundColor Cyan
& $Godot --headless --editor --path $ProjectRoot --quit
if ($LASTEXITCODE -ne 0) { throw "Falha ao importar recursos no Godot" }

$Tests = @(
    "tests/test_core.gd",
    "tests/test_arena.gd",
    "tests/test_camera_viva.gd",
    "tests/test_dois_socos.gd",
    "tests/test_render_flow.gd",
    "tests/test_show_flow.gd",
    "tests/test_linha_serial.gd",
    "tests/test_descoberta_da_porta.gd",
    "tests/test_native_reentry.gd",
    "tests/test_ponte_teimosa.gd",
    "tests/test_serial_teimoso.gd"
)

foreach ($Test in $Tests) {
    Write-Host "TESTE $Test" -ForegroundColor Yellow
    & $Godot --headless --path $ProjectRoot --script (Join-Path $ProjectRoot $Test)
    if ($LASTEXITCODE -ne 0) {
        throw "Teste falhou: $Test"
    }
}

Write-Host "Todos os testes concluídos. Abrindo o jogo para inspeção visual." -ForegroundColor Green
& $Godot --path $ProjectRoot --editor
