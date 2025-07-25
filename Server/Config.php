<?php
/***********************/
/**
This is a static class that we use to provide our installation-depended configuration details.
 */
class Config {
    /// This is the readable name to be used to describe the organization hosting the server.
    static $g_relying_party_name = "<NAME OF ORG>";
    /// This is the internal database name.
    static $g_db_name = '<DATABASE NAME>';
    /// This is the internal host DNS name or IP address (usually localhost).
    static $g_db_host = 'localhost';
    /// This is the database type (currently, we are specifying MySQL only).
    static $g_db_type = 'mysql';
    /// This is the database username (Must have all satandard permissions).
    static $g_db_login = '<DB LOGIN>';
    /// This is the database user password.
    static $g_db_password = '<DB PASSWORD>';
}

// MARK: - Global Utility Functions

/***********************/
/**
\returns the data provided, as a Base64URL-encoded string.
 */
function base64url_encode(  $data   ///< The data (can be binary) to be converted to Base64URL
                        ) {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/***********************/
/**
\returns the Base64URL-encoded string provided, as the original (possibly binary) data. FALSE, if the conversion fails.
 */
function base64url_decode(string $data  ///< The Base64URL-encoded string to be converted to its original data.
                        ): string|false {
    $data = strtr($data, '-_', '+/');
    $padding = strlen($data) % 4;
    if ($padding > 0) {
        $data .= str_repeat('=', 4 - $padding);
    }
    return base64_decode($data);
}