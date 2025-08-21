# ``PassKeysDemoSwiftUI``

Demonstration of iOS PassKeys in Swift, implemented into a SwiftUI target.

## Overview
![Icon](Icon.png)

This project demonstrates a very simple [iOS](https://apple.com/ios) implementation of basic "passwordless" [PassKeys](https://fidoalliance.org/passkeys/).

The idea of PassKeys, is that they provide enhanced security over the traditional "Login ID and Password" model, while allowing the user to avoid the travails of dealing with passwords.

More advanced implementation of PassKeys can incorporate things like [YubiKeys](https://www.yubico.com/products/), but that is beyond the scope of this demonstration.
This just illustrates a basic login to a simple [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) server.

[Passkeys](https://developer.apple.com/passkeys/) require explicit server storage of credential keys, as opposed to [Sign in with Apple](https://developer.apple.com/sign-in-with-apple/), which can store credentials on the client.

## Basic Structure

The demonstration consists of two contexts:

- A [server](https://github.com/LittleGreenViper/PassKeysDemo/tree/master/Server), implemented in [PHP](https://www.php.net), and using a simple [MySQL](https://www.mysql.com) database. This is a basic [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) server, allowing users to create accounts, store a small amount of information securely, then access and modify that information (also securely). The server is implemented almost entirely in [one PHP file](https://github.com/LittleGreenViper/PassKeysDemo/blob/master/Server/PKDServer.class.php).

- A [client](https://github.com/LittleGreenViper/PassKeysDemo/tree/master/Sources), written in [Swift](https://www.swift.org). This is a "native" client for iOS. The PassKeys implementation is provided as [a "framework-independent" library](https://github.com/LittleGreenViper/PassKeysDemo/blob/master/Sources/PassKeysDemo/Shared/Sources/PKD_Handler.swift), and targets are provided for both a [UIKit](https://developer.apple.com/documentation/uikit/) app, and a [SwiftUI](https://developer.apple.com/swiftui/) app. The client app provides a basic UI to access and modify the server information.

### Operation

The demonstration works by implementing a simple [CRUD](https://en.wikipedia.org/wiki/Create,_read,_update_and_delete) server, accessed via the native iOS client.

The data stored are two strings: A "Display Name," and a "Credo." The Display Name is any name the user wants to call themselves, and the Credo is an aribtrary string. Only the user can see this information (after logging in).

For purposes of this demonstration, these strings are limited to 255 characters in length.

There are two database tables: One is used to strore the passkey credentials, and the other stores the actual user data that is presented and modified by the UI. The user never sees most of the passkey credential information.

The passkey is used in two places: Registration (creating an account), and logging in. After login, the server works in the same way that most of these types of things work.

### The CRUD

- **C**reate - This is how a user registers a new account. They provide a string that is used as a "tag" for the passkey that will represent the account on the server. After creating the passkey, they select that passkey, whenever they want to log in.

- **R**ead - After the user logs in, their client reads the data stored in the server, and populates the UI elements.

- **U**pdate - After the user logs in, their client allows them to change the Display Name and the Credo, to be stored on the server.

- **D**elete - After the user logs in, they can delete their entire server account.

> NOTE: Deleting the server account **does not** delete the passkey! The user needs to do that manually, via [the Settings App](https://support.apple.com/guide/iphone/find-settings-iph079e1fe9d/17.0/ios/17.0), or [the Passwords App](https://support.apple.com/en-us/120758).

## The App

The client app is a very simple, one-view [iOS](https://apple.com/ios) app. It is implemented using both [UIKit](https://developer.apple.com/documentation/uikit/), and [SwiftUI](https://developer.apple.com/swiftui/), The user interface is exactly the same, between them, and they have the same [bundle ID](https://developer.apple.com/documentation/appstoreconnectapi/bundle-ids) (which means there can only be one, installed, at a time), so that each can access the same PassKeys.

Each variant of the app is presented as an [Xcode target](https://developer.apple.com/library/archive/featuredarticles/XcodeConcepts/Concept-Targets.html). The app will work as effectively in the simulator, as it does, on-device. There is no need to log into your Apple account, but doing so, will allow you to share the PassKeys across different devices. You must have biometrics (Touch ID or Face ID) enabled.

### The Main Display

#### Create

Upon startup, the app has not logged in, and you are presented with the Register/Login display (Fig. 1).

At this point, you can register a new account, by typing something into the text box (Fig. 2). This will be the "tag" for the new PassKey.

| The Initial (Logged-Out) Display | Entering A New PassKey Name |
| :-: | :-: |
|![Logged-Out Screen](00-Logged-Out.png)|![Entering a New PassKey Name](01-Enter-Register.png)|
| Figure 1 | Figure 2 |

When we started to type something into the text box, the Login button became disabled, and the Register button enabled. Once you have entered the new PassKey name, select the Register button, and you will be presented with the PassKey confirmation screen (Fig. 3). If you select "Continue," the biometrics authentication screen will display (Fig. 4).

| Confirming A New PassKey | Authenticating With Biometrics | Initial Login Screen |
| :-: | :-: | :-: |
|![Confirming A New PassKey](02-Confirm-PassKey-Create.png)|![PassKey Biometrics](03-PassKey-Create-Biometric.png)|![Initial Screen](04-Logged-In-Blank-Credo.png)|
| Figure 3 | Figure 4 | Figure 5 |

#### Read

After creating the new account, the app logs in the user, reads the user data, and presents the initial logged-in screen (Fig. 5). Note that the Display Name is the same as the one selected for the PassKey tag. This can be changed (but it cannot be blank).

An additional text box (Credo) is now shown (and is blank, at first), and the buttons change to Delete, Logout, and Update. Initially, the Update button is disabled.

#### Logging In

Once we have created one or more accounts, we can then use the PassKey[s] to log in. In the initial screen, if you select the Login Button, you will be presented with the PassKey Login Selection Screen (Fig. 6).

| Confirming A Single Login | Biometrics Authentication | After Login |
| :-: | :-: | :-: |
|![Confirming A New PassKey](13-Single_PassKey-Login-Confirm.png)|![Logged-Out Screen](14-Login-Biometrics.png)|![Logged-Out Screen](15-Successful-Login.png)|
| Figure 6 | Figure 7 | Figure 8 |

If you have registered multiple PassKeys, then the selection screen will have a list (Fig. 9). Select a PassKey, then proceed.

| Multiple Login Selection |
| :-: |
|![Multiple PassKeys](06-Multi-Login-PassKeys.png)|
| Figure 9 |

#### Update

You can change the name, or enter text into the Credo text box (Fig. 10). As soon as we start to modify the text, the Update button becomes enabled (Fig, 11). Selecting this button will immediately send the changes to the server, and the Update button becomes disabled, once more (Fig. 12).

| Initial Logged-In Screen | Entering A New Credo | Update Complete |
| :-: | :-: | :-: |
|![Initial Screen](04-Logged-In-Blank-Credo.png)|![Entering Text](08-Enter-Update.png)|![Update Complete](09-Update-Complete.png)|
| Figure 10 | Figure 11 | Figure 12 |

#### Delete

If you Select Delete, you will be asked for confirmation (Fig. 13). If you confirm, the account is deleted from the server, and you are returned to the logged-out screen (Fig. 14).

| Confirming A Delete | After Delete |
| :-: | :-: |
|![Confirming A New PassKey](05-Delete-Confirm.png)|![Logged-Out Screen](00-Logged-Out.png)|
| Figure 13 | Figure 14 |

> NOTE: The deletion removes the account from the server, and the PassKey will no longer be presented for login, but it will still exist in your Passwords Store. You will need to go in, afterwards, and delete the PassKey manually.

## SwiftUI Target Overview

This target demonstrates the application of [Apple's Expression of PassKeys](https://developer.apple.com/passkeys/), in a [SwiftUI](https://developer.apple.com/swiftui/) app.

It uses the ``PKD_Handler`` class to manage all of the communications with the server, and the application model.

The app is extremely simple. Everything is handled inside a single [View](https://developer.apple.com/documentation/swiftui/view) instance, that displays different UI sets, depending on whether or not the app is logged into the server.
