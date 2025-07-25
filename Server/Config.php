<?php
class Config {
    static $g_relying_party_name = "<NAME OF ORG>";
    static $g_db_name = '<DATABASE NAME>';
    static $g_db_host = 'localhost';
    static $g_db_type = 'mysql';
    static $g_db_login = '<DB LOGIN>';
    static $g_db_password = '<DB PASSWORD>';
}
    
function base64url_encode($data) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

function base64url_decode(string $data): string|false {
    $data = strtr($data, '-_', '+/');
    $padding = strlen($data) % 4;
    if ($padding > 0) {
        $data .= str_repeat('=', 4 - $padding);
    }
    return base64_decode($data);
}