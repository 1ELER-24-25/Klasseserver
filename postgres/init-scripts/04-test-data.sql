-- Create test users
INSERT INTO gaming.users (username, first_name, last_name)
VALUES
    ('player1', 'John', 'Doe'),
    ('player2', 'Jane', 'Smith'),
    ('player3', 'Michael', 'Johnson');

-- Create RFID cards for users
INSERT INTO gaming.rfid_cards (uid, user_id)
SELECT 'CARD001', user_id FROM gaming.users WHERE username = 'player1'
UNION ALL
SELECT 'CARD002', user_id FROM gaming.users WHERE username = 'player2'
UNION ALL
SELECT 'CARD003', user_id FROM gaming.users WHERE username = 'player3';

-- Register test IoT devices
INSERT INTO gaming.iot_devices (device_id, device_type, capabilities, authorized_capabilities, status)
VALUES
    ('ESP32_001', 'SCANNER', '["rfid_read", "display"]', '["rfid_read", "display"]', 'online'),
    ('ESP32_002', 'DISPLAY', '["display"]', '["display"]', 'online'),
    ('ESP32_003', 'SENSOR', '["temperature", "humidity"]', '["temperature", "humidity"]', 'online');

-- Create a completed foosball game
WITH new_game AS (
    INSERT INTO gaming.games (game_type_id, status, start_time, end_time)
    SELECT game_type_id, 'COMPLETED', 
           CURRENT_TIMESTAMP - interval '1 hour',
           CURRENT_TIMESTAMP - interval '30 minutes'
    FROM gaming.game_types 
    WHERE name = 'FOOSBALL'
    RETURNING game_id
)
INSERT INTO gaming.foosball_games (game_id, team1_score, team2_score, winning_team, completed, termination_reason)
SELECT game_id, 5, 3, 1, true, 'normal'
FROM new_game;

-- Create an interrupted chess game
WITH new_game AS (
    INSERT INTO gaming.games (game_type_id, status, start_time, end_time)
    SELECT game_type_id, 'COMPLETED',
           CURRENT_TIMESTAMP - interval '2 hours',
           CURRENT_TIMESTAMP - interval '1 hour 45 minutes'
    FROM gaming.game_types
    WHERE name = 'CHESS'
    RETURNING game_id
)
INSERT INTO gaming.chess_games (game_id, completed, termination_reason, error_code)
SELECT game_id, false, 'connection_lost', 'ERR_007'
FROM new_game;

-- Add some device errors
INSERT INTO gaming.device_errors (device_id, error_code, severity, message)
VALUES
    ('ESP32_001', 'IOT_003', 'warning', 'Rate limit exceeded'),
    ('ESP32_002', 'IOT_001', 'fatal', 'Device registration failed');

-- Add some test chess moves
INSERT INTO gaming.chess_positions (game_id, move_number, pgn, last_move, mqtt_timestamp)
VALUES 
    (1, 1, '1. e4', 'e4', 1234567890),
    (1, 2, '1. e4 e5', 'e5', 1234567891),
    (1, 3, '1. e4 e5 2. Nf3', 'Nf3', 1234567892);
