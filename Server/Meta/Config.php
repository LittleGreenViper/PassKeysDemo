<?php
/*
    © Copyright 2025, Little Green Viper Software Development LLC

    LICENSE:

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and
    associated documentation files (the "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the
    following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial
    portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT
    LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
    WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
/***********************/
/**
This is a static class that we use to provide our installation-dependent configuration details.

It is probably best to locate this file somewhere outside the HTTP directory, so it can't be scanned by anyone.

Set the line in index.php, that looks like this:

    require_once "./Config.php";

to point to wherever it is. The default has it in the same directory as the index file.
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
