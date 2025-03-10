<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);
header('Content-Type: application/json');

$dbconn = pg_connect("host=postgres dbname=klasseserver_db user=admin password=klokkeprosjekt");

if (!$dbconn) {
    die(json_encode(['error' => 'Database connection failed']));
}

// Get POST data
$data = json_decode(file_get_contents('php://input'), true);

if (!$data) {
    die(json_encode(['error' => 'Invalid JSON data']));
}

// Validate required fields
if (!isset($data['game_type']) || !isset($data['player1_card']) || !isset($data['player2_card'])) {
    die(json_encode(['error' => 'Missing required fields']));
}

// Get usernames from RFID cards
$query = "
    SELECT u.username 
    FROM gaming.users u
    JOIN gaming.rfid_cards r ON u.user_id = r.user_id 
    WHERE r.uid = $1 
    AND r.is_active = true
";

$result1 = pg_query_params($dbconn, $query, array($data['player1_card']));
$result2 = pg_query_params($dbconn, $query, array($data['player2_card']));

if (!$result1 || !$result2) {
    die(json_encode(['error' => 'Database query failed']));
}

$player1 = pg_fetch_assoc($result1);
$player2 = pg_fetch_assoc($result2);

if (!$player1 || !$player2) {
    die(json_encode(['error' => 'One or both players not found']));
}

// Determine winner username
$winner = null;
if (isset($data['winner_card']) && $data['winner_card'] !== '') {
    $winner_query = pg_query_params($dbconn, $query, array($data['winner_card']));
    if ($winner_query) {
        $winner_row = pg_fetch_assoc($winner_query);
        if ($winner_row) {
            $winner = $winner_row['username'];
        }
    }
}

// Create and complete game
$result = pg_query_params($dbconn, 
    "SELECT gaming.create_and_complete_game($1, $2, $3, $4)",
    array(
        $data['game_type'],
        $player1['username'],
        $player2['username'],
        $winner
    )
);

if (!$result) {
    die(json_encode(['error' => 'Failed to create game']));
}

echo json_encode(['success' => true, 'game_id' => pg_fetch_result($result, 0, 0)]);
