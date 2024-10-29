import Foundation
import PackagePlugin

@main
struct ExplicitDependencyImportCheckPlugin: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: any Target) async throws -> [Command] {
        let dependeniesNames = findSpmTargetDependencies(fromTarget: target)
        let sitrepResponse = try findImportsUsedInCode(context: context, path: target.directory.string)
        let transitiveDependencies = sitrepResponse.subtracting(dependeniesNames)
        let transitiveDependenciesWithoutCommon = transitiveDependencies.subtracting(commonDependencies)
        guard transitiveDependenciesWithoutCommon.isEmpty == false else { return [] }
        return [
            try exportTransitiveDependenciesAsErrors(
                transitiveDeps: transitiveDependenciesWithoutCommon,
                forTarget: target,
                inContext: context
            )
        ]
    }
}

extension ExplicitDependencyImportCheckPlugin {
    /// This function exports the transitive dependencies to Xcode as an error.
    func exportTransitiveDependenciesAsErrors(
        transitiveDeps: Set<String>,
        forTarget target: Target,
        inContext context: PluginContext
    ) throws -> Command {
        var transitiveDependenciesErrorText = "error: \(transitiveDeps.count) Transitive dependencies found for \(target.name) 🚨🚨🚨"
        for transitiveDep in transitiveDeps {
            transitiveDependenciesErrorText += "\n"
            transitiveDependenciesErrorText += "👉 \(transitiveDep) is a transitive dependency"
        }
        let echoTool = try context.tool(named: "echo")
        return .buildCommand(
            displayName: "Transitive Dependencies Report",
            executable: echoTool.path,
            arguments: [transitiveDependenciesErrorText],
            environment: [:]
       )
        
    }
}

extension ExplicitDependencyImportCheckPlugin {
    /// These should not be considered as transitive dependencies.
    var commonDependencies: Set<String> {
        Set<String>(
            [
                "Foundation",
                "UIKit",
                "SwiftUI",
                "Combine",
                "CoreData"
            ]
        )
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
            .compactMap { $0.targetName.split(separator: ".").first } // Work with alternative importing style ```import stuct Foo.Bar```
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
