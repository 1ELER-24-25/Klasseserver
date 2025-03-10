
-- Foosball specific tables
CREATE TABLE gaming.foosball_games (
    game_id INTEGER PRIMARY KEY REFERENCES gaming.games(game_id),
    team1_score INTEGER DEFAULT 0,
    team2_score INTEGER DEFAULT 0,
    winning_team INTEGER,
    completed BOOLEAN DEFAULT false,
    termination_reason VARCHAR(20) CHECK (termination_reason IN ('normal', 'manual_stop', 'fatal_error', 'connection_lost', 'timeout')),
    error_code VARCHAR(10),
    CONSTRAINT valid_score CHECK (team1_score <= 10 AND team2_score <= 10)
);

CREATE TABLE gaming.foosball_goals (
    goal_id SERIAL PRIMARY KEY,
    game_id INTEGER REFERENCES gaming.foosball_games(game_id),
    scoring_team INTEGER NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    mqtt_timestamp BIGINT,
    CONSTRAINT valid_team CHECK (scoring_team IN (1, 2))
);

-- Add index for performance
CREATE INDEX idx_foosball_goals_timestamp ON gaming.foosball_goals(timestamp);

-- Add a view for goal timeline
CREATE OR REPLACE VIEW gaming.foosball_game_timeline AS
SELECT 
    g.game_id,
    fg.scoring_team,
    fg.timestamp,
    fg.mqtt_timestamp,
    EXTRACT(EPOCH FROM (fg.timestamp - g.start_time)) as seconds_from_start
FROM gaming.games g
JOIN gaming.foosball_games f ON g.game_id = f.game_id
JOIN gaming.foosball_goals fg ON f.game_id = fg.game_id
ORDER BY fg.timestamp;

-- Chess specific tables
CREATE TABLE gaming.chess_games (
    game_id INTEGER PRIMARY KEY REFERENCES gaming.games(game_id),
    result VARCHAR(10),
    completed BOOLEAN DEFAULT false,
    termination_reason VARCHAR(20) CHECK (termination_reason IN ('normal', 'manual_stop', 'fatal_error', 'connection_lost', 'timeout')),
    termination_details VARCHAR(50),
    error_code VARCHAR(10),
    time_control VARCHAR(50) DEFAULT '5+0'
);

CREATE TABLE gaming.chess_positions (
    position_id SERIAL PRIMARY KEY,
    game_id INTEGER REFERENCES gaming.chess_games(game_id),
    move_number INTEGER,
    pgn TEXT,           -- Changed from fen VARCHAR(100)
    last_move VARCHAR(10),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    mqtt_timestamp BIGINT
);

-- Create indexes for performance
CREATE INDEX idx_foosball_goals_game ON gaming.foosball_goals(game_id);
CREATE INDEX idx_chess_positions_game ON gaming.chess_positions(game_id);
CREATE INDEX idx_chess_positions_timestamp ON gaming.chess_positions(timestamp);

-- Add a view for chess game timeline
CREATE OR REPLACE VIEW gaming.chess_game_timeline AS
SELECT 
    g.game_id,
    cp.move_number,
    cp.ply,
    cp.fen,
    cp.evaluation,
    cp.time_spent,
    cp.timestamp,
    cp.mqtt_timestamp,
    EXTRACT(EPOCH FROM (cp.timestamp - g.start_time)) as seconds_from_start
FROM gaming.games g
JOIN gaming.chess_games c ON g.game_id = c.game_id
JOIN gaming.chess_positions cp ON c.game_id = cp.game_id
ORDER BY cp.timestamp;

-- IoT devices table
CREATE TABLE gaming.iot_devices (
    device_id VARCHAR(50) PRIMARY KEY,
    device_type VARCHAR(20) CHECK (device_type IN ('DISPLAY', 'SCANNER', 'SENSOR')),
    capabilities JSONB,
    authorized_capabilities JSONB,
    last_heartbeat TIMESTAMP,
    status VARCHAR(20) DEFAULT 'offline',
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Device errors table
CREATE TABLE gaming.device_errors (
    error_id SERIAL PRIMARY KEY,
    device_id VARCHAR(50) REFERENCES gaming.iot_devices(device_id),
    error_code VARCHAR(10),
    severity VARCHAR(10) CHECK (severity IN ('fatal', 'warning')),
    message TEXT,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes
CREATE INDEX idx_foosball_goals_timestamp ON gaming.foosball_goals(timestamp);
CREATE INDEX idx_chess_positions_game_id ON gaming.chess_positions(game_id);
CREATE INDEX idx_iot_devices_status ON gaming.iot_devices(status);
CREATE INDEX idx_device_errors_timestamp ON gaming.device_errors(timestamp);
