import Foundation
import PackagePlugin

@main
struct ExplicitDependencyImportCheckPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: any Target) async throws -> [Command] {
        let targetDependencies = findSpmTargetDependencies(fromTarget: target)
        let importsInCode = try findImportsUsedInCode(context: context, path: target.directory.string)
        let transitiveDependencies = findTransitiveDependencies(imports: importsInCode, targetDependencies: targetDependencies)
        let unusedTargetDependencies = findUnusedTargetDependencies(imports: importsInCode, targetDependencies: targetDependencies)

        return (try exportTransitiveDependenciesAsErrors(
                   transitiveDeps: transitiveDependencies,
                   forTarget: target,
                   inContext: context
                )) +
                (try exportUnusedDependenciesAsWarnings(
                   unusedDependencies: unusedTargetDependencies,
                   forTarget: target,
                   inContext: context
                ))
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
    /// This function exports the transitive dependencies to Xcode as an error.
    func exportTransitiveDependenciesAsErrors(
        transitiveDeps: Set<String>,
        forTarget target: Target,
        inContext context: PluginContext
    ) throws -> [Command] {
        guard !transitiveDeps.isEmpty else { return [] }

        var transitiveDependenciesErrorText = "warning: \(transitiveDeps.count) Transitive dependencies found for \(target.name) 🚨🚨🚨\n"
        transitiveDependenciesErrorText += transitiveDeps.map { "👉 \($0) is a transitive dependency" }
                                                         .joined(separator: "\n")

        let echoTool = try context.tool(named: "echo")
        return [.buildCommand(
            displayName: "Transitive Dependencies Report",
            executable: echoTool.path,
            arguments: [transitiveDependenciesErrorText],
            environment: [:]
       )]
    }

    func exportUnusedDependenciesAsWarnings(
        unusedDependencies: Set<String>,
        forTarget target: Target,
        inContext context: PluginContext
    ) throws -> [Command] {
        guard !unusedDependencies.isEmpty else { return [] }

        var warningText = "warning: \(unusedDependencies.count) Extraneous dependencies found for \(target.name) ⚠️⚠️\n"
        warningText += unusedDependencies.map { "👉 \($0) is an extraneous dependency" }
                                         .joined(separator: "\n")

        let echoTool = try context.tool(named: "echo")
        return [.buildCommand(
            displayName: "Extraneous Dependencies Report",
            executable: echoTool.path,
            arguments: [warningText],
            environment: [:]
        )]
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
