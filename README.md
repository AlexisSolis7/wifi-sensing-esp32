# Detecção de Movimento via Wi-Fi Sensing com ESP32

## Descrição do Projeto

Este projeto explora o uso de sinais Wi-Fi para detectar presença e movimento em ambientes internos, sem o uso de câmeras. A proposta é observar alterações no sinal entre dois módulos ESP32 e transformar essas variações em um alerta visual em tempo real.

No estado atual do código, a detecção é feita a partir do valor de RSSI medido pelo ESP32 receptor. Quando o sinal recebido fica abaixo de um limiar definido no firmware, o receptor envia um evento de movimento para o aplicativo de monitoramento.

## Arquitetura

O sistema é composto por três partes principais:

1. **ESP32 Transmissor**
   - Cria uma rede Wi-Fi própria chamada `WiFi_Sensing_AP`.
   - Atua como ponto de acesso para o ESP32 receptor.
   - Usa o LED integrado para indicar se há algum dispositivo conectado.

2. **ESP32 Receptor**
   - Conecta-se à rede criada pelo transmissor.
   - Mede continuamente o RSSI do sinal Wi-Fi.
   - Envia logs no formato CSV pelo Serial Monitor.
   - Dispara o evento `MOVIMENTO_DETECTADO` via WebSocket quando identifica uma queda no sinal.

3. **Aplicativo de Monitoramento**
   - Desenvolvido em Flutter.
   - Conecta-se ao WebSocket do ESP32 receptor.
   - Exibe uma tela verde enquanto aguarda movimento.
   - Exibe uma tela vermelha com o aviso `MOVIMENTO!` quando recebe o alerta.

## Fluxo de Funcionamento

```text
ESP32 Transmissor
    cria a rede Wi-Fi
        ↓
ESP32 Receptor
    conecta na rede e mede RSSI
        ↓
WebSocket
    envia MOVIMENTO_DETECTADO
        ↓
App Flutter
    mostra o alerta visual
```

## Estrutura do Repositório

```text
.
├── Transmissor/
│   └── Transmissor.ino
├── Receptor/
│   └── Receptor.ino
└── app_monitoramento/
    └── lib/
        ├── main.dart
        ├── routes/
        └── modules/home/
```

## Componentes e Materiais

- 2 módulos ESP32.
- Cabos Micro-USB.
- Computador com Arduino IDE.
- Dispositivo ou emulador para executar o app Flutter.

## Tecnologias Utilizadas

- **C/C++ com Arduino IDE** para o firmware dos ESP32.
- **Biblioteca WiFi do ESP32** para criação da rede e leitura de RSSI.
- **WebSocketsServer** no ESP32 receptor para comunicação em tempo real.
- **Flutter** para o aplicativo de monitoramento.
- **GetX** para organização de rotas, binding e estado no app Flutter.
- **web_socket_channel** para conexão WebSocket no Flutter.

## Como Executar

### 1. Transmissor

Abra `Transmissor/Transmissor.ino` na Arduino IDE, selecione a placa ESP32 e envie o código para o primeiro módulo.

Após iniciar, o ESP32 cria a rede:

```text
SSID: WiFi_Sensing_AP
Senha: 1234567890
```

### 2. Receptor

Abra `Receptor/Receptor.ino` na Arduino IDE e envie o código para o segundo módulo ESP32.

O receptor se conecta ao transmissor, inicia um servidor WebSocket na porta `81` e imprime no Serial Monitor o IP que deve ser usado pelo aplicativo Flutter.

### 3. Aplicativo Flutter

Entre na pasta do app:

```bash
cd app_monitoramento
```

Instale as dependências:

```bash
flutter pub get
```

Execute o aplicativo:

```bash
flutter run
```

O app atualmente tenta se conectar ao endereço:

```text
ws://192.168.4.2:81
```

Caso o ESP32 receptor receba outro IP, atualize esse endereço em `app_monitoramento/lib/modules/home/home_controller.dart`.

## Estado Atual

- O transmissor já cria a rede Wi-Fi.
- O receptor já conecta, mede RSSI e envia alerta via WebSocket.
- O app Flutter já recebe o evento e mostra o alerta visual.
- A detecção atual usa um limiar simples de RSSI (`rssi < -65`).

## Possíveis Melhorias

- Tornar o IP do receptor configurável no aplicativo.
- Exibir o valor de RSSI em tempo real no app.
- Adicionar gráfico das leituras de RSSI.
- Calibrar o limiar de detecção conforme o ambiente.
- Implementar filtros para reduzir falsos positivos.
- Evoluir a coleta para CSI, caso o objetivo seja uma análise mais precisa da camada física.

## Equipe e Responsabilidades

- **Mauricio Darabas:** infraestrutura e firmware base dos ESP32.
- **Pedro Henrique:** coleta de dados e processamento/análise dos sinais.
- **Alexis Solis:** desenvolvimento do front em Flutter, integração via WebSocket e interface de alerta.
