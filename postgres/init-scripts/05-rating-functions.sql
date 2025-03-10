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
    p_game_id INTEGER
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
    v_completed BOOLEAN;
    v_termination_reason VARCHAR;
BEGIN
    -- Get game type and k-factor
    SELECT game_type_id INTO v_game_type_id
    FROM gaming.games
    WHERE game_id = p_game_id;

    SELECT k_factor INTO v_k_factor
    FROM gaming.game_types
    WHERE game_type_id = v_game_type_id;

    -- Get completion status based on game type
    CASE 
        WHEN EXISTS (SELECT 1 FROM gaming.foosball_games WHERE game_id = p_game_id) THEN
            SELECT completed, termination_reason INTO v_completed, v_termination_reason
            FROM gaming.foosball_games WHERE game_id = p_game_id;
        WHEN EXISTS (SELECT 1 FROM gaming.chess_games WHERE game_id = p_game_id) THEN
            SELECT completed, termination_reason INTO v_completed, v_termination_reason
            FROM gaming.chess_games WHERE game_id = p_game_id;
    END CASE;

    -- Only update ratings for completed games with normal termination
    IF NOT (v_completed AND v_termination_reason = 'normal') THEN
        RETURN;
    END IF;

    -- Get players
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

    -- Determine actual score based on game type
    CASE 
        WHEN EXISTS (SELECT 1 FROM gaming.foosball_games WHERE game_id = p_game_id) THEN
            SELECT 
                CASE 
                    WHEN team1_score > team2_score THEN 1.0
                    WHEN team1_score < team2_score THEN 0.0
                    ELSE 0.5
                END INTO v_player1_score
            FROM gaming.foosball_games 
            WHERE game_id = p_game_id;
        WHEN EXISTS (SELECT 1 FROM gaming.chess_games WHERE game_id = p_game_id) THEN
            SELECT 
                CASE 
                    WHEN result = '1-0' THEN 1.0
                    WHEN result = '0-1' THEN 0.0
                    ELSE 0.5
                END INTO v_player1_score
            FROM gaming.chess_games 
            WHERE game_id = p_game_id;
    END CASE;

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

-- Trigger function to automatically update ratings when a game is completed
CREATE OR REPLACE FUNCTION gaming.trigger_update_ratings()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.completed = true AND NEW.termination_reason = 'normal') THEN
        PERFORM gaming.update_ratings(NEW.game_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for both game types
CREATE TRIGGER update_foosball_ratings
AFTER UPDATE ON gaming.foosball_games
FOR EACH ROW
WHEN (OLD.completed IS DISTINCT FROM NEW.completed)
EXECUTE FUNCTION gaming.trigger_update_ratings();

CREATE TRIGGER update_chess_ratings
AFTER UPDATE ON gaming.chess_games
FOR EACH ROW
WHEN (OLD.completed IS DISTINCT FROM NEW.completed)
EXECUTE FUNCTION gaming.trigger_update_ratings();
