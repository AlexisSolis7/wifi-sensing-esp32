#include <WiFi.h>

// --- Configuração do LED ---
#define LED_VERDE 2  // Conecte o LED verde no pino 18 (e um resistor ao GND)
// Dica: Se quiser testar com o azul interno agora mesmo, mude para 2

// --- Configurações de Conexão ---
const char* ssid     = "WiFi_Sensing_AP";
const char* password = "1234567890";

// --- Variáveis para a Task de Log ---
TaskHandle_t xLogTask;

void vDataLogTask(void *pvParameters);

void setup() {
  // Inicializa o pino do LED
  pinMode(LED_VERDE, OUTPUT);
  digitalWrite(LED_VERDE, LOW);

  // Inicializa Serial
  Serial.begin(115200);
  delay(1000);

  Serial.println("\n--- Iniciando Receptor WiFi Sensing ---");

  // Inicia conexão WiFi
  WiFi.begin(ssid, password);
  
  Serial.print("Conectando ao Transmissor");
  
  // Lógica de PISCAR enquanto não conecta
  while (WiFi.status() != WL_CONNECTED) {
    digitalWrite(LED_VERDE, HIGH); // Liga
    delay(250);
    digitalWrite(LED_VERDE, LOW);  // Desliga
    delay(250);
    Serial.print(".");
  }

  // SUCESSO: LED Verde aceso fixo
  digitalWrite(LED_VERDE, HIGH);
  Serial.println("\n[SUCESSO] Conectado ao Transmissor!");
  Serial.println("Aguardando estabilização...");
  delay(2000);

  // Cabeçalho do CSV
  Serial.println("timestamp_ms,rssi_valor");

  // Criação da Task via FreeRTOS
  xTaskCreatePinnedToCore(
    vDataLogTask,
    "LogTask",
    4096,
    NULL,
    1,
    &xLogTask,
    1
  );
}

void loop() {
  // Monitoramento da Conexão: Se cair, o LED apaga
  if (WiFi.status() == WL_CONNECTED) {
    digitalWrite(LED_VERDE, HIGH);
  } else {
    digitalWrite(LED_VERDE, LOW);
  }
  
  vTaskDelay(pdMS_TO_TICKS(500)); // Checa a cada meio segundo
}

// --- Implementação da Coleta e Log ---
void vDataLogTask(void *pvParameters) {
  for (;;) {
    if (WiFi.status() == WL_CONNECTED) {
      long rssi = WiFi.RSSI();
      unsigned long ts = millis();

      // Log para o Serial Monitor
      Serial.print(ts);
      Serial.print(",");
      Serial.println(rssi);
    } else {
      // Se cair o sinal, tenta reconectar silenciosamente
      WiFi.begin(ssid, password);
    }

    // Intervalo de amostragem: 100ms
    vTaskDelay(pdMS_TO_TICKS(100));
  }
}
