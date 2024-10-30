# 📦 explicitDependencyImportCheck

**explicitDependencyImportCheck** is a Swift build plugin designed to help you enforce clean dependency management by ensuring that only explicitly declared dependencies are imported. Transitive dependencies can cause a range of problems, from bloated builds to fragile code. Swift provides the `--explicit-target-dependency-import-check` flag for this purpose, but it doesn’t work consistently with **XcodeBuild** – and that’s where this plugin steps in! 🚀

## 🌟 Features

- **No More Transitive Dependencies**: Catch unwanted transitive imports and keep your code cleaner, faster, and more modular.
- **Swift Build Plugin**: Runs automatically during the Swift build process.
- **Easy Integration**: Just add it to your project to start using!

## 🛠️ Installation

To integrate `explicitDependencyImportCheck` in your Swift project, add it to your **Package.swift**:

```swift
dependencies: [
    .package(url: "https://github.com/Nikoloutsos/explicitDependencyImportCheck", from: "1.0.0")
]
```

And make sure to include it in your targets as a plugin:

```swift
targets: [
    .target(
        name: "AppTarget",
        plugins: [
            .plugin(name: "explicitDependencyImportCheckPlugin", package: "explicitDependencyImportCheck")
        ]
    )
]
```

or put that at the end of package.swift to apply to everything:

```swift
// Add plugin on every target
for target in package.targets.filter({ $0.type != .plugin && $0.type != .binary }) {
    if target.plugins == nil {
        target.plugins = []
    }
    target.plugins?.append(.plugin(name: "explicitDependencyImportCheckPlugin", package: "explicitDependencyImportCheck"))
}
```

## 🚀 Usage
Once added, the plugin will automatically check for transitive dependencies each time your project builds. If any transitive dependencies are detected, Xcode will throw an error providing you with the transitive dependencies imported!

> Note: On your first run, you may be prompted to enable the plugin. Follow the instructions in the console to complete the setup.

## 🤝 Contributions

Contributions are more than welcome! If you’d like to improve **explicitDependencyImportCheck** or have ideas for new features, feel free to open an issue or submit a pull request. Let’s make dependency management better, together! 🌟
