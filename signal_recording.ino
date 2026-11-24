// signal_recording (versión EOG - 1 canal)
// 50 Hz, salida con promedio de 20 lecturas durante 20 ms.
//  - 20 ms = 1 ciclo de la red eléctrica -> cancela ruido de 50 Hz.
//  - Promediar da mayor resolución con 2 decimales.

const int PIN_EOG = A0;

const unsigned long PERIODO_US = 1000;  // una lectura cada 1 ms
const int N_PROMEDIO = 20;              // 20 x 1 ms = 20 ms -> salida a 50 Hz

unsigned long tAnterior = 0;
unsigned long suma = 0;
int n = 0;

void setup() {
  Serial.begin(115200);
  tAnterior = micros();
}

void loop() {
  if (micros() - tAnterior >= PERIODO_US) {
    tAnterior += PERIODO_US;

    suma += analogRead(PIN_EOG);
    n++;

    if (n >= N_PROMEDIO) {
      // Formato de salida: "valor\n" (con 2 decimales)
      Serial.println(suma / (float)N_PROMEDIO, 2);
      suma = 0;
      n = 0;
    }
  }
}
