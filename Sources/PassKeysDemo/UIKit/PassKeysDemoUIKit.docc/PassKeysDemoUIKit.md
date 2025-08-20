# ``PassKeysDemoUIKit``

Demonstration of iOS PassKeys in Swift, implemented into a UIKit target.

## Overview
![Icon](Icon.png)

This target demonstrates the application of [Apple's Expression of PassKeys](https://developer.apple.com/passkeys/), in a [UIKit (Storyboard)](https://developer.apple.com/documentation/uikit/) app.

It uses the ``PKD_Handler`` class to manage all of the communications with the server, and the application model.

The app is extremely simple. Everything is handled inside a single [`UIViewController`](https://developer.apple.com/documentation/uikit/uiviewcontroller) instance, that displays different UI sets, depending on whether or not the app is logged into the server.
