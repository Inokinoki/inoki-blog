---
title: KDE Connect iOS Develop Dairy(3) Certificate
date: 2021-02-07 14:34:50
tags:
- KDE Connect
categories:
- KDE Connect
---

As mentioned at the end of my previous post [KDE Connect iOS Develop Dairy(2) Identity Protocol](https://blog.inoki.cc/2020/04/19/KDEConnect-iOS-dev-dairy-2/), the new version KDE Connect protocol needs a TLS/SSL connection to make a completed identification. Indeed, devices use the TLS/SSL connection to communicate with each other, under secure consideration.

In such a connection with asymmetric cryptography, the most important thing is the private key, the public key exchange, and the certificate signed with each device's private key. This post describes how I added a related library (OpenSSL) and used it to generate these elements.

# Investigation

OpenSSL is a widely used library for my purpose. However, there are too many options for each entity. For the private-public key pair, there are several algorithms such as the Elliptic-Curve Digital Signature Algorithm (ECDSA), RSA, etc. What we need to use is precisely the one used by the original KDE Connect.

So, I did an investigation on the original version on [KDE Invent](https://invent.kde.org/network/kdeconnect-kde).

## Implementation in KDE Connect codebase

KDE Connect uses QCA-Qt5 (Qt Cryptographic Architecture), a Qt library providing a straightforward API.

To generate a private key (and its paired public key) with 2048 bits from the RSA algorithm, KDE Connect profits this single line:

```cpp
void KdeConnectConfig::generatePrivateKey(const QString& keyPath)
{
    // ...
    d->m_privateKey = QCA::KeyGenerator().createRSA(2048);
    // ...
}
```

Then, the generated private key is stored in `m_privateKey` field.

To generate a certificate, KDE Connect uses this method:

```cpp
void KdeConnectConfig::generateCertificate(const QString& certPath)
{
    // ...
    QString uuid = QUuid::createUuid().toString();
    DBusHelper::filterNonExportableCharacters(uuid);
    qCDebug(KDECONNECT_CORE) << "My id:" << uuid;

    // FIXME: We only use QCA here to generate the cert and key, would be nice to get rid of it completely.
    // The same thing we are doing with QCA could be done invoking openssl (although it's potentially less portable):
    // openssl req -new -x509 -sha256 -newkey rsa:2048 -nodes -keyout privateKey.pem -days 3650 -out certificate.pem -subj "/O=KDE/OU=KDE Connect/CN=_e6e29ad4_2b31_4b6d_8f7a_9872dbaa9095_"

    QCA::CertificateOptions certificateOptions = QCA::CertificateOptions();
    QDateTime startTime = QDateTime::currentDateTime().addYears(-1);
    QDateTime endTime = startTime.addYears(10);
    QCA::CertificateInfo certificateInfo;
    certificateInfo.insert(QCA::CommonName, uuid);
    certificateInfo.insert(QCA::Organization,QStringLiteral("KDE"));
    certificateInfo.insert(QCA::OrganizationalUnit,QStringLiteral("Kde connect"));
    certificateOptions.setInfo(certificateInfo);
    certificateOptions.setFormat(QCA::PKCS10);
    certificateOptions.setSerialNumber(QCA::BigInteger(10));
    certificateOptions.setValidityPeriod(startTime, endTime);

    d->m_certificate = QSslCertificate(QCA::Certificate(certificateOptions, d->m_privateKey).toPEM().toLatin1());
    // ...
}
```

TL;DR, KDE Connect gets a UUID of the current device, use it as `Common Name(CN)` to generate a certificate with `PKCS10`; the certificate is valid from one year before to ten years later; there are 2 other fields: `Orgnization(O)` set to `KDE` and `Organization Unit(OU)` set to `Kde connect. Finally, KDE Connect uses the private key to sign the certificate (we can call it self-sign, because there is no authority).

We can see that the `QCA::Certificate` constructor is in charge of all of them. Unfortunately, on iOS, it is not so easy to find an all-in-one solution. I needed to find out how it is done in detail.

```cpp
Certificate::Certificate(const CertificateOptions &opts, const PrivateKey &key, const QString &provider)
:d(new Private)
{
	CertContext *c = static_cast<CertContext *>(getContext(QStringLiteral("cert"), provider));
	if(c->createSelfSigned(opts, *(static_cast<const PKeyContext *>(key.context()))))
		change(c);
	else
		delete c;
}
```

In the constructor, we can see that a `cert` context is got, and used to create a self-signed certificate.

The method is declared here:

```cpp
class QCA_EXPORT CertContext : public CertBase
{
	Q_OBJECT
public:
	/**
	   Standard constructor

	   \param p the provider associated with this context
	*/
	CertContext(Provider *p) : CertBase(p, QStringLiteral("cert")) {}

	/**
	   Create a self-signed certificate based on the given options and
	   private key.  Returns true if successful, otherwise false.

	   If successful, this object becomes the self-signed certificate.
	   If unsuccessful, this object is considered to be in an
	   uninitialized state.

	   \param opts the options to set on the certificate
	   \param priv the key to be used to sign the certificate 
	*/
	virtual bool createSelfSigned(const CertificateOptions &opts, const PKeyContext &priv) = 0;

```

and implemented here:

```cpp
class MyCertContext : public CertContext
{
    Q_OBJECT
public:
	bool createSelfSigned(const CertificateOptions &opts, const PKeyContext &priv) override
	{
		_props = CertContextProps();
		item.reset();

		CertificateInfo info = opts.info();

		// Note: removing default constraints, let the app choose these if it wants
		Constraints constraints = opts.constraints();
		// constraints - logic from Botan
		/*Constraints constraints;
		if(opts.isCA())
		{
			constraints += KeyCertificateSign;
			constraints += CRLSign;
		}
		else
			constraints = find_constraints(priv, opts.constraints());*/

		EVP_PKEY *pk = static_cast<const MyPKeyContext *>(&priv)->get_pkey();
		X509_EXTENSION *ex;

		const EVP_MD *md;
		if(priv.key()->type() == PKey::RSA)
			md = EVP_sha1();
		else if(priv.key()->type() == PKey::DSA)
			md = EVP_sha1();
		else
			return false;

		// create
		X509 *x = X509_new();
		X509_set_version(x, 2);

		// serial
		BIGNUM *bn = bi2bn(opts.serialNumber());
		BN_to_ASN1_INTEGER(bn, X509_get_serialNumber(x));
		BN_free(bn);

		// validity period
		ASN1_TIME_set(X509_get_notBefore(x), opts.notValidBefore().toTime_t());
		ASN1_TIME_set(X509_get_notAfter(x), opts.notValidAfter().toTime_t());

		// public key
		X509_set_pubkey(x, pk);

		// subject
		X509_NAME *name = new_cert_name(info);
		X509_set_subject_name(x, name);

		// issuer == subject
		X509_set_issuer_name(x, name);

		// subject key id
		ex = new_subject_key_id(x);
		{
			X509_add_ext(x, ex, -1);
			X509_EXTENSION_free(ex);
		}

		// CA mode
		ex = new_basic_constraints(opts.isCA(), opts.pathLimit());
		if(ex)
		{
			X509_add_ext(x, ex, -1);
			X509_EXTENSION_free(ex);
		}

		// subject alt name
		ex = new_cert_subject_alt_name(info);
		if(ex)
		{
			X509_add_ext(x, ex, -1);
			X509_EXTENSION_free(ex);
		}

		// key usage
		ex = new_cert_key_usage(constraints);
		if(ex)
		{
			X509_add_ext(x, ex, -1);
			X509_EXTENSION_free(ex);
		}

		// extended key usage
		ex = new_cert_ext_key_usage(constraints);
		if(ex)
		{
			X509_add_ext(x, ex, -1);
			X509_EXTENSION_free(ex);
		}

		// policies
		ex = new_cert_policies(opts.policies());
		if(ex)
		{
			X509_add_ext(x, ex, -1);
			X509_EXTENSION_free(ex);
		}

		// finished
		X509_sign(x, pk, md);

		item.cert = x;
		make_props();
		return true;
	}
```

I could use this as a reference to implement the generation of the private key and the certificate.

# Implementation on iOS

The next step is to generate a certificate and load it on iOS, to test.

## Generate and store self-signed certificate on iOS

I tried several times and several ways, because there were many difficulties. They are noted here. Hope these can help.

## First generation with OpenSSL cli

To make an easy start, I tried to generate a private key and a certificate using OpenSSL. The equivalent command is listed in the comment:

```
openssl req -new -x509 -sha256 -newkey rsa:2048 -nodes -keyout privateKey.pem -days 3650 -out certificate.pem -subj "/O=KDE/OU=KDE Connect/CN=_e6e29ad4_2b31_4b6d_8f7a_9872dbaa9095_"
```

After this, I have a `privateKey.pem` and a `certificate.pem`.

## Load self-signed certificate on iOS

I tried to separetly load the key and the certificate on iOS, but I did not find a proper API to do so.

In a secure connection on iOS, the type needed is `SecIdentityRef`. However, there is [an API to do so](https://developer.apple.com/documentation/security/1395728-secitemimport?language=objc):

```objective-c
OSStatus SecItemImport(CFDataRef importedData, CFStringRef fileNameOrExtension, SecExternalFormat *inputFormat, SecExternalItemType *itemType, SecItemImportExportFlags flags, const SecItemImportExportKeyParameters *keyParams, SecKeychainRef importKeychain, CFArrayRef  _Nullable *outItems);
```

only for macOS 10.7+, **but not for iOS**.

There is [another one](https://developer.apple.com/documentation/security/1396915-secpkcs12import?language=objc):

```objective-c
OSStatus SecPKCS12Import(CFDataRef pkcs12_data, CFDictionaryRef options, CFArrayRef  _Nullable *items);
```

to import both the private key and the certificate at the same time. But it only accepts the data from a `p12` file.

So, finally, I sumed the private key and the certificate into a `p12` file. And the loading method is like:

```objective-c
- (void) loadSecIdentity
{
    BOOL needGenerateCertificate = NO;

    NSString *resourcePath = NULL;
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    for (NSString *directory in documentDirectories) {
        NSLog(@"Find %@", directory);
        resourcePath = [directory stringByAppendingString:@"/rsaPrivate.p12"];
    }

    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (resourcePath != NULL && [fileManager fileExistsAtPath:resourcePath]) {
        NSData *p12Data = [NSData dataWithContentsOfFile:resourcePath];

        NSMutableDictionary * options = [[NSMutableDictionary alloc] init];
        [options setObject:@"" forKey:(id)kSecImportExportPassphrase];  // No password

        CFArrayRef items = CFArrayCreate(NULL, 0, 0, NULL);
        OSStatus securityError = SecPKCS12Import((CFDataRef) p12Data,
                                                 (CFDictionaryRef)options, &items);
        SecIdentityRef identityApp;
        if (securityError == noErr && CFArrayGetCount(items) > 0) {
            SecKeyRef privateKeyRef = NULL;
            CFDictionaryRef identityDict = CFArrayGetValueAtIndex(items, 0);

            identityApp = (SecIdentityRef)CFDictionaryGetValue(identityDict,
                                                               kSecImportItemIdentity);

            securityError = SecIdentityCopyPrivateKey(identityApp, &privateKeyRef);
            if (securityError != noErr) {
                // Fail to retrieve private key from the .p12 file
                needGenerateCertificate = YES;
            } else {
                _identity = identityApp;
                NSLog(@"Certificate loaded successfully from %@", resourcePath);
            }
        } else {
            // Not valid component in the .p12 file
            needGenerateCertificate = YES;
        }
    } else {
        // No .p12 file
        needGenerateCertificate = YES;
    }
    
    if (needGenerateCertificate) {
        // generate certificate
        NSLog(@"Need generate certificate");
        [self generateAndLoadSecIdentity];
    }
}
```

The `p12` file is still available [in the project](https://github.com/Inokinoki/kdeconnect-ios/blob/master/rsaPrivate.p12), and should be removed soon.

## Attemption on generation with OpenSSL-Universal

I tried to use [OpenSSL-Universal](https://github.com/cute/OpenSSL-Universal) by adding:

```ruby
pod 'OpenSSL-Universal'
```

But it does not work, in both meanings:

- the generated certificate cannot be correctly loaded;
- there is an error indicating the missing bitcode on Xcode 11.3.1 and on a real iPhone.

## Success generation

After searching, I choose to use:

```ruby
pod 'openssl-ios-bitcode'
```

The final generation method is as follow:

```objective-c
- (void) generateSecIdentity
{
    // generate private key
    EVP_PKEY * pkey;
    pkey = EVP_PKEY_new();

    RSA * rsa;
    rsa = RSA_generate_key(
            2048,   /* number of bits for the key - 2048 is a sensible value */
            RSA_F4, /* exponent - RSA_F4 is defined as 0x10001L */
            NULL,   /* callback - can be NULL if we aren't displaying progress */
            NULL    /* callback argument - not needed in this case */
    );
    EVP_PKEY_assign_RSA(pkey, rsa);

    // generate cert
    X509 *x509;
    x509 = X509_new();

    ASN1_INTEGER_set(X509_get_serialNumber(x509), 10);

    X509_gmtime_adj(X509_get_notBefore(x509), 0);
    X509_gmtime_adj(X509_get_notAfter(x509), 31536000L);

    X509_set_pubkey(x509, pkey);

    X509_NAME *name;
    name = X509_get_subject_name(x509);

    X509_NAME_add_entry_by_txt(name, "OU", MBSTRING_ASC,    // OU = organisational unit
            (unsigned char *)"Kde connect", -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, "O",  MBSTRING_ASC,    // O = organization
            (unsigned char *)"KDE", -1, -1, 0);
    X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_ASC,    // CN = common name, TODO: uuid
            (unsigned char *)[[NetworkPackage getUUID] UTF8String], -1, -1, 0);

    X509_set_issuer_name(x509, name);
    
    if (!X509_sign(x509, pkey, EVP_md5())) {
        @throw [[NSException alloc] initWithName:@"Fail sign cert" reason:@"Error" userInfo:nil];
    }

    if (!X509_check_private_key(x509, pkey)) {
        @throw [[NSException alloc] initWithName:@"Fail validate cert" reason:@"Error" userInfo:nil];
    }

    // load algo and encryption components
    SSLeay_add_all_algorithms();
    ERR_load_crypto_strings();

    // create p12 format data
    PKCS12 *p12 = NULL;
    p12 = PKCS12_create(/* password */ "", /* name */ "KDE Connect", pkey, x509,
                        /* ca */ NULL, /* nid_key */ 0, /* nid_cert */ 0,
                        /* iter */ 0, /* mac_iter */ PKCS12_DEFAULT_ITER, /* keytype */ 0);
    if(!p12) {
        @throw [[NSException alloc] initWithName:@"Fail getP12File" reason:@"Error creating PKCS#12 structure" userInfo:nil];
    }

    // write into `Documents/rsaPrivate.p12`
    NSArray *documentDirectories = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *p12FilePath = NULL;
    for (NSString *directory in documentDirectories) {
        NSLog(@"Find %@", directory);
        p12FilePath = [directory stringByAppendingString:@"/rsaPrivate.p12"];
    }
    if (![[NSFileManager defaultManager] createFileAtPath:p12FilePath contents:nil attributes:nil])
    {
        NSLog(@"Error creating file for P12");
        @throw [[NSException alloc] initWithName:@"Fail getP12File" reason:@"Fail Error creating file for P12" userInfo:nil];
    }

    // get a FILE struct for the P12 file
    NSFileHandle *outputFileHandle = [NSFileHandle fileHandleForWritingAtPath:p12FilePath];
    FILE *p12File = fdopen([outputFileHandle fileDescriptor], "w");

    i2d_PKCS12_fp(p12File, p12);
    PKCS12_free(p12);
    fclose(p12File);
    [outputFileHandle closeFile];
}
```

# Conclusion

In this post, I described, in general, how I generate and load the private key and certificate in KDE Connect iOS. This aims at preparing a TLS/SSL connection between an iOS device and a device using the current version of KDE Connect.

In the next post, I will tell the TLS/SSL transport in KDE Connect iOS. Thanks for reading!
