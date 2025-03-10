<?php
header('Content-Type: application/json');

// First try to get the local network IP
$ip = shell_exec("ip route get 1 | awk '{print $(NF-2);exit}'");

if (empty($ip)) {
    // Try getting the host IP from Docker
    $ip = shell_exec("hostname -I | awk '{print $1}'");
}

if (empty($ip)) {
    // If still empty, try getting from HTTP_HOST
    $ip = $_SERVER['HTTP_HOST'];
    // Remove port number if present
    $ip = preg_replace('/:\d+$/', '', $ip);
}

echo json_encode(['ip' => trim($ip)]);
?>
