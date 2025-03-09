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

// Get user IDs from RFID cards
$query = "
    SELECT user_id 
    FROM gaming.rfid_cards 
    WHERE uid = $1 
    AND is_active = true
";

$result1 = pg_query_params($dbconn, $query, array($data['player1_card']));
$result2 = pg_query_params($dbconn, $query, array($data['player2_card']));

if (!$result1 || !$result2) {
    die(json_encode(['error' => 'Invalid RFID cards']));
}

$player1 = pg_fetch_assoc($result1);
$player2 = pg_fetch_assoc($result2);

if (!$player1 || !$player2) {
    die(json_encode(['error' => 'Players not found']));
}

// Determine winner
$winner = null;
if (isset($data['winner_card']) && $data['winner_card'] !== '') {
    if ($data['winner_card'] === $data['player1_card']) {
        $winner = $player1['user_id'];
    } else if ($data['winner_card'] === $data['player2_card']) {
        $winner = $player2['user_id'];
    }
}

// Create and complete game
$query = "SELECT gaming.create_and_complete_game($1, $2, $3, $4)";
$result = pg_query_params($dbconn, $query, array(
    $data['game_type'],
    $player1['user_id'],
    $player2['user_id'],
    $winner
));

if (!$result) {
    die(json_encode(['error' => 'Failed to create game']));
}

echo json_encode(['success' => true, 'game_id' => pg_fetch_result($result, 0, 0)]);