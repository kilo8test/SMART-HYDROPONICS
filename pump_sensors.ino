#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <time.h>

// ================== CONFIG ==================
/* WiFi */
const char* WIFI_SSID     = "Makisuuu";
const char* WIFI_PASSWORD = "#Max.X!e071204";

/* Supabase */
const char* SUPABASE_URL = "https://ihscuhuksaixfjmmttqa.supabase.co/rest/v1/pump_sensors";
const char* SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imloc2N1aHVrc2FpeGZqbW10dHFhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTc1MTU0NTAsImV4cCI6MjA3MzA5MTQ1MH0.6eKAuH33Rn4c4RsIy-5XXYrArhdy4f0suJ6S82Q7cW8";

/* Pins */
#define WATER_LEVEL_PIN 34  // Water level sensor (digital)
#define TDS_PIN 35          // TDS analog input
#define RELAY_PIN 5         // Relay control pin
#define RELAY_ACTIVE_LOW 0  // 0 = Active HIGH relay, 1 = Active LOW

/* Time */
const char* ntpServer        = "pool.ntp.org";
const long gmtOffset_sec     = 8 * 3600;  // UTC+8
const int daylightOffset_sec = 0;

/* Behavior */
const unsigned long CHECK_INTERVAL_MS = 1000;  // Check sensors every 1 second
const int WIFI_CONNECT_TIMEOUT_MS = 15000;     // WiFi connect timeout
const float TDS_UPLOAD_DELTA = 10.0;           // Upload only if TDS changes ≥ 10 ppm
const float DEFAULT_WATER_TEMP = 25.0;         // °C default temperature for compensation

/* Serial */
const int SERIAL_BAUD = 115200;

// ================== VARIABLES ==================
bool lastWaterStatus = false;
bool lastPumpStatus  = false;
float tdsValue = 0.0;
float lastTdsValue = 0.0;
float waterTemp = DEFAULT_WATER_TEMP;
unsigned long lastCheck = 0;
String lastInsertedTime = "";

// ================== HELPERS ==================
void ensureWiFiModeSta() {
  if (WiFi.getMode() != WIFI_MODE_STA) WiFi.mode(WIFI_MODE_STA);
}

void connectWiFi() {
  if (WiFi.status() == WL_CONNECTED) return;

  ensureWiFiModeSta();
  Serial.print("🌐 Connecting to WiFi");
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  unsigned long start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < WIFI_CONNECT_TIMEOUT_MS) {
    delay(250);
    Serial.print(".");
    yield();
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.print("✅ WiFi Connected! IP: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println();
    Serial.println("❌ WiFi Failed. Will retry later...");
  }
}

String getTimeStamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return "";
  char buffer[30];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &timeinfo);
  return String(buffer);
}

void setRelay(bool on) {
  if (RELAY_ACTIVE_LOW)
    digitalWrite(RELAY_PIN, on ? LOW : HIGH);
  else
    digitalWrite(RELAY_PIN, on ? HIGH : LOW);

  Serial.println(on ? "💧 Pump: ON" : "💧 Pump: OFF");
  lastPumpStatus = on;
}

// ================== SUPABASE UPLOAD ==================
bool insertRow(bool waterDetected) {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
    if (WiFi.status() != WL_CONNECTED) return false;
  }

  HTTPClient http;
  http.begin(SUPABASE_URL);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);
  http.addHeader("Prefer", "return=representation");

  StaticJsonDocument<400> doc;
  String nowTs = getTimeStamp();
  doc["waterlevel_status"] = waterDetected;
  doc["pump_status"]       = lastPumpStatus;
  doc["tds_value"]         = tdsValue;
  doc["date_time"]         = nowTs;
  lastInsertedTime = nowTs;

  String payload;
  serializeJson(doc, payload);
  Serial.println("📤 Sending Payload: " + payload);

  int code = http.POST(payload);
  String response = http.getString();
  http.end();

  if (code >= 200 && code < 300) {
    Serial.println("✅ Row inserted successfully.");
    return true;
  } else {
    Serial.printf("❌ Insert error: %d\n", code);
    Serial.println("🔎 Response: " + response);
    return false;
  }
}

void logStateIfChanged(bool newWaterStatus, bool newPumpStatus, float newTdsValue) {
  bool waterChanged = (newWaterStatus != lastWaterStatus);
  bool pumpChanged  = (newPumpStatus != lastPumpStatus);
  bool tdsChanged   = (fabs(newTdsValue - lastTdsValue) >= TDS_UPLOAD_DELTA);

  if (waterChanged || pumpChanged || tdsChanged) {
    lastWaterStatus = newWaterStatus;
    lastPumpStatus  = newPumpStatus;
    lastTdsValue    = newTdsValue;
    insertRow(lastWaterStatus);
  }
}

// ================== REMOTE COMMAND ==================
bool fetchLatestCommand() {
  if (WiFi.status() != WL_CONNECTED) {
    connectWiFi();
    if (WiFi.status() != WL_CONNECTED) return false;
  }

  String url = String(SUPABASE_URL) + "?order=date_time.desc&limit=1";
  HTTPClient http;
  http.begin(url);
  http.addHeader("apikey", SUPABASE_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_KEY);

  int code = http.GET();
  String response = http.getString();
  http.end();

  if (code >= 200 && code < 300) {
    StaticJsonDocument<512> doc;
    DeserializationError err = deserializeJson(doc, response);
    if (err) {
      Serial.println("❌ JSON parse failed in fetchLatestCommand.");
      return false;
    }

    if (!doc.is<JsonArray>() || doc.size() == 0) return true;

    JsonObject obj = doc[0];
    String latestTime = obj["date_time"] | "";
    bool remotePump   = obj["pump_status"] | false;

    if (latestTime.length() > 0 && latestTime != lastInsertedTime && remotePump != lastPumpStatus) {
      Serial.println("🔄 Remote command detected! Updating pump...");
      setRelay(remotePump);
      insertRow(lastWaterStatus);
    }
    return true;
  } else {
    Serial.printf("❌ Fetch error: %d\n", code);
    return false;
  }
}

// ================== TDS SENSOR READING ==================
float readTDS() {
  int rawValue = analogRead(TDS_PIN);
  rawValue = constrain(rawValue, 0, 4095);

  float voltage = rawValue * (3.3f / 4095.0f);
  float compensationCoefficient = 1.0f + 0.02f * (waterTemp - 25.0f);
  float compensationVoltage = voltage / compensationCoefficient;

  float tds = (133.42f * pow(compensationVoltage, 3)
             - 255.86f * pow(compensationVoltage, 2)
             + 857.39f * compensationVoltage) * 0.5f;

  if (tds < 0) tds = 0;
  return tds;
}

// ================== SETUP ==================
void setup() {
  Serial.begin(SERIAL_BAUD);
  delay(100);

  pinMode(WATER_LEVEL_PIN, INPUT);
  pinMode(RELAY_PIN, OUTPUT);
  setRelay(false);

  connectWiFi();
  configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
  delay(2000);

  lastWaterStatus = (digitalRead(WATER_LEVEL_PIN) == HIGH);
  tdsValue = readTDS();
  lastTdsValue = tdsValue;
  insertRow(lastWaterStatus);

  Serial.println("📢 Type 'On' or 'Off' in Serial Monitor to control pump manually.");
}

// ================== LOOP ==================
void loop() {
  unsigned long now = millis();
  if (now - lastCheck >= CHECK_INTERVAL_MS) {
    lastCheck = now;

    tdsValue = readTDS();
    bool waterDetected = (digitalRead(WATER_LEVEL_PIN) == HIGH);

    Serial.print("🌊 TDS Value: ");
    Serial.print(tdsValue, 0);
    Serial.print(" ppm | Water: ");
    Serial.println(waterDetected ? "💧 Present" : "⚠️ Absent");

    // Safety check
    if (lastPumpStatus && !waterDetected) {
      Serial.println("⛔ No water detected! Pump OFF automatically.");
      setRelay(false);
      insertRow(false);
    }

    // Upload only if there’s a change
    logStateIfChanged(waterDetected, lastPumpStatus, tdsValue);

    // Check remote Supabase command
    fetchLatestCommand();
  }

  // Manual serial control
  if (Serial.available() > 0) {
    String cmd = Serial.readStringUntil('\n');
    cmd.trim();

    if (cmd.equalsIgnoreCase("On")) {
      if (!lastWaterStatus) {
        Serial.println("⛔ No water detected! Cannot turn ON.");
      } else if (!lastPumpStatus) {
        Serial.println("🖥 Manual Command: Pump ON");
        setRelay(true);
        insertRow(lastWaterStatus);
      }
    } else if (cmd.equalsIgnoreCase("Off")) {
      if (lastPumpStatus) {
        Serial.println("🖥 Manual Command: Pump OFF");
        setRelay(false);
        insertRow(lastWaterStatus);
      }
    } else {
      Serial.println("⚠️ Invalid command. Use 'On' or 'Off'.");
    }
  }

  delay(1); // yield for stability
}
