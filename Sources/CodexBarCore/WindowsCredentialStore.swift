import Foundation

#if os(Windows)
import WinSDK

/// Windows Credential Manager integration for secure credential storage.
///
/// Uses the Windows Credential Manager (wincred.h) APIs to securely store
/// and retrieve credentials with DPAPI protection.
public enum WindowsCredentialStore {
    private static let log = CodexBarLog.logger(LogCategories.keychainCache)
    private static let targetPrefix = "CodexBar/"

    /// Store a credential in Windows Credential Manager
    public static func store(key: String, data: Data) -> Bool {
        let targetName = "\(targetPrefix)\(key)"

        return targetName.withCString(encodedAs: UTF16.self) { targetNamePtr in
            data.withUnsafeBytes { dataPtr in
                guard let baseAddress = dataPtr.baseAddress else { return false }

                var credential = CREDENTIALW()
                credential.Type = CRED_TYPE_GENERIC
                credential.TargetName = UnsafeMutablePointer(mutating: targetNamePtr)
                credential.CredentialBlobSize = DWORD(data.count)
                credential.CredentialBlob = UnsafeMutablePointer(
                    mutating: baseAddress.assumingMemoryBound(to: UInt8.self))
                credential.Persist = CRED_PERSIST_LOCAL_MACHINE
                credential.UserName = nil

                let result = CredWriteW(&credential, 0)
                if result == 0 {
                    let error = GetLastError()
                    log.error("CredWriteW failed with error: \(error)")
                    return false
                }
                return true
            }
        }
    }

    /// Retrieve a credential from Windows Credential Manager
    public static func load(key: String) -> Data? {
        let targetName = "\(targetPrefix)\(key)"

        return targetName.withCString(encodedAs: UTF16.self) { targetNamePtr in
            var credentialPtr: PCREDENTIALW?

            let result = CredReadW(targetNamePtr, CRED_TYPE_GENERIC, 0, &credentialPtr)
            if result == 0 {
                let error = GetLastError()
                if error != ERROR_NOT_FOUND {
                    log.error("CredReadW failed with error: \(error)")
                }
                return nil
            }

            guard let credential = credentialPtr?.pointee else {
                return nil
            }

            defer {
                CredFree(credentialPtr)
            }

            guard credential.CredentialBlobSize > 0,
                  let blobPtr = credential.CredentialBlob else {
                return nil
            }

            return Data(bytes: blobPtr, count: Int(credential.CredentialBlobSize))
        }
    }

    /// Delete a credential from Windows Credential Manager
    public static func delete(key: String) -> Bool {
        let targetName = "\(targetPrefix)\(key)"

        return targetName.withCString(encodedAs: UTF16.self) { targetNamePtr in
            let result = CredDeleteW(targetNamePtr, CRED_TYPE_GENERIC, 0)
            if result == 0 {
                let error = GetLastError()
                if error != ERROR_NOT_FOUND {
                    log.error("CredDeleteW failed with error: \(error)")
                    return false
                }
            }
            return true
        }
    }

    /// List all CodexBar credentials in Windows Credential Manager
    public static func listKeys() -> [String] {
        let filter = "\(targetPrefix)*"

        return filter.withCString(encodedAs: UTF16.self) { filterPtr in
            var count: DWORD = 0
            var credentialsPtr: UnsafeMutablePointer<PCREDENTIALW>?

            let result = CredEnumerateW(filterPtr, 0, &count, &credentialsPtr)
            if result == 0 {
                return []
            }

            defer {
                CredFree(credentialsPtr)
            }

            var keys: [String] = []
            for i in 0..<Int(count) {
                if let cred = credentialsPtr?[i]?.pointee,
                   let targetName = cred.TargetName {
                    let name = String(decodingCString: targetName, as: UTF16.self)
                    if name.hasPrefix(targetPrefix) {
                        keys.append(String(name.dropFirst(targetPrefix.count)))
                    }
                }
            }

            return keys
        }
    }
}

// MARK: - DPAPI Data Protection

/// Windows Data Protection API (DPAPI) for encrypting/decrypting data.
///
/// DPAPI uses the user's credentials to derive encryption keys,
/// providing secure storage tied to the current user account.
public enum WindowsDataProtection {
    private static let log = CodexBarLog.logger(LogCategories.keychainCache)

    /// Encrypt data using DPAPI (CryptProtectData)
    public static func protect(data: Data, description: String? = nil) -> Data? {
        var dataIn = DATA_BLOB()
        var dataOut = DATA_BLOB()

        return data.withUnsafeBytes { dataPtr in
            guard let baseAddress = dataPtr.baseAddress else { return nil }

            dataIn.cbData = DWORD(data.count)
            dataIn.pbData = UnsafeMutablePointer(
                mutating: baseAddress.assumingMemoryBound(to: UInt8.self))

            let result: BOOL
            if let description = description {
                result = description.withCString(encodedAs: UTF16.self) { descPtr in
                    CryptProtectData(
                        &dataIn,
                        descPtr,
                        nil,  // optional entropy
                        nil,  // reserved
                        nil,  // prompt struct
                        CRYPTPROTECT_UI_FORBIDDEN,
                        &dataOut)
                }
            } else {
                result = CryptProtectData(
                    &dataIn,
                    nil,
                    nil,
                    nil,
                    nil,
                    CRYPTPROTECT_UI_FORBIDDEN,
                    &dataOut)
            }

            if result == 0 {
                let error = GetLastError()
                log.error("CryptProtectData failed with error: \(error)")
                return nil
            }

            defer {
                LocalFree(dataOut.pbData)
            }

            guard dataOut.cbData > 0, let outPtr = dataOut.pbData else {
                return nil
            }

            return Data(bytes: outPtr, count: Int(dataOut.cbData))
        }
    }

    /// Decrypt data using DPAPI (CryptUnprotectData)
    public static func unprotect(data: Data) -> Data? {
        var dataIn = DATA_BLOB()
        var dataOut = DATA_BLOB()

        return data.withUnsafeBytes { dataPtr in
            guard let baseAddress = dataPtr.baseAddress else { return nil }

            dataIn.cbData = DWORD(data.count)
            dataIn.pbData = UnsafeMutablePointer(
                mutating: baseAddress.assumingMemoryBound(to: UInt8.self))

            let result = CryptUnprotectData(
                &dataIn,
                nil,  // description output
                nil,  // optional entropy
                nil,  // reserved
                nil,  // prompt struct
                CRYPTPROTECT_UI_FORBIDDEN,
                &dataOut)

            if result == 0 {
                let error = GetLastError()
                log.error("CryptUnprotectData failed with error: \(error)")
                return nil
            }

            defer {
                LocalFree(dataOut.pbData)
            }

            guard dataOut.cbData > 0, let outPtr = dataOut.pbData else {
                return nil
            }

            return Data(bytes: outPtr, count: Int(dataOut.cbData))
        }
    }
}

#else

// Stub implementations for non-Windows platforms
public enum WindowsCredentialStore {
    public static func store(key: String, data: Data) -> Bool { false }
    public static func load(key: String) -> Data? { nil }
    public static func delete(key: String) -> Bool { false }
    public static func listKeys() -> [String] { [] }
}

public enum WindowsDataProtection {
    public static func protect(data: Data, description: String? = nil) -> Data? { nil }
    public static func unprotect(data: Data) -> Data? { nil }
}

#endif
