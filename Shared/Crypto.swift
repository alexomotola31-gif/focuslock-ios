import Foundation
import CommonCrypto

/// PBKDF2-SHA256 hashing. Emergency codes are never stored in plaintext.
enum PBKDF2 {
    static func randomSalt(length: Int = 16) -> Data {
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytes(kSecRandomDefault, length, &bytes)
        return Data(bytes)
    }

    static func hash(pin: String, salt: Data, rounds: UInt32 = 120_000, length: Int = 32) -> Data {
        let passwordData = Data(pin.utf8)
        var derivedData = Data(repeating: 0, count: length)
        _ = derivedData.withUnsafeMutableBytes { derivedPtr -> Int32 in
            salt.withUnsafeBytes { saltPtr -> Int32 in
                passwordData.withUnsafeBytes { passwordPtr -> Int32 in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPtr.bindMemory(to: Int8.self).baseAddress,
                        passwordData.count,
                        saltPtr.bindMemory(to: UInt8.self).baseAddress,
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        rounds,
                        derivedPtr.bindMemory(to: UInt8.self).baseAddress,
                        length
                    )
                }
            }
        }
        return derivedData
    }

    static func constantTimeEqual(_ a: Data, _ b: Data) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for (x, y) in zip(a, b) { diff |= x ^ y }
        return diff == 0
    }

    /// A fresh random 6-digit code.
    static func randomCode() -> String {
        var value: UInt32 = 0
        _ = withUnsafeMutableBytes(of: &value) { SecRandomCopyBytes(kSecRandomDefault, 4, $0.baseAddress!) }
        return String(format: "%06d", Int(value % 1_000_000))
    }
}
