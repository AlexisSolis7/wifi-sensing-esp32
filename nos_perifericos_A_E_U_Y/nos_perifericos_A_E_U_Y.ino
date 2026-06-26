#include <esp_now.h>
#include <WiFi.h>

// --- CONFIGURAÇÃO ---
char NODE_ID = 'Y'; // MUDE PARA 'A', 'E', 'U' ou 'Y' conforme a placa

typedef struct struct_message {
    char id;
    int rssi_A, rssi_E, rssi_U, rssi_Y, rssi_M;
} struct_message;

struct_message myReport;
uint8_t broadcastAddress[] = {0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF};

void OnDataRecv(const esp_now_recv_info_t * recv_info, const uint8_t *data, int len) {
    int rssi = recv_info->rx_ctrl->rssi;
    struct_message *incoming = (struct_message*)data;
    char sender = incoming->id;

    if(sender == 'A') myReport.rssi_A = rssi;
    else if(sender == 'E') myReport.rssi_E = rssi;
    else if(sender == 'U') myReport.rssi_U = rssi;
    else if(sender == 'Y') myReport.rssi_Y = rssi;
    else if(sender == 'M') myReport.rssi_M = rssi;
}

void setup() {
    Serial.begin(115200);
    delay(1000);
    Serial.printf("\n[SISTEMA] Iniciando Nó Periférico %c...\n", NODE_ID);

    WiFi.mode(WIFI_STA);
    WiFi.disconnect();

    if (esp_now_init() != ESP_OK) {
        Serial.println("[ERRO] Falha ao iniciar ESP-NOW");
        return;
    }
    
    esp_now_register_recv_cb(OnDataRecv);

    esp_now_peer_info_t peerInfo = {};
    memcpy(peerInfo.peer_addr, broadcastAddress, 6);
    peerInfo.ifidx = WIFI_IF_STA;
    
    if (esp_now_add_peer(&peerInfo) != ESP_OK) {
        Serial.println("[ERRO] Falha ao adicionar Peer");
        return;
    }

    myReport.id = NODE_ID;
    Serial.println("[SUCESSO] Sensor operando em malha. Enviando pings...");
}

void loop() {
    esp_now_send(broadcastAddress, (uint8_t *) &myReport, sizeof(myReport));
    
    // Pisca o LED para confirmar que está transmitindo
    digitalWrite(2, HIGH);
    delay(50);
    digitalWrite(2, LOW);
    
    delay(150); 
}
