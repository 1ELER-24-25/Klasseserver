#include <Arduino.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// WiFi credentials
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

// Server details
const char* serverUrl = "http://192.168.1.216/php";  // Use your server's IP address

void setup() {
  Serial.begin(115200);
  
  // Connect to WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
  }
  Serial.println("\nConnected to WiFi");
}

// Simulate reading an RFID card
String simulateRFIDRead() {
  return "CARD00000001";  // This should match a card from your test data
}

// Send game result to server
void sendGameResult(String player1Card, String player2Card, String winner) {
  if (WiFi.status() == WL_CONNECTED) {
    HTTPClient http;
    
    // Create JSON document
    JsonDocument doc;
    doc["game_type"] = "CHESS";  // or "FOOSBALL"
    doc["player1_card"] = player1Card;
    doc["player2_card"] = player2Card;
    doc["winner_card"] = winner;
    
    String jsonString;
    serializeJson(doc, jsonString);
    
    // Send POST request to the api subfolder
    http.begin(String(serverUrl) + "/api/game_result.php");
    http.addHeader("Content-Type", "application/json");
    
    int httpResponseCode = http.POST(jsonString);
    
    if (httpResponseCode > 0) {
      String response = http.getString();
      Serial.println("HTTP Response code: " + String(httpResponseCode));
      Serial.println("Response: " + response);
    } else {
      Serial.println("Error on sending POST: " + String(httpResponseCode));
    }
    
    http.end();
  }
}

void loop() {
  if (Serial.available()) {
    char cmd = Serial.read();
    
    switch (cmd) {
      case '1': {
        // Test: Player 1 wins
        String player1 = simulateRFIDRead();
        String player2 = "CARD00000002";
        sendGameResult(player1, player2, player1);
        break;
      }
      case '2': {
        // Test: Player 2 wins
        String player1 = "CARD00000001";
        String player2 = "CARD00000002";
        sendGameResult(player1, player2, player2);
        break;
      }
      case 'd': {
        // Test: Draw game
        String player1 = "CARD00000001";
        String player2 = "CARD00000002";
        sendGameResult(player1, player2, "");
        break;
      }
      case 'l': {
        // Test: Get leaderboard
        if (WiFi.status() == WL_CONNECTED) {
          HTTPClient http;
          http.begin(String(serverUrl) + "/leaderboard.php");
          
          int httpResponseCode = http.GET();
          if (httpResponseCode > 0) {
            String response = http.getString();
            Serial.println("Leaderboard: " + response);
          }
          http.end();
        }
        break;
      }
    }
  }
  
  delay(100);  // Small delay to prevent busy-waiting
}
