param(
    [string]$Blender = ""
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Generator = Join-Path $PSScriptRoot "gerar_personagem_blender.py"
$Output = Join-Path $ProjectRoot "assets\personagem\lutador.glb"

if ([string]::IsNullOrWhiteSpace($Blender)) {
    $InstallRoot = Join-Path $env:ProgramFiles "Blender Foundation"
    $Blender = Get-ChildItem $InstallRoot -Filter "blender.exe" -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

if ([string]::IsNullOrWhiteSpace($Blender) -or -not (Test-Path $Blender)) {
    throw "Blender não encontrado. Instale Blender 4.2 ou superior, ou use: .\tools\gerar_personagem_windows.ps1 -Blender 'C:\caminho\blender.exe'"
}

if (Test-Path $Output) {
    Copy-Item $Output "$Output.anterior" -Force
}

Write-Host "Gerando boxeador humanoide com:" $Blender -ForegroundColor Cyan
& $Blender --background --python $Generator
if ($LASTEXITCODE -ne 0) {
    throw "O Blender terminou com código $LASTEXITCODE"
}
if (-not (Test-Path $Output)) {
    throw "O Blender terminou, mas não criou $Output"
}

$SizeMb = [math]::Round((Get-Item $Output).Length / 1MB, 2)
Write-Host "GLB criado: $Output ($SizeMb MB)" -ForegroundColor Green
Write-Host "Abra o projeto no Godot e aguarde a reimportação antes de testar." -ForegroundColor Yellow
