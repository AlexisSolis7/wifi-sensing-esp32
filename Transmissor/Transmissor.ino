/* 
 * Issue 1.1 - ESP32 Transmissor (Beacon) com Feedback Visual
 * Objetivo: Criar a rede e indicar se há receptores conectados.
 */
#include <WiFi.h>

// --- Configuração de Hardware ---
#define LED_VERDE 2 // Pino do LED Verde (mesmo padrão do receptor)

const char* ssid = "WiFi_Sensing_AP";
const char* password = "1234567890";

void setup() {
  // Configura o pino do LED
  pinMode(LED_VERDE, OUTPUT);
  digitalWrite(LED_VERDE, LOW);

  Serial.begin(115200);
  delay(1000);
  
  Serial.println("\n--- Configurando Transmissor (AP) ---");
  
  // Configura o ESP32 como Access Point
  WiFi.softAP(ssid, password);

  IPAddress IP = WiFi.softAPIP();
  Serial.print("IP do Ponto de Acesso: ");
  Serial.println(IP);
  Serial.println("Transmissor Ativo. Aguardando conexão do receptor...");
}

void loop() {
  // Verifica quantos dispositivos (stations) estão conectados
  int numEstacoes = WiFi.softAPgetStationNum();

  if (numEstacoes > 0) {
    // Se houver pelo menos 1 conexão (Receptor do Pedro Henrique ativo)
    digitalWrite(LED_VERDE, HIGH); // LED fica aceso fixo
  } else {
    // Se não houver ninguém conectado
    // Inverte o estado do LED para piscar (500ms ligado, 500ms desligado)
    digitalWrite(LED_VERDE, !digitalRead(LED_VERDE));
    delay(500); 
  }
  
  // Pequeno delay para estabilidade do loop
  delay(100); 
}
