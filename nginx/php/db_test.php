<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

$dbconn = pg_connect("host=postgres dbname=klasseserver_db user=admin password=klokkeprosjekt");
if (!$dbconn) {
    die("Could not connect to database\n");
}
echo "Database connection successful!\n";

$result = pg_query($dbconn, "SELECT COUNT(*) FROM gaming.users");
if (!$result) {
    die("Query failed: " . pg_last_error($dbconn));
}
$count = pg_fetch_result($result, 0, 0);
echo "Number of users in database: $count\n";