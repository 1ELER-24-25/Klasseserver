-- Test some chess games
SELECT gaming.create_and_complete_game('CHESS', 'player1', 'player2', 'player1');
SELECT gaming.create_and_complete_game('CHESS', 'player2', 'player3', 'player2');

-- Test some foosball games
SELECT gaming.create_and_complete_game('FOOSBALL', 'player1', 'player2', 'player1');
SELECT gaming.create_and_complete_game('FOOSBALL', 'player3', 'player4', NULL); -- Draw

-- Check the results
SELECT 
    u.username,
    gt.name as game_type,
    ur.elo_rating,
    ur.games_played,
    ur.last_game_date
FROM gaming.user_ratings ur
JOIN gaming.users u ON ur.user_id = u.user_id
JOIN gaming.game_types gt ON ur.game_type_id = gt.game_type_id
WHERE ur.games_played > 0
ORDER BY gt.name, ur.elo_rating DESC;

-- Check rating history
SELECT 
    u.username,
    gt.name as game_type,
    rh.old_rating,
    rh.new_rating,
    rh.rating_change,
    rh.timestamp
FROM gaming.rating_history rh
JOIN gaming.users u ON rh.user_id = u.user_id
JOIN gaming.game_types gt ON rh.game_type_id = gt.game_type_id
ORDER BY rh.timestamp;