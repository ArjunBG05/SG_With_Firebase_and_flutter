// Smart Guardian firmware: MAX30102 + DS18B20 + NEO-6M GPS -> Firestore
// PROTOTYPE ONLY: BPM and SpO2 are not medically validated.
//
// Wiring: MAX30102 SDA=GPIO21, SCL=GPIO22 | DS18B20 data=GPIO4 (4.7k pull-up)
//         NEO-6M TX -> GPIO16 (RX2), NEO-6M RX -> GPIO17 (TX2)
// Libraries: SparkFun MAX3010x, DallasTemperature, OneWire, TinyGPSPlus
#include <WiFi.h>
#include <Wire.h>
#include <OneWire.h>
#include <DallasTemperature.h>
#include "secrets.h"
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <TinyGPSPlus.h>
#include "MAX30105.h"
#include "spo2_algorithm.h"

#define ONE_WIRE_PIN 4
#define FINGER_THRESHOLD 50000  // IR below this = no finger
#define GPS_RX_PIN 16           // ESP32 pin connected to GPS TX  (change if yours differs)
#define GPS_TX_PIN 17           // ESP32 pin connected to GPS RX  (change if yours differs)
#define GPS_BAUD 9600

OneWire oneWire(ONE_WIRE_PIN);
DallasTemperature tempSensor(&oneWire);
MAX30105 particleSensor;
TinyGPSPlus gps;

// Must stay above all functions (Arduino IDE auto-generates prototypes)
struct Latest { int bpm; int spo2; float tempC; uint32_t ms; };
struct Gps { double lat; double lng; bool valid; };

const int S_BUFFER_SIZE = 100;  // 4 seconds at 25 samples/sec
const int STEP = 25;            // 25 new samples = 1 second
uint32_t irBuffer[S_BUFFER_SIZE];
uint32_t redBuffer[S_BUFFER_SIZE];

int32_t spo2 = 0, heartRate = 0;
int8_t validSPO2 = 0, validHeartRate = 0;
float temperatureC = NAN;

void readSample(int i) {
  while (!particleSensor.available()) particleSensor.check();
  redBuffer[i] = particleSensor.getRed();
  irBuffer[i] = particleSensor.getIR();
  particleSensor.nextSample();
}

void checkWiFi() {
  static wl_status_t last = WL_NO_SHIELD;
  static uint32_t lastRetry = 0;
  wl_status_t s = WiFi.status();

  if (s != last) {  // print only when the status changes
    last = s;
    if (s == WL_CONNECTED) {
      Serial.print("{\"wifi\":\"connected\",\"ip\":\"");
      Serial.print(WiFi.localIP());
      Serial.print("\",\"rssi\":");
      Serial.print(WiFi.RSSI());
      Serial.println("}");
    } else {
      Serial.println("{\"wifi\":\"disconnected\"}");
    }
  }

  if (s != WL_CONNECTED && millis() - lastRetry > 15000) {  // retry every 15 s
    lastRetry = millis();
    WiFi.disconnect();
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
  }
}

// ---------- Shared data ----------
Latest latest = {-1, -1, NAN, 0};
Gps gpsData = {0, 0, false};
portMUX_TYPE dataMux = portMUX_INITIALIZER_UNLOCKED;

// ---------- GPS task: reads the NEO-6M in the background ----------
void gpsTask(void*) {
  for (;;) {
    while (Serial2.available()) gps.encode(Serial2.read());

    bool ok = gps.location.isValid() && gps.location.age() < 10000;
    double la = ok ? gps.location.lat() : 0;
    double lo = ok ? gps.location.lng() : 0;

    portENTER_CRITICAL(&dataMux);
    gpsData.lat = la;
    gpsData.lng = lo;
    gpsData.valid = ok;
    portEXIT_CRITICAL(&dataMux);

    vTaskDelay(pdMS_TO_TICKS(20));
  }
}

// ---------- Firestore upload (runs on its own task) ----------
String idToken;
uint32_t tokenMs = 0;

bool signIn() {
  WiFiClientSecure client;
  client.setInsecure();  // prototype only: skips certificate check
  HTTPClient http;
  http.begin(client, String("https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=") + FIREBASE_API_KEY);
  http.addHeader("Content-Type", "application/json");
  String body = String("{\"email\":\"") + DEVICE_EMAIL + "\",\"password\":\"" + DEVICE_PASSWORD + "\",\"returnSecureToken\":true}";
  int code = http.POST(body);
  String resp = http.getString();
  http.end();

  if (code != 200) {
    Serial.print("{\"signin\":\"failed\",\"http\":");
    Serial.print(code);
    Serial.print(",\"detail\":");
    Serial.print(code > 0 ? resp.substring(0, 160) : String("\"no response\""));
    Serial.println("}");
    return false;
  }
  int k = resp.indexOf("\"idToken\"");
  if (k < 0) return false;
  int q1 = resp.indexOf('"', resp.indexOf(':', k) + 1);
  int q2 = resp.indexOf('"', q1 + 1);
  idToken = resp.substring(q1 + 1, q2);
  tokenMs = millis();
  Serial.println("{\"signin\":\"ok\"}");
  return true;
}

String intField(int v) {
  return v >= 0 ? String("{\"integerValue\":\"") + v + "\"}" : String("{\"nullValue\":null}");
}

String coordField(bool valid, double v) {
  return valid ? String("{\"doubleValue\":") + String(v, 6) + "}" : String("{\"nullValue\":null}");
}

int uploadReading(const Latest& d, const Gps& g) {
  char id[25];
  snprintf(id, sizeof(id), "%08lx%08lx%08lx",
           (unsigned long)esp_random(), (unsigned long)esp_random(), (unsigned long)esp_random());
  String doc = String("projects/") + FIREBASE_PROJECT_ID + "/databases/(default)/documents/sensor_data/" + id;

  String temp = isnan(d.tempC) ? String("{\"nullValue\":null}")
                               : String("{\"doubleValue\":") + String(d.tempC, 1) + "}";
  String body = String("{\"writes\":[{\"update\":{\"name\":\"") + doc + "\",\"fields\":{"
    "\"patientId\":{\"stringValue\":\"" + PATIENT_UID + "\"},"
    "\"heartRate\":" + intField(d.bpm) + ","
    "\"spo2\":" + intField(d.spo2) + ","
    "\"latitude\":" + coordField(g.valid, g.lat) + ","
    "\"longitude\":" + coordField(g.valid, g.lng) + ","
    "\"temperature\":" + temp + "}},"
    "\"updateTransforms\":[{\"fieldPath\":\"timestamp\",\"setToServerValue\":\"REQUEST_TIME\"}],"
    "\"currentDocument\":{\"exists\":false}}]}";

  WiFiClientSecure client;
  client.setInsecure();  // prototype only
  HTTPClient http;
  http.begin(client, String("https://firestore.googleapis.com/v1/projects/") + FIREBASE_PROJECT_ID + "/databases/(default)/documents:commit");
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", String("Bearer ") + idToken);
  int code = http.POST(body);
  if (code != 200 && code > 0) {
    Serial.print("{\"upload_error\":");
    Serial.print(http.getString().substring(0, 200));
    Serial.println("}");
  }
  http.end();
  return code;
}

void uploadTask(void*) {
  for (;;) {
    vTaskDelay(pdMS_TO_TICKS(5000));

    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("{\"upload\":\"skipped\",\"reason\":\"no wifi\"}");
      continue;
    }
    Latest d;
    Gps g;
    portENTER_CRITICAL(&dataMux);
    d = latest;
    g = gpsData;
    portEXIT_CRITICAL(&dataMux);
    if (d.ms == 0 || millis() - d.ms > 3000) {
      Serial.println("{\"upload\":\"skipped\",\"reason\":\"no fresh sensor data\"}");
      continue;
    }
    if (idToken.length() == 0 || millis() - tokenMs > 50UL * 60UL * 1000UL) {
      if (!signIn()) continue;
    }
    int code = uploadReading(d, g);
    Serial.print("{\"upload\":\"");
    Serial.print(code == 200 ? "ok" : "failed");
    Serial.print("\",\"http\":");
    Serial.print(code);
    Serial.print(",\"gps\":");
    if (g.valid) {
      Serial.print("{\"lat\":");
      Serial.print(g.lat, 6);
      Serial.print(",\"lng\":");
      Serial.print(g.lng, 6);
      Serial.print("}");
    } else {
      Serial.print("\"no fix\"");
    }
    Serial.println("}");
    if (code == 401) idToken = "";  // token expired: sign in again next time
  }
}

void setup() {
  Serial.begin(115200);

  Wire.begin(21, 22);

  if (!particleSensor.begin(Wire, I2C_SPEED_FAST)) {
    Serial.println("{\"error\":\"MAX30102 not found\"}");
    while (1) delay(1000);
  }
  // ledBrightness, sampleAverage, ledMode(2 = red+IR), sampleRate, pulseWidth, adcRange
  particleSensor.setup(60, 4, 2, 100, 411, 4096);

  delay(500);
  tempSensor.begin();
  Serial.print("{\"ds18b20_devices\":");
  Serial.print(tempSensor.getDeviceCount());
  Serial.println("}");
  tempSensor.setResolution(10);
  tempSensor.setWaitForConversion(false);  // don't block sensor sampling
  tempSensor.requestTemperatures();

  Serial2.setRxBufferSize(2048);
  Serial2.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

  Serial.println("{\"status\":\"ready\"}");

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  xTaskCreatePinnedToCore(uploadTask, "upload", 12288, NULL, 1, NULL, 0);
  xTaskCreatePinnedToCore(gpsTask, "gps", 4096, NULL, 1, NULL, 0);

  for (int i = 0; i < S_BUFFER_SIZE; i++) readSample(i);
  maxim_heart_rate_and_oxygen_saturation(irBuffer, S_BUFFER_SIZE, redBuffer,
                                         &spo2, &validSPO2, &heartRate, &validHeartRate);
}

void loop() {
  checkWiFi();
  // Slide window: keep the newest 75 samples, read 25 new ones (about 1 second)
  for (int i = STEP; i < S_BUFFER_SIZE; i++) {
    redBuffer[i - STEP] = redBuffer[i];
    irBuffer[i - STEP] = irBuffer[i];
  }
  for (int i = S_BUFFER_SIZE - STEP; i < S_BUFFER_SIZE; i++) readSample(i);

  maxim_heart_rate_and_oxygen_saturation(irBuffer, S_BUFFER_SIZE, redBuffer,
                                         &spo2, &validSPO2, &heartRate, &validHeartRate);

  // Temperature: keep the last good value for up to 30 s to hide brief dropouts
  float t = tempSensor.getTempCByIndex(0);
    if (t == DEVICE_DISCONNECTED_C) {
    static uint32_t lastScan = 0;
    if (millis() - lastScan > 5000) {
      lastScan = millis();
      tempSensor.begin();  // look for the sensor again
    }
  }
  tempSensor.requestTemperatures();
  static float lastGoodT = NAN;
  static uint32_t lastGoodMs = 0;
  if (t != DEVICE_DISCONNECTED_C) {
    lastGoodT = t;
    lastGoodMs = millis();
  }
  temperatureC = (lastGoodMs != 0 && millis() - lastGoodMs < 30000) ? lastGoodT : NAN;

  uint32_t ir = irBuffer[S_BUFFER_SIZE - 1];
  bool finger = ir > FINGER_THRESHOLD;

  bool bpmOk = finger && validHeartRate && heartRate >= 30 && heartRate <= 220;
  bool spo2Ok = finger && validSPO2 && spo2 >= 70 && spo2 <= 100;

  portENTER_CRITICAL(&dataMux);
  latest.bpm = bpmOk ? (int)heartRate : -1;
  latest.spo2 = spo2Ok ? (int)spo2 : -1;
  latest.tempC = temperatureC;
  latest.ms = millis();
  portEXIT_CRITICAL(&dataMux);

  Serial.print("{\"ir\":");
  Serial.print(ir);
  Serial.print(",\"bpm\":");
  if (bpmOk) Serial.print(heartRate); else Serial.print("null");
  Serial.print(",\"spo2\":");
  if (spo2Ok) Serial.print(spo2); else Serial.print("null");
  Serial.print(",\"temperature_c\":");
  if (isnan(temperatureC)) Serial.print("null"); else Serial.print(temperatureC, 1);
  Serial.println("}");
}