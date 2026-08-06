import Foundation
import PackagePlugin

@main
struct ExplicitDependencyImportCheckPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: any Target) async throws -> [Command] {
        let configuration = try PluginConfiguration.load(from: context)
        let targetDependencies = findSpmTargetDependencies(fromTarget: target)
        let importsInCode = try findImportsUsedInCode(context: context, path: target.directory.string)
        let transitiveDependencies = findTransitiveDependencies(imports: importsInCode, targetDependencies: targetDependencies)
        let unusedTargetDependencies = findUnusedTargetDependencies(imports: importsInCode, targetDependencies: targetDependencies)

        exportTransitiveDependencies(
            transitiveDeps: transitiveDependencies,
            severity: configuration.transitiveDependencySeverity,
            forTarget: target
        )
        exportUnusedDependencies(
            unusedDependencies: unusedTargetDependencies,
            severity: configuration.unusedDependencySeverity,
            forTarget: target
        )

        return []
    }

    func findTransitiveDependencies(imports: Set<String>, targetDependencies: Set<String>) -> Set<String> {
        return imports.subtracting(targetDependencies)
                      .subtracting(systemLibraries)
    }

    func findUnusedTargetDependencies(imports: Set<String>, targetDependencies: Set<String>) -> Set<String> {
        return targetDependencies.subtracting(imports)
    }
}

extension ExplicitDependencyImportCheckPlugin {
    /// This function exports the transitive dependencies to Xcode.
    func exportTransitiveDependencies(
        transitiveDeps: Set<String>,
        severity: DiagnosticSeverity,
        forTarget target: Target
    ) {
        guard !transitiveDeps.isEmpty else { return }

        var message = "\(transitiveDeps.count) transitive dependencies found for \(target.name):\n"
        message += transitiveDeps
            .sorted()
            .map { "\($0) is a transitive dependency" }
            .joined(separator: "\n")

        severity.emit(message)
    }

    func exportUnusedDependencies(
        unusedDependencies: Set<String>,
        severity: DiagnosticSeverity,
        forTarget target: Target
    ) {
        guard !unusedDependencies.isEmpty else { return }

        var message = "\(unusedDependencies.count) extraneous dependencies found for \(target.name):\n"
        message += unusedDependencies
            .sorted()
            .map { "\($0) is an extraneous dependency" }
            .joined(separator: "\n")

        severity.emit(message)
    }
}

extension ExplicitDependencyImportCheckPlugin {
    /// This function is finding the import statements in sourcecode.
    func findImportsUsedInCode(context: PluginContext, path: String) throws -> Set<String> {
        let sitrepTool = try context.tool(named: "sitrep")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: sitrepTool.path.string)
        process.arguments = [
            "-p",
            path,
            "-f",
            "json"
        ]
        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        try process.run()
        process.waitUntilExit()
        let jsonDecoder = JSONDecoder()
        guard let dataFromOutputPipe = try outputPipe.fileHandleForReading.readToEnd() else {
            throw ErrorFindImportsUsedInCode.readingResponseError
        }
        let sitrepResponse = try jsonDecoder.decode(SitrepResponse.self, from: dataFromOutputPipe)
        
        let rawDependencies = sitrepResponse.imports
            .compactMap { $0.targetName.split(separator: ".").first?.trimmingCharacters(in: .whitespaces) } // Work with alternative importing style ```import stuct Foo.Bar```
            .map { String($0)}
        return Set(rawDependencies)
    }
}

extension ExplicitDependencyImportCheckPlugin {
    /// This function finds all the dependencies a SPM target has.
    func findSpmTargetDependencies(fromTarget target: Target) -> Set<String> {
        let dependencies = target.dependencies.compactMap { dependency in
            switch dependency {
            case .product(let product):
                return product.name
            case .target(let target):
                return target.name
            default:
                return nil
            }
        }
        return Set(dependencies)
    }
}

enum ErrorFindImportsUsedInCode: Error {
    case readingResponseError
}
