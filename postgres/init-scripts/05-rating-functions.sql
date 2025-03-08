-- Function to calculate expected score
CREATE OR REPLACE FUNCTION gaming.calculate_expected_score(
    rating1 INTEGER,
    rating2 INTEGER
) RETURNS FLOAT AS $$
BEGIN
    RETURN 1.0 / (1.0 + POWER(10.0, (rating2 - rating1)::FLOAT / 400.0));
END;
$$ LANGUAGE plpgsql;

-- Function to update ratings for an individual game
CREATE OR REPLACE FUNCTION gaming.update_ratings(
    p_game_id INTEGER,
    p_winner_id INTEGER
) RETURNS VOID AS $$
DECLARE
    v_game_type_id INTEGER;
    v_k_factor INTEGER;
    v_player1_id INTEGER;
    v_player2_id INTEGER;
    v_player1_rating INTEGER;
    v_player2_rating INTEGER;
    v_expected_score FLOAT;
    v_player1_score FLOAT;
BEGIN
    -- Get game type and k-factor
    SELECT game_type_id INTO v_game_type_id
    FROM gaming.games
    WHERE game_id = p_game_id;

    SELECT k_factor INTO v_k_factor
    FROM gaming.game_types
    WHERE game_type_id = v_game_type_id;

    -- Get players (simplified version)
    SELECT MIN(user_id), MAX(user_id) 
    INTO v_player1_id, v_player2_id
    FROM gaming.game_participants
    WHERE game_id = p_game_id;

    -- Get current ratings
    SELECT elo_rating INTO v_player1_rating
    FROM gaming.user_ratings
    WHERE user_id = v_player1_id AND game_type_id = v_game_type_id;

    SELECT elo_rating INTO v_player2_rating
    FROM gaming.user_ratings
    WHERE user_id = v_player2_id AND game_type_id = v_game_type_id;

    -- Calculate expected score for player 1
    v_expected_score := gaming.calculate_expected_score(v_player1_rating, v_player2_rating);

    -- Set actual score
    v_player1_score := CASE
        WHEN p_winner_id = v_player1_id THEN 1.0
        WHEN p_winner_id = v_player2_id THEN 0.0
        ELSE 0.5  -- Draw
    END;

    -- Update player 1 rating
    INSERT INTO gaming.rating_history (
        user_id, game_type_id, game_id, old_rating, new_rating
    )
    VALUES (
        v_player1_id,
        v_game_type_id,
        p_game_id,
        v_player1_rating,
        v_player1_rating + (v_k_factor * (v_player1_score - v_expected_score))::INTEGER
    );

    UPDATE gaming.user_ratings
    SET 
        elo_rating = v_player1_rating + (v_k_factor * (v_player1_score - v_expected_score))::INTEGER,
        games_played = games_played + 1,
        last_game_date = CURRENT_TIMESTAMP
    WHERE user_id = v_player1_id AND game_type_id = v_game_type_id;

    -- Update player 2 rating
    INSERT INTO gaming.rating_history (
        user_id, game_type_id, game_id, old_rating, new_rating
    )
    VALUES (
        v_player2_id,
        v_game_type_id,
        p_game_id,
        v_player2_rating,
        v_player2_rating + (v_k_factor * ((1 - v_player1_score) - (1 - v_expected_score)))::INTEGER
    );

    UPDATE gaming.user_ratings
    SET 
        elo_rating = v_player2_rating + (v_k_factor * ((1 - v_player1_score) - (1 - v_expected_score)))::INTEGER,
        games_played = games_played + 1,
        last_game_date = CURRENT_TIMESTAMP
    WHERE user_id = v_player2_id AND game_type_id = v_game_type_id;

    -- Mark game as processed
    UPDATE gaming.games
    SET 
        ratings_processed = true,
        end_time = CURRENT_TIMESTAMP,
        status = 'COMPLETED'
    WHERE game_id = p_game_id;
END;
$$ LANGUAGE plpgsql;

-- Function to create and complete a game
CREATE OR REPLACE FUNCTION gaming.create_and_complete_game(
    p_game_type_name VARCHAR,
    p_player1_username VARCHAR,
    p_player2_username VARCHAR,
    p_winner_username VARCHAR DEFAULT NULL
) RETURNS INTEGER AS $$
DECLARE
    v_game_id INTEGER;
    v_game_type_id INTEGER;
    v_player1_id INTEGER;
    v_player2_id INTEGER;
    v_winner_id INTEGER;
BEGIN
    -- Get game type ID
    SELECT game_type_id INTO v_game_type_id
    FROM gaming.game_types
    WHERE name = p_game_type_name;

    -- Get player IDs
    SELECT user_id INTO v_player1_id
    FROM gaming.users
    WHERE username = p_player1_username;

    SELECT user_id INTO v_player2_id
    FROM gaming.users
    WHERE username = p_player2_username;

    IF p_winner_username IS NOT NULL THEN
        SELECT user_id INTO v_winner_id
        FROM gaming.users
        WHERE username = p_winner_username;
    END IF;

    -- Create new game
    INSERT INTO gaming.games (game_type_id)
    VALUES (v_game_type_id)
    RETURNING game_id INTO v_game_id;

    -- Add players
    INSERT INTO gaming.game_participants (game_id, user_id)
    VALUES 
        (v_game_id, v_player1_id),
        (v_game_id, v_player2_id);

    -- Update ratings
    PERFORM gaming.update_ratings(v_game_id, v_winner_id);

    RETURN v_game_id;
END;
$$ LANGUAGE plpgsql;
