-- Test rating calculations
DO $$
DECLARE
    v_game_id INTEGER;
BEGIN
    -- First, let's verify our test users and game types exist
    IF NOT EXISTS (SELECT 1 FROM gaming.users WHERE username IN ('player1', 'player2')) THEN
        RAISE EXCEPTION 'Test users not found. Please run 04-test-data.sql first.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM gaming.game_types WHERE name = 'CHESS') THEN
        RAISE EXCEPTION 'Chess game type not found. Please run 03-init-game-types.sql first.';
    END IF;

    -- Store initial ratings
    RAISE NOTICE 'Initial ratings:';
    RAISE NOTICE '----------------------------------------';
    FOR r IN (
        SELECT 
            u.username,
            gt.name as game_type,
            ur.elo_rating
        FROM gaming.user_ratings ur
        JOIN gaming.users u ON ur.user_id = u.user_id
        JOIN gaming.game_types gt ON ur.game_type_id = gt.game_type_id
        WHERE u.username IN ('player1', 'player2')
        AND gt.name = 'CHESS'
        ORDER BY u.username
    ) LOOP
        RAISE NOTICE 'Player: %, Game: %, Rating: %', r.username, r.game_type, r.elo_rating;
    END LOOP;

    -- Simulate a series of games
    -- Game 1: player1 wins
    SELECT gaming.create_and_complete_game('CHESS', 'player1', 'player2', 'player1') INTO v_game_id;
    RAISE NOTICE 'Game 1 completed (player1 wins) - ID: %', v_game_id;

    -- Game 2: player2 wins
    SELECT gaming.create_and_complete_game('CHESS', 'player1', 'player2', 'player2') INTO v_game_id;
    RAISE NOTICE 'Game 2 completed (player2 wins) - ID: %', v_game_id;

    -- Game 3: draw
    SELECT gaming.create_and_complete_game('CHESS', 'player1', 'player2', NULL) INTO v_game_id;
    RAISE NOTICE 'Game 3 completed (draw) - ID: %', v_game_id;

    -- Display final ratings
    RAISE NOTICE '----------------------------------------';
    RAISE NOTICE 'Final ratings:';
    RAISE NOTICE '----------------------------------------';
    FOR r IN (
        SELECT 
            u.username,
            gt.name as game_type,
            ur.elo_rating,
            ur.games_played
        FROM gaming.user_ratings ur
        JOIN gaming.users u ON ur.user_id = u.user_id
        JOIN gaming.game_types gt ON ur.game_type_id = gt.game_type_id
        WHERE u.username IN ('player1', 'player2')
        AND gt.name = 'CHESS'
        ORDER BY u.username
    ) LOOP
        RAISE NOTICE 'Player: %, Game: %, Rating: %, Games played: %', 
            r.username, r.game_type, r.elo_rating, r.games_played;
    END LOOP;

    -- Show rating history
    RAISE NOTICE '----------------------------------------';
    RAISE NOTICE 'Rating history:';
    RAISE NOTICE '----------------------------------------';
    FOR r IN (
        SELECT 
            u.username,
            gt.name as game_type,
            rh.old_rating,
            rh.new_rating,
            (rh.new_rating - rh.old_rating) as rating_change
        FROM gaming.rating_history rh
        JOIN gaming.users u ON rh.user_id = u.user_id
        JOIN gaming.game_types gt ON rh.game_type_id = gt.game_type_id
        WHERE u.username IN ('player1', 'player2')
        AND gt.name = 'CHESS'
        ORDER BY rh.game_id, u.username
    ) LOOP
        RAISE NOTICE 'Player: %, Game: %, Old rating: %, New rating: %, Change: %', 
            r.username, r.game_type, r.old_rating, r.new_rating, r.rating_change;
    END LOOP;

END $$;