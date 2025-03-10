# MQTT Communication Protocol

## Overview
This document describes the MQTT communication protocol used in the Klasseserver project for game tracking and scoring.

## Connection Details
- Broker: Eclipse Mosquitto
- Default Port: 1883
- WebSocket Port: 9001
- QoS Level: 1 (default)

## Common Topics

### Device Status
Topic: `device/status`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "type": "CHESS|FOOSBALL",
    "status": "online|offline",
    "timestamp": 1234567890
}
```

### Card Registration
Topic: `card/register`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "card_id": "RFID123",
    "timestamp": 1234567890
}
```

Topic: `card/response`
Direction: Server → Device
```json
{
    "card_id": "RFID123",
    "status": "success|error",  // error: invalid card format, unknown card, db error
    "is_new": false,
    "player_name": "John Doe", // New user with funny name if is_new is true
    "player_id": "12345",
    "timestamp": 1234567890
}
```

## Foosball Topics

### Game Start
Topic: `foosball/game/start`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "player1_card": "RFID123",
    "player2_card": "RFID456",
    "timestamp": 1234567890
}
```

Topic: `foosball/game/response`
Direction: Server → Device
```json
{
    "game_id": "GAME_001",
    "status": "started|error",
    "player1_name": "John Doe",
    "player2_name": "Jane Smith",
    "timestamp": 1234567890
}
```

### Game Progress
Topic: `foosball/game/goal`
Direction: Device → Server
```json
{
    "game_id": "GAME_001",
    "scoring_player": 1,  // 1 for player1, 2 for player2
    "timestamp": 1234567890
}
```

### Game End
Topic: `foosball/game/end`
Direction: Device → Server
```json
{
    "game_id": "GAME_001",
    "completed": true,  // false for interrupted games
    "final_score": {
        "player1": 5,
        "player2": 3
    },
    "termination_reason": "normal|manual_stop|fatal_error|connection_lost|timeout",
    "error_code": "ERR_001",  // optional, included when termination_reason is fatal_error
    "timestamp": 1234567890
}
```

## Chess Topics

### Game Start
Topic: `chess/game/start`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "player1_card": "RFID123",
    "player2_card": "RFID456",
    "timestamp": 1234567890
}
```

Topic: `chess/game/response`
Direction: Server → Device
```json
{
    "game_id": "GAME_001",
    "status": "started|error",
    "white_player": "John Doe",
    "black_player": "Jane Smith",
    "timestamp": 1234567890
}
```

### Game Progress
Topic: `chess/game/move`
Direction: Device → Server
```json
{
    "game_id": "GAME_001",
    "pgn": "1. e4 e5 2. Nf3 Nc6",  // Complete game notation up to current move
    "move_number": 4,
    "last_move": "Nc6",            // The last move made
    "timestamp": 1234567890
}
```

Note: Each move message contains the complete PGN (Portable Game Notation) string representing:
- All moves made in the game so far
- The last move is provided separately for easy processing
- Move numbers are counted as full moves (each player's turn counts as half a move)

### Game End
Topic: `chess/game/end`
Direction: Device → Server
```json
{
    "game_id": "GAME_001",
    "completed": true,  // false for interrupted games
    "result": "1-0|0-1|1/2-1/2",  // only included for completed games
    "termination_reason": "normal|manual_stop|fatal_error|connection_lost|timeout",
    "termination_details": "checkmate|resignation|stalemate|repetition|fifty_move|agreement|insufficient_material",  // only for normal termination
    "error_code": "ERR_001",  // optional, included when termination_reason is fatal_error
    "timestamp": 1234567890
}
```

### Termination Reasons
- `normal`: Game finished naturally (checkmate, final score reached, etc.)
- `manual_stop`: Game manually stopped by controller or players
- `fatal_error`: Game stopped due to system error (see error_code)
- `connection_lost`: Communication failure between device and server
- `timeout`: Game inactive for too long

## Error Handling

### Game-Specific Errors
Topic: `foosball/error`
Topic: `chess/error`
Direction: Bidirectional
```json
{
    "device_id": "ESP32_001",
    "game_id": "GAME_001",
    "error_code": "ERR_001",
    "severity": "fatal|warning",  // fatal errors abort the game, warnings allow continuation
    "message": "Error description",
    "timestamp": 1234567890
}
```

### Error Codes
- Fatal Errors (abort game):
  - ERR_001: Invalid card format
  - ERR_002: Unknown card ID
  - ERR_003: Game not found
  - ERR_005: Device not registered
  - ERR_006: Invalid game state

- Warning Errors (game continues):
  - ERR_004: Invalid move (chess only - move can be retried)
  - ERR_007: Temporary connection issue
  - ERR_008: Score reporting delay

## General Purpose IoT Topics

### Device Registration
Topic: `iot/register`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "type": "DISPLAY|SCANNER|SENSOR",
    "capabilities": ["rfid_read", "display", "temperature"],
    "timestamp": 1234567890
}
```

Topic: `iot/register/response`
Direction: Server → Device
```json
{
    "device_id": "ESP32_001",
    "status": "success|error",
    "authorized_capabilities": ["rfid_read", "display"],  // Server confirms allowed capabilities
    "refresh_interval": 300,  // How often to send heartbeat in seconds
    "timestamp": 1234567890
}
```

### Time Sync
Topic: `iot/time/request`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "timestamp": 1234567890
}
```

Topic: `iot/time/response`
Direction: Server → Device
```json
{
    "unix_timestamp": 1234567890,
    "timezone": "Europe/Oslo",
    "iso_time": "2024-01-20T15:30:45+01:00"
}
```

### RFID Queries
Topic: `iot/rfid/query`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "card_id": "RFID123",
    "timestamp": 1234567890
}
```

Topic: `iot/rfid/response`
Direction: Server → Device
```json
{
    "card_id": "RFID123",
    "status": "success|error",
    "player_name": "John Doe",
    "player_id": "12345",
    "last_game": "2024-01-20T14:30:00+01:00",  // optional
    "games_played": 42,                         // optional
    "timestamp": 1234567890
}
```

### Game Status Query
Topic: `iot/games/active`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "game_type": "CHESS|FOOSBALL|ALL",  // optional
    "timestamp": 1234567890
}
```

Topic: `iot/games/status`
Direction: Server → Device
```json
{
    "active_games": [
        {
            "game_id": "GAME_001",
            "type": "CHESS",
            "player1": "John Doe",
            "player2": "Jane Smith",
            "start_time": "2024-01-20T15:00:00+01:00",
            "status": "IN_PROGRESS",
            "score": {  // for foosball
                "player1": 3,
                "player2": 2
            }
        }
    ],
    "timestamp": 1234567890
}
```

### Statistics Query
Topic: `iot/stats/request`
Direction: Device → Server
```json
{
    "device_id": "ESP32_001",
    "stat_type": "daily|weekly|monthly",
    "game_type": "CHESS|FOOSBALL|ALL",
    "timestamp": 1234567890
}
```

Topic: `iot/stats/response`
Direction: Server → Device
```json
{
    "period": "daily",
    "game_type": "ALL",
    "total_games": 15,
    "active_players": 8,
    "game_breakdown": {
        "chess": 7,
        "foosball": 8
    },
    "timestamp": 1234567890
}
```

### Display Messages
Topic: `iot/display/message`
Direction: Server → Device
```json
{
    "device_id": "ESP32_001",
    "message_type": "info|alert|celebration",
    "text": "New game starting!",
    "duration": 5000,  // milliseconds
    "timestamp": 1234567890
}
```

### Error Handling
Topic: `iot/error`
Direction: Bidirectional
```json
{
    "device_id": "ESP32_001",
    "error_code": "IOT_001",
    "severity": "fatal|warning",
    "message": "Error description",
    "timestamp": 1234567890
}
```

### IoT Error Codes
- IOT_001: Device registration failed
- IOT_002: Invalid query format
- IOT_003: Rate limit exceeded
- IOT_004: Unauthorized device
- IOT_005: Invalid capability request

## Notes
1. All timestamps are in UNIX timestamp format
2. All messages use QoS level 1 unless specified otherwise
3. Device IDs should be unique per physical device
4. Game IDs are generated by the server
5. All JSON messages should be UTF-8 encoded

