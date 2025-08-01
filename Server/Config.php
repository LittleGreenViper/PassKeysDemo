<?php
/***********************/
/**
This is a static class that we use to provide our installation-depended configuration details.
 */
class Config {
    /// This is the readable name to be used to describe the organization hosting the server.
    static $g_relying_party_name = "<NAME OF ORG>";
    /// This is the URI to be used to denote the organization hosting the server.
    static $g_relying_party_uri = "<URI OF SERVER>";
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
    Converts a binary value to a Base64 URL string.
    @param string $data The data (can be binary) to be converted to Base64URL
    @return the data provided, as a Base64URL-encoded string.
 */
function base64url_encode(string $data): string {
    return rtrim(strtr(base64_encode($data), '+/', '-_'), '=');
}

/***********************/
/**
    Converts a Base64URL string back to its original form.
    @param string $data The Base64URL-encoded string to be converted to its original data.
    @return the Base64URL-encoded string provided, as the original (possibly binary) data. FALSE, if the conversion fails.
 */
function base64url_decode(string $data): string|false {
    return base64_decode(str_pad(strtr($data, '-_', '+/'), strlen($data) % 4, '=', STR_PAD_RIGHT));
}