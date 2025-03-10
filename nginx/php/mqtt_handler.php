<?php
require(__DIR__ . '/vendor/autoload.php');

use PhpMqtt\Client\MqttClient;
use PhpMqtt\Client\ConnectionSettings;

function debug($message) {
    $logMessage = "[" . date('Y-m-d H:i:s') . "] $message\n";
    error_log($logMessage);
    echo $logMessage;
}

function generateFunnyName() {
    $adjectives = ['Happy', 'Clever', 'Brave', 'Swift', 'Mighty', 'Quick', 'Wise', 'Noble', 'Agile', 'Bold'];
    $nouns = ['Panda', 'Tiger', 'Eagle', 'Dragon', 'Wolf', 'Lion', 'Hawk', 'Bear', 'Fox', 'Owl'];
    
    // Add timestamp to ensure uniqueness
    $name = $adjectives[array_rand($adjectives)] . ' ' . $nouns[array_rand($nouns)];
    return $name . '_' . substr(uniqid(), -4);
}

$dbconn = pg_connect("host=postgres dbname=klasseserver_db user=admin password=klokkeprosjekt");
if (!$dbconn) {
    die("Could not connect to database\n");
}

try {
    $mqtt = new MqttClient('mosquitto', 1883);
    debug("Connecting to MQTT broker...");
    
    $clientId = 'php-mqtt-' . uniqid();
    
    $connectionSettings = new ConnectionSettings();
    $connectionSettings
        ->setLastWillTopic('server/status')
        ->setLastWillMessage('offline')
        ->setLastWillQualityOfService(1)
        ->setRetainLastWill(true);
    
    $mqtt->connect($connectionSettings, true);
    
    debug("Connected to MQTT broker successfully");
    $mqtt->publish('server/status', 'online', 1, true);
    
    $mqtt->subscribe('card/register', function($topic, $message) use ($mqtt, $dbconn) {
        debug("Received message on topic '$topic': $message");
        
        try {
            $data = json_decode($message, true);
            if (!isset($data['card_id']) || !isset($data['device_id'])) {
                debug("Error: Invalid message format - missing required fields");
                $response = [
                    'card_id' => $data['card_id'] ?? 'unknown',
                    'status' => 'error',
                    'message' => 'Invalid message format',
                    'timestamp' => time()
                ];
                $mqtt->publish('card/response', json_encode($response), 1);
                return;
            }
            
            $cardId = $data['card_id'];
            $deviceId = $data['device_id'];
            debug("Processing card ID: $cardId from device: $deviceId");
            
            // First check if the card exists
            $query = "
                SELECT u.user_id, u.username, u.first_name, u.last_name 
                FROM gaming.rfid_cards r
                JOIN gaming.users u ON r.user_id = u.user_id
                WHERE r.uid = $1";
            
            $result = pg_query_params($dbconn, $query, array($cardId));
            
            if (!$result) {
                debug("Database error: " . pg_last_error($dbconn));
                $response = [
                    'card_id' => $cardId,
                    'status' => 'error',
                    'message' => 'Database error',
                    'timestamp' => time()
                ];
                $mqtt->publish('card/response', json_encode($response), 1);
                return;
            }
            
            $row = pg_fetch_assoc($result);
            $isNew = false;
            $playerName = '';
            $playerId = null;
            
            if ($row) {
                // Existing user
                $playerName = $row['first_name'] . ' ' . $row['last_name'];
                $playerId = $row['user_id'];
                debug("Found existing player: $playerName");
            } else {
                // New user
                $isNew = true;
                $playerName = generateFunnyName();
                debug("Creating new player: $playerName");
                
                // Start a transaction
                pg_query($dbconn, "BEGIN");
                
                try {
                    // Insert new user
                    $query = "
                        INSERT INTO gaming.users (username, first_name, last_name)
                        VALUES ($1, $2, $3)
                        RETURNING user_id";
                    
                    $result = pg_query_params($dbconn, $query, array(
                        strtolower(str_replace(' ', '_', $playerName)),
                        $playerName,
                        'Player'
                    ));
                    
                    if (!$result) {
                        throw new Exception("Error creating user: " . pg_last_error($dbconn));
                    }
                    
                    $userId = pg_fetch_result($result, 0, 0);
                    
                    // Insert RFID card
                    $query = "
                        INSERT INTO gaming.rfid_cards (uid, user_id)
                        VALUES ($1, $2)";
                    
                    $result = pg_query_params($dbconn, $query, array($cardId, $userId));
                    
                    if (!$result) {
                        throw new Exception("Error creating RFID card: " . pg_last_error($dbconn));
                    }
                    
                    // Insert default ratings
                    $query = "
                        INSERT INTO gaming.user_ratings (user_id, game_type_id, elo_rating)
                        SELECT $1, game_type_id, default_elo
                        FROM gaming.game_types";
                    
                    $result = pg_query_params($dbconn, $query, array($userId));
                    
                    if (!$result) {
                        throw new Exception("Error creating ratings: " . pg_last_error($dbconn));
                    }
                    
                    pg_query($dbconn, "COMMIT");
                    debug("Successfully created new player");
                    
                } catch (Exception $e) {
                    pg_query($dbconn, "ROLLBACK");
                    debug("Error in transaction: " . $e->getMessage());
                    $response = [
                        'card_id' => $cardId,
                        'status' => 'error',
                        'message' => 'Failed to create new user',
                        'timestamp' => time()
                    ];
                    $mqtt->publish('card/response', json_encode($response), 1);
                    return;
                }
            }
            
            $response = [
                'card_id' => $cardId,
                'status' => 'success',
                'is_new' => $isNew,
                'player_name' => $playerName,
                'player_id' => (string)$playerId,
                'timestamp' => time()
            ];
            
            $responseJson = json_encode($response);
            debug("Publishing response to card/response: $responseJson");
            
            $success = $mqtt->publish('card/response', $responseJson, 1);
            debug($success ? "Response published successfully" : "Failed to publish response");
            
        } catch (Exception $e) {
            debug("Error processing message: " . $e->getMessage());
            $response = [
                'card_id' => $cardId ?? 'unknown',
                'status' => 'error',
                'message' => 'Internal server error',
                'timestamp' => time()
            ];
            $mqtt->publish('card/response', json_encode($response), 1);
        }
    });

    $mqtt->subscribe('game/goal', function($topic, $message) use ($dbconn) {
        debug("Received goal: $message");
        $data = json_decode($message, true);
        
        // Insert goal into database
        $query = "
            INSERT INTO gaming.foosball_goals (game_id, scoring_team, mqtt_timestamp)
            SELECT g.game_id, $1, $2
            FROM gaming.games g
            WHERE g.status = 'IN_PROGRESS'
            ORDER BY g.start_time DESC
            LIMIT 1";
        
        $result = pg_query_params($dbconn, $query, array(
            $data['team'],
            $data['timestamp']
        ));
        
        if (!$result) {
            debug("Error recording goal: " . pg_last_error($dbconn));
        }
    });

    $mqtt->subscribe('game/finish', function($topic, $message) use ($dbconn) {
        debug("Received game finish: $message");
        $data = json_decode($message, true);
        
        // Update game status and scores
        $query = "
            WITH game_update AS (
                UPDATE gaming.games
                SET status = 'COMPLETED', end_time = CURRENT_TIMESTAMP
                WHERE status = 'IN_PROGRESS'
                RETURNING game_id
            )
            UPDATE gaming.foosball_games
            SET team1_score = $1, team2_score = $2,
                winning_team = CASE 
                    WHEN $1 > $2 THEN 1
                    WHEN $2 > $1 THEN 2
                    ELSE NULL
                END
            WHERE game_id IN (SELECT game_id FROM game_update)";
        
        $result = pg_query_params($dbconn, $query, array(
            $data['team1_score'],
            $data['team2_score']
        ));
        
        if (!$result) {
            debug("Error finishing game: " . pg_last_error($dbconn));
        }
    });

    $mqtt->subscribe('chess/game/move', function($topic, $message) use ($dbconn) {
        debug("Received chess move: $message");
        $data = json_decode($message, true);
        
        $query = "
            INSERT INTO gaming.chess_positions 
                (game_id, move_number, pgn, last_move, mqtt_timestamp)
            SELECT g.game_id, $1, $2, $3, $4
            FROM gaming.games g
            WHERE g.status = 'IN_PROGRESS'
            AND g.game_id = $5";
        
        $result = pg_query_params($dbconn, $query, array(
            $data['move_number'],
            $data['pgn'],
            $data['last_move'],
            $data['timestamp'],
            $data['game_id']
        ));
        
        if (!$result) {
            debug("Error recording chess move: " . pg_last_error($dbconn));
        }
    });

    debug("Subscribed to card/register, waiting for messages...");
    
    while (true) {
        $mqtt->loop();
    }
    
} catch (Exception $e) {
    debug("Fatal error: " . $e->getMessage());
    exit(1);
}
