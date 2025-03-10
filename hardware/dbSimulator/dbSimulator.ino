#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// WiFi and MQTT settings
const char* ssid = "Ingve";
const char* password = "AndreaBochili";
const char* mqtt_server = "192.168.1.216";
const int mqtt_port = 1883;

// Test card IDs
const char* TEST_CARDS[] = {
    "CARD001",
    "CARD002",
    "CARD003",
    "NEWCARD"
};

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
    String gameType;
    String player1Card;
    String player2Card;
    int team1Score = 0;
    int team2Score = 0;
};

GameSession currentGame;

void printMainMenu() {
    Serial.println("\n=== Klasseserver Test Menu ===");
    Serial.println("1. Simulate RFID Card Scan");
    Serial.println("2. Start Game");
    Serial.println("3. Score Management");
    Serial.println("4. Game Status");
    Serial.println("5. Custom RFID Input");
    Serial.println("h. Show This Menu");
    Serial.println("========================");
}

void printGameTypeMenu() {
    Serial.println("\n=== Select Game Type ===");
    Serial.println("1. Chess");
    Serial.println("2. Foosball");
    Serial.println("b. Back to Main Menu");
    Serial.println("=====================");
}

void printScoreMenu() {
    Serial.println("\n=== Score Management ===");
    Serial.println("1. Team 1 Scores");
    Serial.println("2. Team 2 Scores");
    Serial.println("3. Show Current Score");
    Serial.println("4. End Game");
    Serial.println("b. Back to Main Menu");
    Serial.println("=====================");
}

void handleRFIDSimulation() {
    Serial.println("\n=== Select RFID Card ===");
    for (int i = 0; i < 4; i++) {
        Serial.printf("%d. %s\n", i + 1, TEST_CARDS[i]);
    }
    Serial.println("b. Back to Main Menu");
    
    while (!Serial.available()) delay(100);
    char choice = Serial.read();
    
    if (choice >= '1' && choice <= '4') {
        int idx = choice - '1';
        String cardId = TEST_CARDS[idx];
        
        JsonDocument doc;
        doc["card_id"] = cardId;
        
        String message;
        serializeJson(doc, message);
        
        mqtt.publish("game/register_card", message.c_str());
        Serial.printf("Published card ID: %s\n", cardId.c_str());
    }
}

void handleGameStart() {
    printGameTypeMenu();
    
    while (!Serial.available()) delay(100);
    char choice = Serial.read();
    
    switch (choice) {
        case '1':
            currentGame.gameType = "CHESS";
            currentGame.state = WAITING_PLAYER1;
            Serial.println("Chess game selected. Scan Player 1 card.");
            break;
        case '2':
            currentGame.gameType = "FOOSBALL";
            currentGame.state = WAITING_PLAYER1;
            Serial.println("Foosball game selected. Scan Player 1 card.");
            break;
    }
}

void handleScoreManagement() {
    printScoreMenu();
    
    while (!Serial.available()) delay(100);
    char choice = Serial.read();
    
    switch (choice) {
        case '1':
            currentGame.team1Score++;
            publishScore(1);
            break;
        case '2':
            currentGame.team2Score++;
            publishScore(2);
            break;
        case '3':
            Serial.printf("Current Score - Team 1: %d, Team 2: %d\n",
                currentGame.team1Score, currentGame.team2Score);
            break;
        case '4':
            endGame();
            break;
    }
}

void publishScore(int team) {
    JsonDocument doc;
    doc["team"] = team;
    doc["timestamp"] = millis();
    
    String message;
    serializeJson(doc, message);
    mqtt.publish("game/goal", message.c_str());
    
    Serial.printf("Goal for Team %d! Score: %d-%d\n",
        team, currentGame.team1Score, currentGame.team2Score);
}

void endGame() {
    JsonDocument doc;
    doc["game_type"] = currentGame.gameType;
    doc["player1_card"] = currentGame.player1Card;
    doc["player2_card"] = currentGame.player2Card;
    doc["team1_score"] = currentGame.team1Score;
    doc["team2_score"] = currentGame.team2Score;
    
    String message;
    serializeJson(doc, message);
    mqtt.publish("game/finish", message.c_str());
    
    currentGame = GameSession();
    Serial.println("Game ended and results published!");
}

void handleCustomRFID() {
    Serial.println("\nEnter custom RFID (max 10 chars):");
    while (!Serial.available()) delay(100);
    
    String customRFID = Serial.readStringUntil('\n');
    customRFID.trim();
    
    if (customRFID.length() > 0 && customRFID.length() <= 10) {
        JsonDocument doc;
        doc["card_id"] = customRFID;
        
        String message;
        serializeJson(doc, message);
        mqtt.publish("game/register_card", message.c_str());
        Serial.printf("Published custom RFID: %s\n", customRFID.c_str());
    } else {
        Serial.println("Invalid RFID length!");
    }
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
    String message = String((char*)payload, length);
    Serial.printf("\nReceived message on topic '%s': %s\n", topic, message.c_str());
}

void setupMQTT() {
    mqtt.setServer(mqtt_server, mqtt_port);
    mqtt.setCallback(mqttCallback);
    
    while (!mqtt.connected()) {
        Serial.println("Connecting to MQTT...");
        String clientId = "ESP32Sim-";
        clientId += String(random(0xffff), HEX);
        
        if (mqtt.connect(clientId.c_str())) {
            Serial.println("Connected to MQTT broker");
            mqtt.subscribe("game/response/#");
        } else {
            Serial.printf("Failed to connect to MQTT, rc=%d\n", mqtt.state());
            delay(2000);
        }
    }
}

void setup() {
    Serial.begin(115200);
    
    // Connect to WiFi
    Serial.printf("Connecting to WiFi %s", ssid);
    WiFi.begin(ssid, password);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\nConnected to WiFi");
    
    setupMQTT();
    printMainMenu();
}

void loop() {
    mqtt.loop();
    
    if (Serial.available()) {
        char cmd = Serial.read();
        
        switch (cmd) {
            case '1':
                handleRFIDSimulation();
                break;
            case '2':
                handleGameStart();
                break;
            case '3':
                handleScoreManagement();
                break;
            case '4':
                Serial.printf("\nGame Status:\nType: %s\nState: %d\nScore: %d-%d\n",
                    currentGame.gameType.c_str(), currentGame.state,
                    currentGame.team1Score, currentGame.team2Score);
                break;
            case '5':
                handleCustomRFID();
                break;
            case 'h':
                printMainMenu();
                break;
        }
    }
}
