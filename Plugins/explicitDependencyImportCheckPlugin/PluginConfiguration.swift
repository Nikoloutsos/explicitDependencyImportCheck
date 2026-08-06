import Foundation
import PackagePlugin

struct PluginConfiguration {
    var transitiveDependencySeverity: DiagnosticSeverity = .error
    var unusedDependencySeverity: DiagnosticSeverity = .warning

    static func load(from context: PluginContext) throws -> PluginConfiguration {
        let configPath = [
            ".explicit-dependency-import-check.yml",
            ".explicit-dependency-import-check.yaml"
        ]
        .map { context.package.directory.appending($0).string }
        .first { FileManager.default.fileExists(atPath: $0) }

        guard let configPath = configPath else {
            return PluginConfiguration()
        }

        let contents = try String(contentsOfFile: configPath, encoding: .utf8)
        return try PluginConfiguration(contents: contents, path: configPath)
    }

    init() {}

    init(contents: String, path: String) throws {
        self.init()

        for (lineIndex, line) in contents.components(separatedBy: "\n").enumerated() {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !trimmedLine.isEmpty, !trimmedLine.hasPrefix("#") else {
                continue
            }

            let parts = trimmedLine.split(separator: ":", maxSplits: 1).map {
                $0.trimmingCharacters(in: .whitespaces)
            }

            guard parts.count == 2 else {
                throw PluginConfigurationError.invalidLine(path: path, line: lineIndex + 1)
            }

            let key = parts[0]
            let rawValue = parts[1].split(separator: "#", maxSplits: 1).first?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                ?? ""

            guard let severity = DiagnosticSeverity(rawValue: rawValue) else {
                throw PluginConfigurationError.invalidSeverity(
                    path: path,
                    line: lineIndex + 1,
                    value: rawValue
                )
            }

            switch key {
            case "transitiveDependencySeverity":
                transitiveDependencySeverity = severity
            case "unusedDependencySeverity":
                unusedDependencySeverity = severity
            default:
                throw PluginConfigurationError.unknownKey(
                    path: path,
                    line: lineIndex + 1,
                    key: key
                )
            }
        }
    }
}

enum DiagnosticSeverity: String {
    case error
    case warning
    case ignore

    func emit(_ message: String) {
        switch self {
        case .error:
            Diagnostics.error(message)
        case .warning:
            Diagnostics.warning(message)
        case .ignore:
            break
        }
    }
}

enum PluginConfigurationError: Error, CustomStringConvertible, LocalizedError {
    case invalidLine(path: String, line: Int)
    case invalidSeverity(path: String, line: Int, value: String)
    case unknownKey(path: String, line: Int, key: String)

    var description: String {
        switch self {
        case let .invalidLine(path, line):
            return "\(path):\(line): expected `key: value`."
        case let .invalidSeverity(path, line, value):
            return "\(path):\(line): invalid severity `\(value)`. Expected `error`, `warning`, or `ignore`."
        case let .unknownKey(path, line, key):
            return "\(path):\(line): unknown configuration key `\(key)`."
        }
    }

    var errorDescription: String? {
        description
    }
}
