-- Disable triggers temporarily
SET session_replication_role = 'replica';

-- Drop existing schema if exists
DROP SCHEMA IF EXISTS gaming CASCADE;

-- Re-enable triggers
SET session_replication_role = 'origin';

-- Create schema and tables
\i /docker-entrypoint-initdb.d/01-init-gaming.sql

-- Create game-specific tables
\i /docker-entrypoint-initdb.d/02-init-game-specific.sql

-- Create rating functions
\i /docker-entrypoint-initdb.d/05-rating-functions.sql

-- Initialize game types
\i /docker-entrypoint-initdb.d/03-init-game-types.sql

-- Add test data
\i /docker-entrypoint-initdb.d/04-test-data.sql

-- Run rating tests
\i /docker-entrypoint-initdb.d/06-test-ratings.sql

-- Run test games
\i /docker-entrypoint-initdb.d/07-test-games.sql

-- Verify initialization
DO $$
DECLARE
    user_count INTEGER;
    game_type_count INTEGER;
    chess_game_count INTEGER;
    foosball_game_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM gaming.users;
    SELECT COUNT(*) INTO game_type_count FROM gaming.game_types;
    SELECT COUNT(*) INTO chess_game_count FROM gaming.chess_games;
    SELECT COUNT(*) INTO foosball_game_count FROM gaming.foosball_games;
    
    IF user_count = 0 THEN
        RAISE EXCEPTION 'No users found';
    END IF;
    
    IF game_type_count = 0 THEN
        RAISE EXCEPTION 'No game types found';
    END IF;
    
    IF chess_game_count = 0 AND foosball_game_count = 0 THEN
        RAISE EXCEPTION 'No games found';
    END IF;
    
    RAISE NOTICE 'Initialization successful: % users, % game types, % chess games, % foosball games',
        user_count, game_type_count, chess_game_count, foosball_game_count;
END $$;
