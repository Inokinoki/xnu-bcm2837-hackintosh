# Building Security Framework for ARM64

The Security framework provides cryptographic services, secure storage, and authentication for Darwin/macOS.

## Overview

The Security framework provides:

- **Keychain Services** - Secure credential storage
- **Certificate/Key/Trust Services** - PKI operations
- **Cryptographic Services** - Encryption/decryption
- **Secure Transport** - TLS/SSL implementation
- **Authorization Services** - Access control
- **Code Signing** - Application signing/verification

## Components

| Component | Description |
|-----------|-------------|
| `Security.framework` | Main framework |
| `securityd` | Security daemon |
| `security` | Command-line tool |
| `codesign` | Code signing utility |
| `csreq` | Code signing requirements |

## Source

Download from Apple Open Source:
- **URL**: https://opensource.apple.com/source/Security/
- **Recommended Version**: Security-59754.140.13 or latest

```bash
curl -O https://opensource.apple.com/tarballs/Security/Security-59754.140.13.tar.gz
tar xzf Security-59754.140.13.tar.gz
cd Security-59754.140.13
```

## Dependencies

| Dependency | Purpose | Required |
|------------|---------|----------|
| [Libc](Libc.md) | C standard library | ✅ Yes |
| [CoreFoundation](CoreFoundation.md) | Core types | ✅ Yes |
| [libdispatch](libdispatch.md) | Async operations | ✅ Yes |
| CommonCrypto | Cryptographic primitives | ✅ Yes |
| sqlite | Keychain database | ✅ Yes |
| [libxpc](libxpc.md) | IPC with securityd | ✅ Yes |

## Project Structure

```
Security/
├── OSX/
│   ├── libsecurity_keychain/    # Keychain implementation
│   ├── libsecurity_ssl/         # SSL/TLS
│   ├── libsecurity_utilities/   # Utility functions
│   ├── libsecurity_codesigning/ # Code signing
│   └── sec/                     # Command-line tool
├── securityd/
│   └── src/                     # Security daemon
├── keychain/
│   └── ...                      # Keychain services
└── certificates/
    └── ...                      # Certificate handling
```

## Build Instructions

### Using Xcode

```bash
xcodebuild -project Security.xcodeproj \
    -scheme Security \
    -configuration Release \
    ARCHS=arm64 \
    SDKROOT=macosx
```

### Key Libraries

The Security framework consists of multiple libraries:

```bash
# Build individual components
xcodebuild -target libsecurity_keychain
xcodebuild -target libsecurity_ssl
xcodebuild -target libsecurity_codesigning
xcodebuild -target securityd
xcodebuild -target security  # CLI tool
```

## Security Tool Usage

### Keychain Operations

```bash
# List keychains
security list-keychains

# Create keychain
security create-keychain -p password mykeychain.keychain

# Add password
security add-generic-password -a account -s service -w password

# Find password
security find-generic-password -a account -s service -w

# Import certificate
security import cert.pem -k login.keychain
```

### Certificate Operations

```bash
# Show certificate info
security verify-cert -c cert.pem

# Find certificates
security find-certificate -a

# Export certificate
security export -t certs -o output.pem
```

### Code Signing

```bash
# Sign application
codesign -s "Developer ID" MyApp.app

# Verify signature
codesign -v MyApp.app

# Display signature info
codesign -d -v MyApp.app
```

## API Examples

### Keychain Access

```c
#include <Security/Security.h>

// Add password to keychain
OSStatus status = SecKeychainAddGenericPassword(
    NULL,                           // default keychain
    strlen("myservice"), "myservice",
    strlen("myaccount"), "myaccount",
    strlen("mypassword"), "mypassword",
    NULL                            // item reference
);

// Find password
void *passwordData;
UInt32 passwordLength;
status = SecKeychainFindGenericPassword(
    NULL,
    strlen("myservice"), "myservice",
    strlen("myaccount"), "myaccount",
    &passwordLength, &passwordData,
    NULL
);
```

### Certificate Verification

```c
#include <Security/Security.h>

SecCertificateRef cert = SecCertificateCreateWithData(NULL, certData);
SecPolicyRef policy = SecPolicyCreateBasicX509();
SecTrustRef trust;

OSStatus status = SecTrustCreateWithCertificates(cert, policy, &trust);
SecTrustResultType result;
status = SecTrustEvaluate(trust, &result);

if (result == kSecTrustResultProceed || 
    result == kSecTrustResultUnspecified) {
    // Certificate is trusted
}
```

### Encryption

```c
#include <Security/Security.h>

// Generate key pair
SecKeyRef publicKey, privateKey;
CFMutableDictionaryRef attrs = CFDictionaryCreateMutable(...);
CFDictionarySetValue(attrs, kSecAttrKeyType, kSecAttrKeyTypeRSA);
CFDictionarySetValue(attrs, kSecAttrKeySizeInBits, @2048);

OSStatus status = SecKeyGeneratePair(attrs, &publicKey, &privateKey);

// Encrypt data
CFDataRef encrypted = SecKeyCreateEncryptedData(
    publicKey,
    kSecKeyAlgorithmRSAEncryptionPKCS1,
    plainData,
    NULL
);

// Decrypt data
CFDataRef decrypted = SecKeyCreateDecryptedData(
    privateKey,
    kSecKeyAlgorithmRSAEncryptionPKCS1,
    encrypted,
    NULL
);
```

## Output Files

| File | Location | Description |
|------|----------|-------------|
| `Security.framework` | `/System/Library/Frameworks/` | Main framework |
| `securityd` | `/usr/sbin/` | Security daemon |
| `security` | `/usr/bin/` | CLI tool |
| `codesign` | `/usr/bin/` | Code signing |

## securityd Integration

securityd plist:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.apple.securityd</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/sbin/securityd</string>
    </array>
    <key>MachServices</key>
    <dict>
        <key>com.apple.securityd</key>
        <true/>
    </dict>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

## Patches for ARM64

### Cryptographic optimizations

```c
#if defined(__arm64__)
// Use ARM cryptographic extensions if available
#if __ARM_FEATURE_CRYPTO
// Use hardware AES, SHA instructions
#endif
#endif
```

### Keychain location

```c
// Adjust keychain paths for embedded systems
#define SYSTEM_KEYCHAIN_PATH "/var/db/SystemKey"
#define USER_KEYCHAIN_DIR    "/var/keychains"
```

## CommonCrypto Dependency

Security framework uses CommonCrypto for primitives:

```bash
# CommonCrypto is usually part of libSystem
# Or build separately from Apple Open Source
curl -O https://opensource.apple.com/tarballs/CommonCrypto/CommonCrypto-60178.100.1.tar.gz
```

## References

- [Apple Open Source - Security](https://opensource.apple.com/source/Security/)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Certificate, Key, and Trust Services](https://developer.apple.com/documentation/security/certificate_key_and_trust_services)
- [Code Signing Guide](https://developer.apple.com/library/archive/documentation/Security/Conceptual/CodeSigningGuide/)

## Next Steps

After building Security:

1. Build CommonCrypto for crypto primitives
2. Set up securityd with launchd
3. Create initial system keychain
4. Configure code signing policies
