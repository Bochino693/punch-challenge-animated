# Câmera nativa no Windows

O jogo captura webcams USB diretamente pelo **Windows Media Foundation**,
através do addon `CameraServerExtension`. O pacote já contém a DLL x86_64;
não há Python, OpenCV, serviço ou driver virtual para instalar.

## Uso

1. Conecte a câmera USB.
2. Abra o jogo.
3. Pressione F9 para ver a prévia e usar **TESTAR FOTO**.

Se a câmera for conectada depois da abertura, a descoberta é repetida a cada
2,5 segundos somente enquanto não existe um feed. **PROCURAR DE NOVO** força
a enumeração imediatamente. Depois que o vídeo abre, o jogo mantém o mesmo
feed ativo; ele não reinicia a câmera por atraso ou por foto.

## Vídeo e fotografia

- A prévia é uma `CameraTexture`, atualizada diretamente pelo backend nativo.
- O formato preferido é 1280×720 a 30 fps; 4K recebe baixa prioridade para
  evitar carga USB/GPU desnecessária.
- Durante a pose, o obturador escolhe o melhor quadro recebido.
- Somente o retrato escolhido fica congelado brevemente. O feed ao vivo não é
  fechado e a gravação JPEG do ranking ocorre fora da linha principal.

## Diagnóstico PowerShell

`tools/camera_windows.ps1` apenas consulta os dispositivos PnP, a privacidade
da webcam e programas que podem estar usando a câmera. **RESOLVER ACESSO**
altera somente as permissões de câmera do usuário atual. O PowerShell não
transporta vídeo e não abre a webcam.

## Exportação

Exporte para Windows x86_64 e copie a pasta inteira. O arquivo
`libcameraserver-extension.windows.dll` precisa acompanhar o executável.
O verificador `sh tools/conferir_exportacao.sh` confirma a presença tanto da
extensão da câmera quanto da extensão serial do Arduino.

## Arduino

A câmera e a serial são addons independentes. Nenhum arquivo em `arduino/`,
`scripts/serial/` ou `addons/gdserial/` é alterado por esta integração.

## Origem e licença

`CameraServerExtension` é distribuído sob licença MIT. A licença original
está em `addons/CameraServerExtension/LICENSE`.
