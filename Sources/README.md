![Icon](./Icon.png)

# Passkeys Demo Project

Client Implementation

## Overview

This client is written in [Swift](https://www.swift.org). It is a "native" client for iOS. The PassKeys implementation is provided as [a "framework-independent" library](https://github.com/LittleGreenViper/PassKeysDemo/blob/master/Sources/PassKeysDemo/Shared/Sources/PKD_Handler.swift), and targets are provided for both a [UIKit](https://developer.apple.com/documentation/uikit/) app, and a [SwiftUI](https://developer.apple.com/swiftui/) app. The client app provides a basic UI to access and modify the server information.

### Operation

- **C**reate - This is how a user registers a new account. They provide a string that is used as a "tag" for the passkey that will represent the account on the server. After creating the passkey, they select that passkey, whenever they want to log in.

- **R**ead - After the user logs in, their client reads the data stored in the server, and populates the UI elements.

- **U**pdate - After the user logs in, their client allows them to change the Display Name and the Credo, to be stored on the server.

- **D**elete - After the user logs in, they can delete their entire server account.

> NOTE: Deleting the server account **does not** delete the passkey! The user needs to do that manually, via [the Settings App](https://support.apple.com/guide/iphone/find-settings-iph079e1fe9d/17.0/ios/17.0), or [the Passwords App](https://support.apple.com/en-us/120758).

## Requirements

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
