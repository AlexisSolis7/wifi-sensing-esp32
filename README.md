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

## Próxima Etapa: Mapa de Movimento com 3 ou 4 ESP32

A próxima evolução do projeto é usar 3 ou 4 módulos ESP32 distribuídos pelo ambiente para estimar por onde uma pessoa está se movendo. A ideia é representar o ambiente como um quadrado ou retângulo no aplicativo Flutter e exibir um ponto se deslocando conforme os sinais Wi-Fi forem alterados.

Exemplo de posicionamento com 4 ESP32:

```text
ESP A ---------------- ESP B
  |                      |
  |       ambiente       |
  |                      |
ESP D ---------------- ESP C
```

Neste modelo, os ESP32 ficam em posições conhecidas. Quando uma pessoa passa pelo ambiente, o corpo interfere no sinal Wi-Fi entre os dispositivos. Essa interferência altera os valores de RSSI medidos. Comparando essas alterações, o sistema pode estimar a região mais provável onde houve movimento.

### Estratégia com RSSI

Como primeira versão, a localização será feita usando RSSI, pois essa informação já é simples de obter com a biblioteca WiFi do ESP32.

O processo esperado é:

1. Posicionar 3 ou 4 ESP32 em pontos fixos do ambiente.
2. Medir o RSSI entre os dispositivos com o ambiente vazio.
3. Usar esses valores como referência de calibração.
4. Medir continuamente o RSSI durante o funcionamento.
5. Comparar o RSSI atual com o RSSI de referência.
6. Identificar quais caminhos de sinal foram mais afetados.
7. Estimar uma posição aproximada da pessoa.
8. Enviar a posição estimada para o app Flutter.
9. Mostrar no app um ponto se movendo dentro do mapa.

Com 4 ESP32, é possível analisar vários caminhos de sinal, por exemplo:

```text
A-B
A-C
A-D
B-C
B-D
C-D
```

Quanto mais caminhos forem observados, melhor tende a ser a estimativa. Porém, como o RSSI sofre bastante variação por paredes, móveis, distância, reflexões e ruído do ambiente, a posição exibida no app deve ser tratada como uma estimativa aproximada, não como uma localização exata.

### Representação no Aplicativo

No app Flutter, o ambiente pode ser desenhado como um mapa simples:

```text
+----------------------+
| ESP A          ESP B |
|                      |
|          o           |
|                      |
| ESP D          ESP C |
+----------------------+
```

O ponto `o` representa a posição estimada da pessoa. Conforme o backend ou ESP coordenador calcular novas posições, o app atualiza esse ponto em tempo real.

Para melhorar a visualização, o app também pode exibir:

- os ESP32 fixos nos cantos do mapa;
- o ponto estimado da pessoa;
- um rastro do caminho percorrido;
- a intensidade do movimento detectado;
- o nível de confiança da estimativa;
- gráficos dos valores de RSSI para testes e calibração.

### Limitações Esperadas

Usar RSSI permite criar uma primeira versão funcional, mas existem limitações:

- o sinal pode variar mesmo sem movimento;
- a posição estimada pode oscilar;
- ambientes com muitos obstáculos podem gerar falsos positivos;
- a precisão depende de uma boa calibração inicial;
- o resultado tende a ser melhor para detectar regiões do que coordenadas exatas.

Por isso, a primeira meta deve ser identificar zonas aproximadas de movimento. Depois, com filtros e calibração, o sistema pode evoluir para um ponto mais estável no mapa.

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


# (Projeto Final) Wi-Fi Sensing: Detecção de Movimento e Localização em Grade 5x5

Este projeto utiliza a tecnologia de **Wi-Fi Sensing** para monitorar ambientes internos de forma não invasiva. Através da análise de rádio (RSSI), o sistema identifica a presença e a localização exata de pessoas em uma grade de **25 zonas de detecção**, utilizando apenas 5 módulos ESP32.

## Evolução Técnica
O projeto superou o modelo convencional Ponto-a-Ponto, evoluindo para uma arquitetura de **Rede em Malha (Full Mesh)**. Esta abordagem transforma cada sensor em um transmissor e receptor simultâneo, criando uma teia densa de feixes de rádio que eliminam pontos cegos e permitem a triangulação do movimento.

## Layout de Sensoriamento (Grade de 25 Zonas)
O sistema divide a sala em 25 quadrados (Zonas A a Y). O posicionamento estratégico dos sensores permite que cada zona seja atravessada por múltiplos links de rádio.

![Layout das 25 Zonas](layout_zonas.jpg)
*Figura 1: Grade de monitoramento com os 5 nós ESP32 (A, E, U, Y nas arestas e M ao centro).*

## Infraestrutura e Protocolos
- **Topologia:** Full Mesh (Malha Completa).
- **Protocolo de Malha:** ESP-NOW (Baixa latência, sem necessidade de roteador).
- **Protocolo de Aplicação:** WebSockets (Porta 81) para integração com dispositivos móveis.
- **Taxa de Amostragem:** 10Hz (10 pings de sensoriamento por segundo).

### Funcionamento dos Nós:
- **Nós Periféricos (A, E, U, Y):** Atuam como sensores de borda. Eles medem o sinal de todos os vizinhos e enviam um "relatório de vizinhança" para o centro.
- **Nó M (Centro/Gateway):** Atua como o cérebro do sistema. Ele consolida os relatórios, monta uma **Matriz de Sinais 5x5** e transmite a telemetria bruta e alertas de zona para o aplicativo Flutter.

## Funcionalidades de Firmware
- **Auto-Calibração Inteligente:** Ao iniciar, o sistema realiza uma leitura de 5 segundos do ambiente vazio para definir a *baseline* (referência) de rádio de forma automática.
- **Relatório de Vizinhança:** Implementação de estruturas de dados que permitem ao Nó M "enxergar" o que acontece entre os sensores periféricos, mesmo sem visão direta.
- **Programação Não-Bloqueante:** Lógica baseada em `millis()` que permite ao ESP32 gerenciar o rádio de sensoriamento e o servidor de internet simultaneamente, sem perdas de conexão.
- **Matriz de Diagnóstico:** Sistema de log via Serial Monitor que exibe a saúde de todos os 20 links de rádio em tempo real.

## Estrutura de Dados (Telemetria)
O sistema envia para o Flutter uma string de telemetria completa no formato:
`MATRIX:v1,v2,v3...v25`
Isso permite que o aplicativo gere **Mapas de Calor (Heatmaps)** e identifique a posição exata do usuário no grid.

## Organização do Repositório
- `/nos_perifericos`: Firmware único para os nós A, E, U e Y (configuráveis via NODE_ID).
- `/no_central`: Firmware do Hub Central (Gateway WebSocket + Matriz de Sinais).

---


## Equipe e Responsabilidades

- **Mauricio Darabas:** infraestrutura e firmware base dos ESP32.
- **Pedro Henrique:** coleta de dados e processamento/análise dos sinais.
- **Alexis Solis:** desenvolvimento do front em Flutter, integração via WebSocket e interface de alerta.
