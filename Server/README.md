![Icon](Meta/Icon.png)

# Passkeys Demo Project

Server Implementation

## Overview

## Basic Structure

This server is implemented in [PHP](https://www.php.net), and uses a simple [MySQL](https://www.mysql.com) database. It is a basic [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) server, allowing users to create accounts, store a small amount of information securely, then access and modify that information (also securely). The server is implemented almost entirely in [one PHP file](https://github.com/LittleGreenViper/PassKeysDemo/blob/master/Server/PKDServer.class.php).

### Operation

The data stored are two strings: A "Display Name," and a "Credo."

For purposes of this demonstration, these strings are limited to 255 characters in length.

There are two database tables: One is used to strore the passkey credentials, and the other stores the actual user data that is presented and modified by the UI. The user never sees most of the passkey credential information.

The passkey is used in two places: Registration (creating an account), and logging in. After login, the server works in the same way that most of these types of things work.

### The CRUD

- **C**reate - This is how a user registers a new account. They provide a string that is used as a "tag" for the passkey that will represent the account on the server. After creating the passkey, they select that passkey, whenever they want to log in.

- **R**ead - After the user logs in, their client reads the data stored in the server, and populates the UI elements.

- **U**pdate - After the user logs in, their client allows them to change the Display Name and the Credo, to be stored on the server.

- **D**elete - After the user logs in, they can delete their entire server account.

## Requirements

- The server relies on the well-established [WebAuthn PHP Library](https://github.com/lbuchs/WebAuthn), to provide authentication services.

- The server requires a [LAMP](https://en.wikipedia.org/wiki/LAMP_\(software_bundle\)) server, with [PHP](https://www.php.net) 8 or greater, and a [MySQL](https://www.mysql.com)/[MariaDB](https://mariadb.org) database (MySQL 5.4 or greater, or equivalent MariaDB). The [SQL](https://en.wikipedia.org/wiki/SQL) is written in a very "portable" format, however, so adapting to other databases should be fairly straightforward.

## License:

### MIT License

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
