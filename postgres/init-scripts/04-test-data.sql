-- Create test users if they don't exist
INSERT INTO gaming.users (username, first_name, last_name)
SELECT u.username, u.first_name, u.last_name
FROM (VALUES
    ('player1', 'John', 'Doe'),
    ('player2', 'Jane', 'Smith'),
    ('player3', 'Michael', 'Johnson'),
    ('player4', 'Emily', 'Brown'),
    ('player5', 'David', 'Wilson')
) AS u(username, first_name, last_name)
WHERE NOT EXISTS (
    SELECT 1 FROM gaming.users 
    WHERE username = u.username
);

-- Create RFID cards for users that don't have them
INSERT INTO gaming.rfid_cards (uid, user_id)
SELECT 'CARD' || LPAD(u.user_id::text, 8, '0'), u.user_id
FROM gaming.users u
WHERE NOT EXISTS (
    SELECT 1 FROM gaming.rfid_cards r 
    WHERE r.user_id = u.user_id
);

-- Initialize ratings for users that don't have them
INSERT INTO gaming.user_ratings (user_id, game_type_id, elo_rating)
SELECT u.user_id, gt.game_type_id, gt.default_elo
FROM gaming.users u
CROSS JOIN gaming.game_types gt
WHERE NOT EXISTS (
    SELECT 1 FROM gaming.user_ratings r 
    WHERE r.user_id = u.user_id 
    AND r.game_type_id = gt.game_type_id
);

-- Verify data
DO $$
DECLARE
    user_count INTEGER;
    card_count INTEGER;
    rating_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO user_count FROM gaming.users;
    SELECT COUNT(*) INTO card_count FROM gaming.rfid_cards;
    SELECT COUNT(*) INTO rating_count FROM gaming.user_ratings;
    
    IF user_count < 5 THEN
        RAISE EXCEPTION 'Expected at least 5 users, found %', user_count;
    END IF;
    
    IF card_count < 5 THEN
        RAISE EXCEPTION 'Expected at least 5 RFID cards, found %', card_count;
    END IF;
    
    IF rating_count < 10 THEN
        RAISE EXCEPTION 'Expected at least 10 ratings (5 users × 2 game types), found %', rating_count;
    END IF;
END $$;
