<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');

$dbconn = pg_connect("host=postgres dbname=klasseserver_db user=admin password=klokkeprosjekt");

if (!$dbconn) {
    die(json_encode(['error' => 'Failed to connect to database: ' . pg_last_error()]));
}

function getLeaderboard($game_type) {
    global $dbconn;
    $query = "
        SELECT 
            u.username,
            ur.elo_rating
        FROM gaming.user_ratings ur
        JOIN gaming.users u ON ur.user_id = u.user_id
        JOIN gaming.game_types gt ON ur.game_type_id = gt.game_type_id
        WHERE gt.name = $1
        ORDER BY ur.elo_rating DESC
        LIMIT 5
    ";
    $result = pg_query_params($dbconn, $query, array($game_type));
    return $result ? pg_fetch_all($result) : [];
}

function getLastGame($game_type) {
    global $dbconn;
    $query = "
        WITH last_game AS (
            SELECT g.game_id, g.status
            FROM gaming.games g
            JOIN gaming.game_types gt ON g.game_type_id = gt.game_type_id
            WHERE gt.name = $1
            AND g.status = 'COMPLETED'
            ORDER BY g.end_time DESC
            LIMIT 1
        )
        SELECT 
            u1.username as player1,
            u2.username as player2,
            CASE 
                WHEN rh1.new_rating > rh1.old_rating THEN u1.username
                WHEN rh2.new_rating > rh2.old_rating THEN u2.username
                ELSE 'Draw'
            END as result
        FROM last_game lg
        JOIN gaming.game_participants gp1 ON lg.game_id = gp1.game_id
        JOIN gaming.game_participants gp2 ON lg.game_id = gp2.game_id AND gp1.user_id < gp2.user_id
        JOIN gaming.users u1 ON gp1.user_id = u1.user_id
        JOIN gaming.users u2 ON gp2.user_id = u2.user_id
        JOIN gaming.rating_history rh1 ON lg.game_id = rh1.game_id AND rh1.user_id = gp1.user_id
        JOIN gaming.rating_history rh2 ON lg.game_id = rh2.game_id AND rh2.user_id = gp2.user_id
    ";
    
    $result = pg_query_params($dbconn, $query, array($game_type));
    return $result ? pg_fetch_assoc($result) : null;
}

$chess_leaderboard = getLeaderboard('CHESS');
$foosball_leaderboard = getLeaderboard('FOOSBALL');
$last_chess_game = getLastGame('CHESS');
$last_foosball_game = getLastGame('FOOSBALL');

echo json_encode([
    'chess' => [
        'leaderboard' => $chess_leaderboard ?: [],
        'lastGame' => $last_chess_game ?: null
    ],
    'foosball' => [
        'leaderboard' => $foosball_leaderboard ?: [],
        'lastGame' => $last_foosball_game ?: null
    ]
]);
