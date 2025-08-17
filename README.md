![Icon](./icon.png)

# Passkeys Demo Project

Demonstration of iOS PassKeys in Swift.

## Overview

This project demonstrates a very simple [iOS](https://apple.com/ios) implementation of basic "passwordless" [PassKeys](https://fidoalliance.org/passkeys/).

The idea of PassKeys, is that they provide enhanced security over the traditional "Login ID and Password" model, while allowing the user to avoid the travails of dealing with passwords.

More advanced implementation of PassKeys can incorporate things like [YubiKeys](https://www.yubico.com/products/), but that is beyond the scope of this demonstration.
This just illustrates a basic login to a simple [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) server.

[Passkeys](https://developer.apple.com/passkeys/) require explicit server storage of credentials, as opposed to [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/), which stores its data on the client.

[This is the GitHub repository for this project](https://github.com/LittleGreenViper/PassKeysDemo)

## Basic Structure

The demonstration consists of two contexts:

- A [server](https://github.com/LittleGreenViper/PassKeysDemo/tree/master/Server), implemented in [PHP](https://www.php.net), and using a simple [MySQL](https://www.mysql.com) database. This is a basic [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) server, allowing users to create accounts, store a small amount of information securely, then access and modify that information (also securely). The server is implemented almost entirely in [one PHP file](https://github.com/LittleGreenViper/PassKeysDemo/blob/master/Server/PKDServer.class.php).

- A [client](https://github.com/LittleGreenViper/PassKeysDemo/tree/master/Sources/PassKeysDemo), written in [Swift](https://www.swift.org). This is a "native" client for iOS. The PassKeys implementation is provided as [a "framework-independent" library](https://github.com/LittleGreenViper/PassKeysDemo/blob/master/Sources/PassKeysDemo/Shared/Sources/PKD_Handler.swift), and targets are provided for both a [UIKit](https://developer.apple.com/documentation/uikit/) app, and a [SwiftUI](https://developer.apple.com/swiftui/) app. The client app provides a basic UI to access and modify the server information.

## Requirements

- The server side of this project relies on the well-established [WebAuthn PHP Library](https://github.com/lbuchs/WebAuthn), to provide authentication services.

- The server requires a [LAMP](https://en.wikipedia.org/wiki/LAMP_\(software_bundle\)) server, with [PHP](https://www.php.net) 8 or greater, and a [MySQL](https://www.mysql.com)/[MariaDB](https://mariadb.org) database (MySQL 5.4 or greater, or equivalent MariaDB). The [SQL](https://en.wikipedia.org/wiki/SQL) is written in a very "portable" format, however, so adapting to other databases should be fairly straightforward.

- The client requires [iOS](https://apple.com/ios) 17 or greater, and is designed for [Xcode](https://developer.apple.com/xcode/). It is entirely possible to use this in other development environments, but that's up to the person using the project.

- In order to adapt the targets to your own use, you should have [an Apple Developer Account](https://developer.apple.com).

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
