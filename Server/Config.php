<?php
/***********************/
/**
This is a static class that we use to provide our installation-depended configuration details.
 */
class Config {
    /// This is the readable name to be used to describe the organization hosting the server.
    static $g_relying_party_name = '<NAME OF ORG>';
    /// This is the URI to be used to denote the organization hosting the server.
    static $g_relying_party_uri = '<URI OF SERVER>';
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
