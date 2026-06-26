#include <esp_now.h>
#include <WiFi.h>
#include <WebSocketsServer.h>

char NODE_ID = 'M';
uint8_t broadcastAddress[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};
WebSocketsServer webSocket = WebSocketsServer(81);

typedef struct struct_message {
    char id;
    int rssi_A, rssi_E, rssi_U, rssi_Y, rssi_M;
} struct_message;

int matrix[5][5];   
int baseline[5][5]; 
unsigned long ultimoCiclo = 0;
unsigned long ultimoLogSerial = 0;

// --- CALLBACK DE RECEPÇÃO ---
void OnDataRecv(const esp_now_recv_info_t * recv_info, const uint8_t *data, int len) {
    struct_message *msg = (struct_message*)data;
    int row = -1;
    
    if(msg->id == 'A') row = 0;
    else if(msg->id == 'E') row = 1;
    else if(msg->id == 'U') row = 2;
    else if(msg->id == 'Y') row = 3;
    else if(msg->id == 'M') row = 4;

    if(row != -1) {
        matrix[row][0] = msg->rssi_A;
        matrix[row][1] = msg->rssi_E;
        matrix[row][2] = msg->rssi_U;
        matrix[row][3] = msg->rssi_Y;
        matrix[row][4] = msg->rssi_M;
        if(row < 4) matrix[4][row] = recv_info->rx_ctrl->rssi; 
    }
}

// --- FUNÇÃO DE LOG SERIAL (Para o Pedro Henrique) ---
void imprimirMatrizSerial() {
    Serial.println("\n--- MATRIZ DE SINAIS (RSSI) ---");
    Serial.println("    A    E    U    Y    M");
    char nomes[] = {'A', 'E', 'U', 'Y', 'M'};
    for(int i=0; i<5; i++) {
        Serial.print(nomes[i]); Serial.print(" ");
        for(int j=0; j<5; j++) {
            Serial.printf("[%4d]", matrix[i][j]);
        }
        Serial.println();
    }
}

// --- FUNÇÃO PARA O FLUTTER (Telemetria Bruta) ---
void enviarMatrizFlutter() {
    String payload = "MATRIX:"; 
    for(int i=0; i<5; i++) {
        for(int j=0; j<5; j++) {
            payload += String(matrix[i][j]);
            if(!(i == 4 && j == 4)) payload += ",";
        }
    }
    webSocket.broadcastTXT(payload);
}

// --- FUNÇÃO DE DECISÃO (Lógica do Alexis) ---
void decidirZonaLocal() {
    int limiar = 15; 
    // Exemplo: Zona C (Link A-E)
    if (abs(matrix[0][1] - baseline[0][1]) > limiar) {
        webSocket.broadcastTXT("ALERTA:ZONA_C");
    }
}

void setup() {
    Serial.begin(115200);
    delay(2000);
    Serial.println("\n[SISTEMA] Iniciando Nó M...");

    WiFi.mode(WIFI_AP_STA);
    WiFi.softAP("Mesh_Sensing_Hub", "1234567890");
    
    if (esp_now_init() != ESP_OK) return;
    esp_now_register_recv_cb(OnDataRecv);

    esp_now_peer_info_t peerInfo = {};
    memcpy(peerInfo.peer_addr, broadcastAddress, 6);
    peerInfo.ifidx = WIFI_IF_STA;
    esp_now_add_peer(&peerInfo);

    webSocket.begin();

    // 1. Zera a matriz antes de começar
    for(int i=0; i<5; i++) for(int j=0; j<5; j++) matrix[i][j] = 0;

    // 2. FASE DE CALIBRAÇÃO (Não removida)
    Serial.println("[CALIBRANDO] Capturando Baseline da sala vazia...");
    unsigned long startCalib = millis();
    while(millis() - startCalib < 5000) {
        delay(10); // Aguarda pings chegarem
    }

    for(int i=0; i<5; i++) {
        for(int j=0; j<5; j++) {
            baseline[i][j] = matrix[i][j];
        }
    }
    Serial.println("[SUCESSO] Baseline definida!");
    imprimirMatrizSerial();
}

void loop() {
    webSocket.loop();

    // Ciclo de Processamento e Envio (200ms)
    if (millis() - ultimoCiclo > 200) {
        ultimoCiclo = millis();

        decidirZonaLocal();      // Lógica de alerta
        enviarMatrizFlutter();   // Telemetria bruta para o App

        // Ping da malha
        struct_message myMsg; myMsg.id = 'M';
        esp_now_send(broadcastAddress, (uint8_t *) &myMsg, sizeof(myMsg));
    }

    // Ciclo de Log Serial (3 segundos - Não removido)
    if (millis() - ultimoLogSerial > 3000) {
        ultimoLogSerial = millis();
        imprimirMatrizSerial();
    }
}
