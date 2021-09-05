---
title: The right way to store and retrieve SecIdentity/Identity on iOS
date: 2021-09-05 09:42:00
tags:
- iOS
categories:
- iOS
---

Apple does have a [documentation](https://developer.apple.com/documentation/security/certificate_key_and_trust_services/identities/storing_an_identity_in_the_keychain?language=objc) describing how to store an identity in the keychain. In this doc, it is described as a process much like the storage of certificate in the keychain. The only difference is:

- Use `SecIdentityRef` objects instead of `SecCertificateRef` objects.
- Use `kSecClassIdentity` instead of `kSecClassCertificate` for the `kSecClass` attribute.

So, the code of storing an Identity becomes:

```objective-c
NSDictionary* addquery = @{ (id)kSecValueRef:   (__bridge id)identity,
                            (id)kSecClass:      (id)kSecClassIdentity,
                            (id)kSecAttrLabel:  @"Identity",
                           };

OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addquery, NULL);
if (status != errSecSuccess) {
    // Handle the error
}
```

and retrieving as follows:

```objective-c
NSDictionary *getquery = @{ (id)kSecClass:     (id)kSecClassIdentity,
                            (id)kSecAttrLabel: @"Identity",
                            (id)kSecReturnRef: @YES,
                            };

SecIdentityRef identity = NULL;
OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)getquery,
                                      (CFTypeRef *)&identity);
if (status != errSecSuccess) { <# Handle error #> }
else                         { <# Use identity #> }

if (identity) { CFRelease(identity); } // After you are done with it
```

# Problem

However, on the iOS 14.5 emulator, although `SecItemAdd` returns 0 with no error, there is no identity stored:

```
Identity Test[2377:102582] Internet Password: (null)
Identity Test[2377:102582] Cert: (null)
Identity Test[2377:102582] Key: (null)
Identity Test[2377:102582] Identity: (null)
```

It is very weird...

# Solution

I searched on Internet. This thread helps me a little: [I can't get SecIdentity from Keychain](https://developer.apple.com/forums/thread/98029):

```
Using labels on an identity is tricky because identities are not stored in the keychain as an atomic item but are store as a separate private key and certificate, and those items use labels in different ways.
```

It inspired me to remove the `kSecClass` when storing. The code becomes:

```objective-c
NSDictionary* addquery = @{ (id)kSecValueRef:   (__bridge id)identity,
                            (id)kSecAttrLabel:  @"Identity",
                           };

OSStatus status = SecItemAdd((__bridge CFDictionaryRef)addquery, NULL);
if (status != errSecSuccess) {
    // Handle the error
}
```

With these lines of code, when querying, KeyChains gives me:

```
Identity Test[2555:109912] Internet Password: (null)
Identity Test[2555:109912] Cert: (
        {
        ...
        labl = Identity;
        ...
    }
)
Identity Test[2555:109912] Key: (
        {
        ...
        labl = Identity;
        ...
    }
)
Identity Test[2555:109912] Identity: (
        {
        ...
        labl = Identity;
        ...
    }
)
```

There are a private key, a certificate and an identity with my label. It works now :)

When retrieving, we can still keep the `kSecClass` in the query to filter the identity only.

Regarding that these are not mentioned by Apple at all, I hope this workaround can help someone.

# Unique Identity issue

Then, I tried to store a second identity(labelled by `Identity1`) with the workaround. But it fails with the same observation above.

So, I add some code to remove the previous identity before adding new:

```objective-c
NSDictionary *spec = @{(__bridge id)kSecClass: (id)kSecClassIdentity};
SecItemDelete((__bridge CFDictionaryRef)spec);
```

This will remove the corresponding private key, certificate and the identity itself. And the new identity can be added successfully.

Thus, I wonder if the removal of the private key or the certificate will affect the identity? Here are the answers:

|  kSecClass  |  Certificate removed  |  Private key removed |  Identity removed  | Identity can be added  |
|-------------|-----------------------|----------------------|--------------------|------------------------|
| kSecClassCertificate  |  YES  |  NO   |  YES  |  YES  |
| kSecClassKey          |  NO   |  YES  |  YES  |  NO   |
| kSecClassIdentity     |  YES  |  YES  |  YES  |  YES  |

We can see that, removing both certificate or identity should work.

In my case, I need to store some more certificates other than the one from the identity. So, I should not remove all the certificates. I choose to remove the identity to keep atmost one at the same time. You could also do your own choice.

# Conclusion

This post explores the Identity storage on iOS. Here are my discovery:

- do not store the identity with `kSecClass`, the KeyChain service will do this for you;
- only one identity is OK for an app.

Any other questions? Post them in the comments.
