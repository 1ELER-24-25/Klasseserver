#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// WiFi and MQTT settings
const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";
const char* mqtt_server = "YOUR_SERVER_IP"; // Use your server's actual IP address
const int mqtt_port = 1883;

// Add these test card IDs at the top with other constants
const char* TEST_CARD_1 = "CARD001";
const char* TEST_CARD_2 = "CARD002";

WiFiClient espClient;
PubSubClient mqtt(espClient);

// Game state
enum GameState {
    WAITING_PLAYER1,
    WAITING_PLAYER2,
    GAME_ACTIVE,
    GAME_FINISHED
};

struct GameSession {
    GameState state = WAITING_PLAYER1;
    String player1Card;
    String player2Card;
    String player1Name;
    String player2Name;
    String gameType;
    int team1Score = 0;
    int team2Score = 0;
} currentGame;

void printHelp() {
    Serial.println("\n=== Available Commands ===");
    Serial.println("Game Selection:");
    Serial.println("  c - Start Chess game");
    Serial.println("  f - Start Foosball game");
    
    if (currentGame.state == WAITING_PLAYER1) {
        Serial.println("\nPlayer Registration:");
        Serial.println("  p1 - Simulate Player 1 card scan");
    } else if (currentGame.state == WAITING_PLAYER2) {
        Serial.println("\nPlayer Registration:");
        Serial.println("  p2 - Simulate Player 2 card scan");
    }
    
    if (currentGame.state == GAME_ACTIVE && currentGame.gameType == "FOOSBALL") {
        Serial.println("\nFoosball Controls:");
        Serial.println("  1 - Score goal for Team 1");
        Serial.println("  2 - Score goal for Team 2");
        Serial.println("  F - Finish game");
        Serial.printf("Current Score: %d - %d\n", currentGame.team1Score, currentGame.team2Score);
    }
    
    Serial.println("\nh - Show this help message");
}

void setup() {
    Serial.begin(115200);
    
    // Connect to WiFi
    Serial.print("Connecting to WiFi");
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nConnected to WiFi");
    
    // Setup MQTT
    setupMQTT();
    
    printHelp();
}

void setupMQTT() {
    mqtt.setServer(mqtt_server, mqtt_port);
    mqtt.setCallback(mqttCallback);
    
    Serial.println("Attempting MQTT connection...");
    while (!mqtt.connected()) {
        Serial.println("Connecting to MQTT...");
        String clientId = "ESP32Client-";
        clientId += String(random(0xffff), HEX);
        
        if (mqtt.connect(clientId.c_str())) {
            Serial.println("Connected to MQTT server");
            mqtt.subscribe("game/response/#");
            Serial.println("Subscribed to game/response/#");
            
            // Test subscription
            mqtt.publish("game/test", "ESP32 Connected");
            Serial.println("Published test message");
        } else {
            Serial.print("Failed to connect to MQTT, rc=");
            Serial.println(mqtt.state());
            Serial.println("Retrying in 5 seconds...");
            delay(5000);
        }
    }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
    Serial.print("Message received on topic: ");
    Serial.println(topic);
    Serial.print("Payload: ");
    Serial.println(String((char*)payload, length));

    String message = String((char*)payload, length);
    JsonDocument doc;
    DeserializationError error = deserializeJson(doc, message);
    
    if (error) {
        Serial.print("deserializeJson() failed: ");
        Serial.println(error.c_str());
        return;
    }

    if (String(topic) == "game/response/player") {
        String cardId = doc["card_id"].as<String>();
        String playerName = doc["name"].as<String>();
        bool isNewPlayer = doc["is_new"].as<bool>();

        Serial.println("Received player data:");
        Serial.println("Card ID: " + cardId);
        Serial.println("Name: " + playerName);
        Serial.println("Is new: " + String(isNewPlayer));

        if (currentGame.state == WAITING_PLAYER1) {
            currentGame.player1Card = cardId;
            currentGame.player1Name = playerName;
            currentGame.state = WAITING_PLAYER2;
            Serial.println("Player 1: " + playerName + (isNewPlayer ? " (New Player)" : ""));
            Serial.println("Type 'p2' to simulate Player 2 card scan");
        } else if (currentGame.state == WAITING_PLAYER2) {
            currentGame.player2Card = cardId;
            currentGame.player2Name = playerName;
            currentGame.state = GAME_ACTIVE;
            Serial.println("Player 2: " + playerName + (isNewPlayer ? " (New Player)" : ""));
            startGame();
        }
    }
}

void registerCard(String cardId) {
    JsonDocument doc;
    doc["card_id"] = cardId;
    
    String message;
    serializeJson(doc, message);
    
    Serial.println("Publishing to game/register_card: " + message);
    if (mqtt.publish("game/register_card", message.c_str())) {
        Serial.println("Message published successfully");
    } else {
        Serial.println("Failed to publish message");
    }
}

void startGame() {
    Serial.println("\nGame starting!");
    Serial.println(currentGame.player1Name + " vs " + currentGame.player2Name);
    
    // For Foosball, enable goal counting
    if (currentGame.gameType == "FOOSBALL") {
        Serial.println("Press 1 for Team 1 goal");
        Serial.println("Press 2 for Team 2 goal");
        Serial.println("Press F to finish game");
    }
}

void recordGoal(int team) {
    if (currentGame.state != GAME_ACTIVE) return;
    
    if (team == 1) currentGame.team1Score++;
    else if (team == 2) currentGame.team2Score++;
    
    JsonDocument doc;
    doc["game_type"] = "FOOSBALL";
    doc["team"] = team;
    doc["timestamp"] = millis();
    
    String message;
    serializeJson(doc, message);
    mqtt.publish("game/goal", message.c_str());
    
    Serial.printf("Score: %d - %d\n", currentGame.team1Score, currentGame.team2Score);
}

void finishGame() {
    JsonDocument doc;
    doc["game_type"] = currentGame.gameType;
    doc["player1_card"] = currentGame.player1Card;
    doc["player2_card"] = currentGame.player2Card;
    doc["team1_score"] = currentGame.team1Score;
    doc["team2_score"] = currentGame.team2Score;
    
    String message;
    serializeJson(doc, message);
    mqtt.publish("game/finish", message.c_str());
    
    // Reset game state
    currentGame = GameSession();
    Serial.println("\nGame finished! Ready for new players.");
}

void loop() {
    mqtt.loop();
    
    if (Serial.available()) {
        char cmd = Serial.read();
        
        switch (cmd) {
            case 'h':
                printHelp();
                break;
            case 'c':
                currentGame.gameType = "CHESS";
                Serial.println("\nChess mode selected. Waiting for Player 1...");
                Serial.println("Type 'p1' to simulate Player 1 card scan");
                break;
            case 'f':
                currentGame.gameType = "FOOSBALL";
                Serial.println("\nFoosball mode selected. Waiting for Player 1...");
                Serial.println("Type 'p1' to simulate Player 1 card scan");
                break;
            case 'p':  // Handle 'p1' and 'p2' commands
                if (Serial.available()) {
                    char playerNum = Serial.read();
                    if (playerNum == '1') {
                        registerCard(TEST_CARD_1);
                        Serial.println("Simulating Player 1 card scan: " + String(TEST_CARD_1));
                        if (currentGame.state == WAITING_PLAYER2) {
                            Serial.println("Type 'p2' to simulate Player 2 card scan");
                        }
                    } else if (playerNum == '2') {
                        registerCard(TEST_CARD_2);
                        Serial.println("Simulating Player 2 card scan: " + String(TEST_CARD_2));
                    }
                }
                break;
            case '1':
                if (currentGame.gameType == "FOOSBALL" && currentGame.state == GAME_ACTIVE) {
                    recordGoal(1);
                } else {
                    Serial.println("Goal recording only available during active Foosball game!");
                }
                break;
            case '2':
                if (currentGame.gameType == "FOOSBALL" && currentGame.state == GAME_ACTIVE) {
                    recordGoal(2);
                } else {
                    Serial.println("Goal recording only available during active Foosball game!");
                }
                break;
            case 'F':
                if (currentGame.state == GAME_ACTIVE) {
                    finishGame();
                    printHelp();
                } else {
                    Serial.println("No active game to finish!");
                }
                break;
            default:
                if (cmd != '\n' && cmd != '\r') {  // Ignore newline characters
                    Serial.println("Unknown command. Press 'h' for help.");
                }
                break;
        }
    }
}
