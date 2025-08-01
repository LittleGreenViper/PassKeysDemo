/*
    © Copyright 2025, Little Green Viper Software Development LLC

    LICENSE:

    MIT License

    Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation
    files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,
    modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the
    Software is furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
    OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
    CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation

/* ###################################################################################################################################### */
// MARK: - String Extension -
/* ###################################################################################################################################### */
extension String {
    /* ###################################################################### */
    /**
     This treats the string as Base64 URL-encoded, and returns a Data instance that represents the encoded contents.
     */
    var base64urlDecodedData: Data? {
        var base64 = self
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let paddingLength = 4 - (base64.count % 4)
        if paddingLength < 4 {
            base64 += String(repeating: "=", count: paddingLength)
        }
        return Data(base64Encoded: base64)
    }
}

/* ###################################################################################################################################### */
// MARK: - Bundle Extension -
/* ###################################################################################################################################### */
/**
 This extension adds a few simple accessors for some of the more common bundle items.
 */
public extension Bundle {
    /* ################################################################## */
    /**
     This returns the bundle-provided relying party string.
     */
    var defaultRelyingPartyString: String { object(forInfoDictionaryKey: "PKDDefaultRelyingParty") as? String ?? "" }
    
    /* ################################################################## */
    /**
     This returns the bundle-provided base URL string.
     */
    var defaultBaseURIString: String { object(forInfoDictionaryKey: "PKDDefaultBaseURI") as? String ?? "" }
    
    /* ################################################################## */
    /**
     This returns the bundle-provided default user ID string.
     */
    var defaultUserIDString: String { object(forInfoDictionaryKey: "PKDDefaultUserID") as? String ?? "" }
    
    /* ################################################################## */
    /**
     This returns the bundle-provided default display name string.
     */
    var defaultUserNameString: String { object(forInfoDictionaryKey: "PKDDefaultUserName") as? String ?? "" }
}
