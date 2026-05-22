# Detecção de Movimento via Wi-Fi Sensing 

## Descrição do Projeto
Este projeto explora o uso de sinais Wi-Fi para detectar a presença e o movimento de pessoas em ambientes internos, utilizando a interferência causada pelo corpo humano no sinal de rádio. O sistema utiliza dois módulos ESP32 para monitorar flutuações no sinal (RSSI/CSI) e disparar alertas de movimento sem o uso de câmeras.

## Componentes e Materiais
* 2x ESP32: Responsáveis pela transmissão e recepção dos sinais.
* Cabos Micro-USB

## Tecnologias e Softwares
* C/C++.
* Arduino IDE & Bibliotecas CSI: Para programação e extração de dados da camada física.
* Scripts de Processamento de Sinais (MATLAB).

## Equipe e Responsabilidades 
* **Mauricio Darabas:** Infraestrutura e Firmware base.
* **Pedro Henrique:** Coleta de dados e Processamento de Sinais.
* **Alexis Solis:** Lógica de Alarme, Filtros C++ e Validação em Campo.
