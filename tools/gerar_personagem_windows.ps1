param(
    [string]$Blender = "",
    [string]$Godot = ""
)

$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$OutputEncoding = [Console]::OutputEncoding
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$Generator = Join-Path $PSScriptRoot "gerar_personagem_blender.py"
$Output = Join-Path $ProjectRoot "assets\personagem\lutador.glb"
$Backup = "$Output.anterior"
$HadPreviousModel = Test-Path $Output

if ([string]::IsNullOrWhiteSpace($Blender)) {
    $InstallRoot = Join-Path $env:ProgramFiles "Blender Foundation"
    $Blender = Get-ChildItem $InstallRoot -Filter "blender.exe" -File -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}

if ([string]::IsNullOrWhiteSpace($Blender) -or -not (Test-Path $Blender)) {
    throw "Blender não encontrado. Instale Blender 4.2 ou superior, ou use: .\tools\gerar_personagem_windows.ps1 -Blender 'C:\caminho\blender.exe'"
}

if ($HadPreviousModel) {
    Copy-Item $Output $Backup -Force
    # Sem remover o arquivo antigo, uma falha do Blender parecia sucesso:
    # o teste de existência encontrava o GLB que já estava na pasta.
    Remove-Item $Output -Force
}

Write-Host "Gerando boxeador humanoide com:" $Blender -ForegroundColor Cyan
& $Blender --background --python $Generator
$BlenderExitCode = $LASTEXITCODE

function Restore-PreviousModel {
    if ($HadPreviousModel -and (Test-Path $Backup)) {
        Copy-Item $Backup $Output -Force
        Write-Host "O modelo anterior foi restaurado; o jogo continua utilizável." -ForegroundColor Yellow
    }
}

if ($BlenderExitCode -ne 0) {
    Restore-PreviousModel
    throw "O Blender terminou com código $BlenderExitCode. O personagem novo NÃO foi criado."
}
if (-not (Test-Path $Output)) {
    Restore-PreviousModel
    throw "O Blender terminou sem criar $Output. O personagem novo NÃO foi criado."
}

# Validação independente do texto impresso pelo Blender: cabeçalho GLB,
# tamanho interno e contrato mínimo de mesh + skin + nove animações.
try {
    $Bytes = [System.IO.File]::ReadAllBytes($Output)
    if ($Bytes.Length -lt 20 -or [Text.Encoding]::ASCII.GetString($Bytes, 0, 4) -ne "glTF") {
        throw "cabeçalho glTF ausente"
    }
    $Version = [BitConverter]::ToUInt32($Bytes, 4)
    $DeclaredLength = [BitConverter]::ToUInt32($Bytes, 8)
    $JsonLength = [BitConverter]::ToUInt32($Bytes, 12)
    if ($Version -ne 2 -or $DeclaredLength -ne $Bytes.Length -or 20 + $JsonLength -gt $Bytes.Length) {
        throw "versão ou tamanho interno inconsistente"
    }
    $JsonText = [Text.Encoding]::UTF8.GetString($Bytes, 20, $JsonLength).TrimEnd([char[]]@(0, 32))
    $Gltf = $JsonText | ConvertFrom-Json
    if (@($Gltf.meshes).Count -lt 1) { throw "nenhuma malha exportada" }
    if (@($Gltf.skins).Count -lt 1) { throw "nenhum esqueleto/skin exportado" }
    if (@($Gltf.animations).Count -lt 9) { throw "menos de nove animações exportadas" }
}
catch {
    Remove-Item $Output -Force -ErrorAction SilentlyContinue
    Restore-PreviousModel
    throw "O arquivo criado não passou na validação: $($_.Exception.Message). O personagem novo NÃO foi instalado."
}

$SizeMb = [math]::Round((Get-Item $Output).Length / 1MB, 2)
Write-Host "GLB validado: $Output ($SizeMb MB, $(@($Gltf.animations).Count) animações)" -ForegroundColor Green

# Sem esta etapa o Blender termina corretamente, mas uma instalação do
# Godot que estava fechada pode continuar exibindo o cache do modelo leve.
# Quando encontramos o editor, fazemos a importação aqui mesmo. Se ele já
# estiver aberto, o monitor de arquivos dele fará o trabalho e pedimos só
# para aguardar a mensagem de importação.
if ([string]::IsNullOrWhiteSpace($Godot)) {
    $Godot = Get-ChildItem (Join-Path $env:USERPROFILE "Downloads") -Filter "Godot_v4*.exe" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1 -ExpandProperty FullName
}
$GodotAberto = Get-Process -Name "Godot*" -ErrorAction SilentlyContinue | Select-Object -First 1
if ($GodotAberto) {
    Write-Host "Godot aberto: aguarde IMPORTANDO terminar e feche/abra a cena uma vez." -ForegroundColor Yellow
}
elseif (-not [string]::IsNullOrWhiteSpace($Godot) -and (Test-Path $Godot)) {
    Write-Host "Atualizando o cache do personagem no Godot..." -ForegroundColor Cyan
    & $Godot --headless --editor --path $ProjectRoot --quit
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Personagem importado. Na Central deve aparecer HUMANOIDE BLENDER." -ForegroundColor Green
    }
    else {
        Write-Host "O GLB está pronto, mas o Godot não concluiu a importação automática. Abra o projeto e aguarde." -ForegroundColor Yellow
    }
}
else {
    Write-Host "GLB pronto. Abra o projeto no Godot e aguarde a reimportação." -ForegroundColor Yellow
}
