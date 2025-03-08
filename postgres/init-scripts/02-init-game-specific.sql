-- Foosball specific tables
CREATE TABLE gaming.foosball_games (
    game_id INTEGER PRIMARY KEY REFERENCES gaming.games(game_id),
    team1_score INTEGER DEFAULT 0,
    team2_score INTEGER DEFAULT 0,
    winning_team INTEGER,
    goals_timeline JSONB,
    CONSTRAINT valid_score CHECK (team1_score <= 10 AND team2_score <= 10)
);

CREATE TABLE gaming.foosball_goals (
    goal_id SERIAL PRIMARY KEY,
    game_id INTEGER REFERENCES gaming.foosball_games(game_id),
    scoring_team INTEGER NOT NULL,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Chess specific tables
CREATE TABLE gaming.chess_games (
    game_id INTEGER PRIMARY KEY REFERENCES gaming.games(game_id),
    white_elo INTEGER,
    black_elo INTEGER,
    result VARCHAR(10),
    termination VARCHAR(50),
    eco VARCHAR(3),
    opening VARCHAR(100),
    moves_san TEXT,
    pgn TEXT,
    time_control VARCHAR(50) DEFAULT '5+0'
);

CREATE TABLE gaming.chess_positions (
    position_id SERIAL PRIMARY KEY,
    game_id INTEGER REFERENCES gaming.chess_games(game_id),
    move_number INTEGER,
    ply INTEGER,
    fen VARCHAR(100),
    evaluation DECIMAL,
    time_spent INTEGER,
    UNIQUE (game_id, ply)
);

-- Create indexes
CREATE INDEX idx_foosball_goals_game ON gaming.foosball_goals(game_id);
CREATE INDEX idx_chess_positions_game ON gaming.chess_positions(game_id);
