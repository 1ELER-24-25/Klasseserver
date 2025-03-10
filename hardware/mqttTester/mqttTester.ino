#include <Arduino.h>
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

// WiFi and MQTT settings
const char* ssid = "Ingve";
const char* password = "AndreaBochili";
const char* mqtt_server = "192.168.1.216";
const int mqtt_port = 1883;

// Test device settings
const char* DEVICE_ID = "ESP32_TESTER";
const char* TEST_CARD_1 = "RFID123";
const char* TEST_CARD_2 = "RFID456";

WiFiClient espClient;
PubSubClient mqtt(espClient);

// JSON document for messages
StaticJsonDocument<1024> doc;
char jsonBuffer[1024];

// Menu state
enum MenuState {
    MAIN_MENU,
    DEVICE_MENU,
    CARD_MENU,
    CHESS_MENU,
    FOOSBALL_MENU,
    IOT_MENU
};

MenuState currentMenu = MAIN_MENU;

void setupWiFi() {
    Serial.println("Connecting to WiFi...");
    WiFi.begin(ssid, password);
    
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    
    Serial.println("\nWiFi connected");
    Serial.println("IP address: ");
    Serial.println(WiFi.localIP());
}

void mqttCallback(char* topic, byte* payload, unsigned int length) {
    String message = String((char*)payload, length);
    Serial.printf("\nReceived message on topic '%s': %s\n", topic, message.c_str());

    // Parse JSON response
    StaticJsonDocument<1024> doc;
    DeserializationError error = deserializeJson(doc, message);
    
    if (error) {
        Serial.print("deserializeJson() failed: ");
        Serial.println(error.c_str());
        return;
    }

    // Handle card registration response
    if (String(topic) == "card/response") {
        const char* status = doc["status"];
        const char* playerName = doc["player_name"];
        bool isNew = doc["is_new"];
        
        Serial.println("Card registration response:");
        Serial.printf("Status: %s\n", status);
        if (strcmp(status, "success") == 0) {
            Serial.printf("Player: %s (New: %s)\n", playerName, isNew ? "Yes" : "No");
        }
    }
}

void setupMQTT() {
    mqtt.setServer(mqtt_server, mqtt_port);
    mqtt.setCallback(mqttCallback);
    
    reconnectMQTT();
    
    // Update subscribe topics to match the protocol
    const char* subscribeTopics[] = {
        "card/response",              // For card registration responses
        "foosball/game/response",     // For foosball game responses
        "chess/game/response",        // For chess game responses
        "foosball/error",            // For foosball errors
        "chess/error",               // For chess errors
        "iot/display/message"        // For display messages
    };
    
    for (const char* topic : subscribeTopics) {
        mqtt.subscribe(topic);
        Serial.printf("Subscribed to: %s\n", topic);
    }
}

void printMessage(const char* prefix, const char* topic, const char* payload) {
    Serial.println("\n----------------------------------------");
    Serial.printf("| %s\n", prefix);
    Serial.printf("| Topic: %s\n", topic);
    Serial.printf("| Payload: %s\n", payload);
    Serial.println("----------------------------------------\n");
}

void publishJson(const char* topic, JsonDocument& doc) {
    serializeJson(doc, jsonBuffer);
    mqtt.publish(topic, jsonBuffer);
    printMessage("PUBLISHED", topic, jsonBuffer);
}

void verifySubscriptions() {
    Serial.println("\n=== MQTT Subscription Status ===");
    const char* topics[] = {
        "card/response",
        "foosball/game/response",
        "chess/game/response",
        "foosball/error",
        "chess/error",
        "iot/display/message"
    };
    
    for (const char* topic : topics) {
        // Unfortunately PubSubClient doesn't provide a way to check subscription status
        // So we'll just print what we're supposed to be subscribed to
        Serial.printf("Should be subscribed to: %s\n", topic);
    }
    Serial.println("===============================\n");
}

void reconnectMQTT() {
    while (!mqtt.connected()) {
        Serial.println("Connecting to MQTT...");
        String clientId = "ESP32Tester-";
        clientId += String(random(0xffff), HEX);
        
        if (mqtt.connect(clientId.c_str())) {
            Serial.println("Connected to MQTT");
            
            // Resubscribe to all topics after reconnect
            const char* subscribeTopics[] = {
                "card/response",
                "foosball/game/response",
                "chess/game/response",
                "foosball/error",
                "chess/error",
                "iot/display/message"
            };
            
            for (const char* topic : subscribeTopics) {
                boolean success = mqtt.subscribe(topic);
                Serial.printf("Subscribing to %s: %s\n", topic, success ? "SUCCESS" : "FAILED");
            }
            
            // Print subscription status
            verifySubscriptions();
        } else {
            Serial.printf("Failed to connect to MQTT, rc=%d\n", mqtt.state());
            Serial.println("Retrying in 2 seconds...");
            delay(2000);
        }
    }
}

void sendDeviceStatus(const char* status, const char* type) {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["type"] = type;
    doc["status"] = status;
    doc["timestamp"] = 1234567890;
    
    publishJson("device/status", doc);
}

void registerCard(const char* cardId) {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["card_id"] = cardId;
    doc["timestamp"] = 1234567890;
    
    printMessage("REGISTERING CARD", "card/register", cardId);
    publishJson("card/register", doc);
    Serial.println("Waiting for card registration response on topic 'card/response'...");
    
    // Verify we're still subscribed
    verifySubscriptions();
}

void startChessGame() {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["player1_card"] = TEST_CARD_1;
    doc["player2_card"] = TEST_CARD_2;
    doc["timestamp"] = 1234567890;
    
    publishJson("chess/game/start", doc);
}

void sendChessMove() {
    doc.clear();
    doc["game_id"] = "GAME_001";
    doc["pgn"] = "1. e4 e5 2. Nf3";
    doc["move_number"] = 3;
    doc["last_move"] = "Nf3";
    doc["timestamp"] = 1234567890;
    
    publishJson("chess/game/move", doc);
}

void endChessGame(const char* result, const char* termination_details) {
    doc.clear();
    doc["game_id"] = "GAME_001";
    doc["completed"] = true;
    doc["result"] = result;
    doc["termination_reason"] = "normal";
    doc["termination_details"] = termination_details;
    doc["timestamp"] = 1234567890;
    
    publishJson("chess/game/end", doc);
}

void sendChessError() {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["game_id"] = "GAME_001";
    doc["error_code"] = "ERR_001";
    doc["severity"] = "fatal";
    doc["message"] = "Test error message";
    doc["timestamp"] = 1234567890;
    
    publishJson("chess/error", doc);
}

void startFoosballGame() {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["player1_card"] = TEST_CARD_1;
    doc["player2_card"] = TEST_CARD_2;
    doc["timestamp"] = 1234567890;
    
    publishJson("foosball/game/start", doc);
}

void sendFoosballScore(int player) {
    doc.clear();
    doc["game_id"] = "GAME_001";
    doc["scoring_player"] = player;
    doc["timestamp"] = 1234567890;
    
    publishJson("foosball/game/score", doc);
}

void endFoosballGame(bool completed) {
    doc.clear();
    doc["game_id"] = "GAME_001";
    doc["completed"] = completed;
    if (completed) {
        doc["final_score"]["player1"] = 5;
        doc["final_score"]["player2"] = 3;
        doc["termination_reason"] = "normal";
    } else {
        doc["termination_reason"] = "manual_stop";
    }
    doc["timestamp"] = 1234567890;
    
    publishJson("foosball/game/end", doc);
}

void sendFoosballError() {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["game_id"] = "GAME_001";
    doc["error_code"] = "ERR_001";
    doc["severity"] = "fatal";
    doc["message"] = "Test error message";
    doc["timestamp"] = 1234567890;
    
    publishJson("foosball/error", doc);
}

void queryRFID() {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["card_id"] = TEST_CARD_1;
    doc["timestamp"] = 1234567890;
    
    publishJson("iot/rfid/query", doc);
}

void queryStats(const char* period) {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["stat_type"] = period;
    doc["game_type"] = "ALL";
    doc["timestamp"] = 1234567890;
    
    publishJson("iot/stats/request", doc);
}

void sendDisplayMessage() {
    doc.clear();
    doc["device_id"] = DEVICE_ID;
    doc["message_type"] = "info";
    doc["text"] = "Test message from MQTT tester";
    doc["duration"] = 5000;
    doc["timestamp"] = 1234567890;
    
    publishJson("iot/display/message", doc);
}

void setup() {
    Serial.begin(115200);
    delay(1000);  // Short delay to ensure serial is ready
    Serial.println("\nMQTT Tester Starting...");
    
    setupWiFi();
    setupMQTT();
    showCurrentMenu();
}

void loop() {
    if (!mqtt.connected()) {
        reconnectMQTT();
    }
    mqtt.loop();

    if (Serial.available()) {
        String input = Serial.readStringUntil('\n');  // Les helt til linjeskift
        input.trim();  // Fjern whitespace og linjeskift
        
        if (input.length() > 0) {  // Sjekk at vi faktisk har et tegn
            char cmd = input.charAt(0);
            handleCommand(cmd);
            showCurrentMenu();
        }
    }
}

void handleCommand(char cmd) {
    if (cmd == 'b' && currentMenu != MAIN_MENU) {
        currentMenu = MAIN_MENU;
        return;
    }

    switch (currentMenu) {
        case MAIN_MENU:
            handleMainMenu(cmd);
            break;
        case DEVICE_MENU:
            handleDeviceMenu(cmd);
            break;
        case CARD_MENU:
            handleCardMenu(cmd);
            break;
        case CHESS_MENU:
            handleChessMenu(cmd);
            break;
        case FOOSBALL_MENU:
            handleFoosballMenu(cmd);
            break;
        case IOT_MENU:
            handleIoTMenu(cmd);
            break;
    }
}

void handleMainMenu(char cmd) {
    switch (cmd) {
        case '1': currentMenu = DEVICE_MENU; break;
        case '2': currentMenu = CARD_MENU; break;
        case '3': currentMenu = CHESS_MENU; break;
        case '4': currentMenu = FOOSBALL_MENU; break;
        case '5': currentMenu = IOT_MENU; break;
        case 'x': 
            WiFi.disconnect();
            setup();
            break;
        case 'h': break; // Menu will be shown automatically
        default: Serial.println("Unknown command");
    }
}

void handleDeviceMenu(char cmd) {
    switch (cmd) {
        case '1': sendDeviceStatus("online", "GENERIC"); break;
        case '2': sendDeviceStatus("offline", "GENERIC"); break;
        case '3': sendDeviceStatus("online", "CHESS"); break;
        case '4': sendDeviceStatus("online", "FOOSBALL"); break;
        default: Serial.println("Unknown command");
    }
}

void handleCardMenu(char cmd) {
    switch (cmd) {
        case '1': registerCard(TEST_CARD_1); break;
        case '2': registerCard(TEST_CARD_2); break;
        case '3': registerCard("UNKNOWN_CARD"); break;
        default: Serial.println("Unknown command");
    }
}

void handleChessMenu(char cmd) {
    switch (cmd) {
        case '1': startChessGame(); break;
        case '2': sendChessMove(); break;
        case '3': endChessGame("1-0", "checkmate"); break;
        case '4': endChessGame("0-1", "resignation"); break;
        case '5': endChessGame("1/2-1/2", "stalemate"); break;
        case '6': sendChessError(); break;
        default: Serial.println("Unknown command");
    }
}

void handleFoosballMenu(char cmd) {
    switch (cmd) {
        case '1': startFoosballGame(); break;
        case '2': sendFoosballScore(1); break;
        case '3': sendFoosballScore(2); break;
        case '4': endFoosballGame(true); break;
        case '5': endFoosballGame(false); break;
        case '6': sendFoosballError(); break;
        default: Serial.println("Unknown command");
    }
}

void handleIoTMenu(char cmd) {
    switch (cmd) {
        case '1': queryRFID(); break;
        case '2': break; // Reserved for future use
        case '3': queryStats("daily"); break;
        case '4': queryStats("weekly"); break;
        case '5': queryStats("monthly"); break;
        case '6': sendDisplayMessage(); break;
        default: Serial.println("Unknown command");
    }
}

void showCurrentMenu() {
    Serial.println("\n========================================");
    switch (currentMenu) {
        case MAIN_MENU:
            showMainMenu();
            break;
        case DEVICE_MENU:
            showDeviceMenu();
            break;
        case CARD_MENU:
            showCardMenu();
            break;
        case CHESS_MENU:
            showChessMenu();
            break;
        case FOOSBALL_MENU:
            showFoosballMenu();
            break;
        case IOT_MENU:
            showIoTMenu();
            break;
    }
    Serial.println("========================================");
    Serial.println("Choose an option:");
}

void showMainMenu() {
    Serial.println("=== MQTT Protocol Tester - Main Menu ===");
    Serial.println("1: Device Status Tester");
    Serial.println("2: Card Registration Tester");
    Serial.println("3: Chess Game Tester");
    Serial.println("4: Foosball Game Tester");
    Serial.println("5: IoT Queries Tester");
    Serial.println("h: Show this menu");
    Serial.println("x: Reset WiFi/MQTT connection");
}

void showDeviceMenu() {
    Serial.println("=== Device Status Menu ===");
    Serial.println("1: Send online status");
    Serial.println("2: Send offline status");
    Serial.println("3: Send chess device status");
    Serial.println("4: Send foosball device status");
    Serial.println("b: Back to main menu");
}

void showCardMenu() {
    Serial.println("=== Card Registration Menu ===");
    Serial.println("1: Register card 1 (RFID123)");
    Serial.println("2: Register card 2 (RFID456)");
    Serial.println("3: Test unknown card");
    Serial.println("b: Back to main menu");
}

void showChessMenu() {
    Serial.println("=== Chess Game Menu ===");
    Serial.println("1: Start new game");
    Serial.println("2: Send chess move");
    Serial.println("3: End game (white wins)");
    Serial.println("4: End game (black wins)");
    Serial.println("5: End game (draw)");
    Serial.println("6: Simulate error");
    Serial.println("b: Back to main menu");
}

void showFoosballMenu() {
    Serial.println("=== Foosball Game Menu ===");
    Serial.println("1: Start new game");
    Serial.println("2: Goal for player 1");
    Serial.println("3: Goal for player 2");
    Serial.println("4: End game (normal)");
    Serial.println("5: Abort game");
    Serial.println("6: Simulate error");
    Serial.println("b: Back to main menu");
}

void showIoTMenu() {
    Serial.println("=== IoT Queries Menu ===");
    Serial.println("1: RFID Query");
    Serial.println("2: Active Games Query");
    Serial.println("3: Statistics Query (daily)");
    Serial.println("4: Statistics Query (weekly)");
    Serial.println("5: Statistics Query (monthly)");
    Serial.println("6: Send display message");
    Serial.println("b: Back to main menu");
}
