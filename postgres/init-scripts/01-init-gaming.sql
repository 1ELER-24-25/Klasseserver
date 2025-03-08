-- Initialize gaming schema and base tables
CREATE SCHEMA IF NOT EXISTS gaming;

-- Users table
CREATE TABLE IF NOT EXISTS gaming.users (
    user_id SERIAL PRIMARY KEY,
    username VARCHAR(50) UNIQUE NOT NULL,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- RFID cards table
CREATE TABLE IF NOT EXISTS gaming.rfid_cards (
    card_id SERIAL PRIMARY KEY,
    uid VARCHAR(50) UNIQUE NOT NULL,
    user_id INTEGER REFERENCES gaming.users(user_id),
    is_active BOOLEAN DEFAULT true,
    registered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Game types
CREATE TABLE IF NOT EXISTS gaming.game_types (
    game_type_id SERIAL PRIMARY KEY,
    name VARCHAR(50) UNIQUE NOT NULL,
    description TEXT,
    default_elo INTEGER DEFAULT 1200,
    k_factor INTEGER NOT NULL DEFAULT 32
);

-- Games table
CREATE TABLE IF NOT EXISTS gaming.games (
    game_id SERIAL PRIMARY KEY,
    game_type_id INTEGER REFERENCES gaming.game_types(game_type_id),
    start_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(20) DEFAULT 'IN_PROGRESS',
    ratings_processed BOOLEAN DEFAULT FALSE
);

-- User ratings
CREATE TABLE IF NOT EXISTS gaming.user_ratings (
    user_id INTEGER REFERENCES gaming.users(user_id),
    game_type_id INTEGER REFERENCES gaming.game_types(game_type_id),
    elo_rating INTEGER NOT NULL DEFAULT 1200,
    games_played INTEGER DEFAULT 0,
    last_game_date TIMESTAMP,
    PRIMARY KEY (user_id, game_type_id)
);

-- Game participants
CREATE TABLE IF NOT EXISTS gaming.game_participants (
    game_id INTEGER REFERENCES gaming.games(game_id),
    user_id INTEGER REFERENCES gaming.users(user_id),
    team INTEGER,
    PRIMARY KEY (game_id, user_id)
);

-- Rating history
CREATE TABLE IF NOT EXISTS gaming.rating_history (
    history_id SERIAL PRIMARY KEY,
    user_id INTEGER REFERENCES gaming.users(user_id),
    game_type_id INTEGER REFERENCES gaming.game_types(game_type_id),
    game_id INTEGER REFERENCES gaming.games(game_id),
    old_rating INTEGER NOT NULL,
    new_rating INTEGER NOT NULL,
    rating_change INTEGER GENERATED ALWAYS AS (new_rating - old_rating) STORED,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create indexes if they don't exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_rfid_uid') THEN
        CREATE INDEX idx_rfid_uid ON gaming.rfid_cards(uid);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_game_start') THEN
        CREATE INDEX idx_game_start ON gaming.games(start_time);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_game_status') THEN
        CREATE INDEX idx_game_status ON gaming.games(status);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_user_ratings') THEN
        CREATE INDEX idx_user_ratings ON gaming.user_ratings(user_id, game_type_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_rating_history_user') THEN
        CREATE INDEX idx_rating_history_user ON gaming.rating_history(user_id, game_type_id);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM pg_indexes WHERE indexname = 'idx_rating_history_game') THEN
        CREATE INDEX idx_rating_history_game ON gaming.rating_history(game_id);
    END IF;
END $$;
