# App Monitoramento Wi-Fi Sensing

Aplicativo Flutter para visualizar a malha ESP32 do projeto Wi-Fi Sensing.

## Protocolo esperado

O app conecta por WebSocket ao gateway ESP32 na porta `81`.

Endpoint padrao da versao nova:

```text
ws://192.168.4.1:81
```

Mensagens aceitas:

```text
MATRIX:v1,v2,v3...v25
ALERTA:ZONA_C
MOVIMENTO_DETECTADO
```

- `MATRIX:` representa a matriz 5x5 de RSSI entre os nos `A`, `E`, `U`, `Y` e `M`.
- `ALERTA:ZONA_X` destaca a zona detectada na grade 5x5.
- `MOVIMENTO_DETECTADO` mantem compatibilidade com o firmware antigo.

## Como rodar

```bash
flutter pub get
flutter run
```

Para testar no navegador:

```bash
flutter run -d chrome
```

## Observacoes

No Android, o app usa WebSocket sem TLS (`ws://`) para conversar com o ESP32 em rede local. Por isso o manifest principal habilita `INTERNET` e `usesCleartextTraffic`.

## Calibracao no app

O app pode calibrar sem alterar o firmware dos ESP32:

1. Posicione os 5 ESPs e deixe o ambiente vazio.
2. Conecte no WebSocket do no `M`.
3. Clique em `Calibrar`.
4. O app captura 75 matrizes `MATRIX:` por cerca de 15 segundos e calcula a media e o ruido normal de cada link.
5. Durante o uso, o app mostra a variacao de cada link em relacao a essa baseline.

Para uma primeira versao de localizacao, a grade 5x5 e dividida em 4 quadrantes. O app estima o quadrante dominante usando os links mais alterados, descartando links instaveis aprendidos na calibracao e exigindo margem de confianca antes de pintar uma regiao em vermelho.

## Organizacao do codigo

O app foi organizado em camadas simples:

- `domain/`: entidades, constantes e mensagens de telemetria.
- `services/`: parser WebSocket, normalizacao de endpoint e analise RSSI.
- `home_controller.dart`: orquestra estado, WebSocket, calibracao e decisao de regiao.
- `home_page.dart`: interface visual e componentes do dashboard.

Essa separacao mantem as regras principais testaveis sem depender da tela.
