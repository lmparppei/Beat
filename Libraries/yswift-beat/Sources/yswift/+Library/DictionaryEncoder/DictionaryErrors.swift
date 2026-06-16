import Foundation

extension DecodingError {
    static func _typeMismatch(at path: [CodingKey], expectation: Any.Type, reality: Any?) -> DecodingError {
        let description = "Expected to decode \(expectation) but found \(_typeDescription(of: reality)) instead."
        return .typeMismatch(expectation, Context(codingPath: path, debugDescription: description))
    }

    static func _typeDescription(of value: Any?) -> String {
        if value == nil { return "nil" }
        if value is NSNull {
            return "a null value"
        } else if value is NSNumber {
            return "a number"
        } else if value is String {
            return "a string/data"
        } else if value is [Any] {
            return "an array"
        } else if value is [String : Any] {
            return "a dictionary"
        } else {
            return "\(type(of: value))"
        }
    }
}
