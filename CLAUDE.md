# CaptureX - macOS Screenshot Annotation App

## Swift & macOS Development Best Practices

### Code Organization

- **Modular Architecture**: Split large files into focused modules (Models, Views, ViewModels, Utilities)
- **File Size**: Keep files under 400 lines; split into logical components when exceeding
- **Separation of Concerns**:
  - Models: Data structures and business logic
  - Views: UI components only
  - Controllers/ViewModels: Coordination and state management
  - Extensions: Group related functionality in separate files

### Performance Guidelines

- **Lazy Loading**: Use `lazy var` for expensive computations
- **Avoid Redundant Redraws**: Minimize `needsDisplay` calls; batch updates when possible
- **Memory Management**: Use `weak`/`unowned` references to prevent retain cycles
- **Image Handling**: Work with `CGImage` for performance-critical operations instead of `NSImage`
- **Background Processing**: Use `DispatchQueue.global()` for heavy operations, update UI on `.main`
- **View Updates**: Use `@Observable` (modern) or `ObservableObject` instead of NotificationCenter when possible

### Swift Language Best Practices

- **Type Safety**: Use strong typing; avoid force unwrapping (`!`) - prefer `guard let` or `if let`
- **Optionals**: Use optional chaining (`?.`) and nil coalescing (`??`)
- **Enums**: Use enums for state representation and tool types
- **Protocols**: Define protocols for shared behavior (e.g., `Annotation`, `SelectableAnnotation`)
- **Value Types**: Prefer `struct` over `class` for data models (immutability, thread-safety)
- **Extensions**: Extend existing types instead of creating utility classes
- **Computed Properties**: Use computed properties over methods for derived values

### SwiftUI & AppKit Integration

- **Hybrid Approach**: Use SwiftUI for modern UI, wrap AppKit components with `NSViewRepresentable` for custom rendering
- **State Management**: Use `@Observable` (Swift 5.9+) or `@StateObject`/`@ObservedObject` for state
- **Avoid Massive Views**: Break down complex views into smaller components
- **Custom Drawing**: Use `NSView` with CoreGraphics for performance-critical rendering (like canvas)

### Naming Conventions

- **Files**: PascalCase matching the primary type (e.g., `AnnotationModels.swift`)
- **Types**: PascalCase (classes, structs, enums, protocols)
- **Variables/Functions**: camelCase, descriptive names
- **Constants**: camelCase (Swift style) or UPPER_SNAKE_CASE for global constants
- **Protocols**: Descriptive names, often ending in `-able` or `-ing` for capabilities

### Code Quality

- **DRY Principle**: Extract common logic into reusable functions
- **Single Responsibility**: Each type/function should have one clear purpose
- **Early Returns**: Use guard statements for early exits, reduce nesting
- **Comments**: Explain "why" not "what"; use `// MARK:` for organization
- **Error Handling**: Use proper error handling with `Result`, `throws`, or optionals

### Dependencies & Packages

- **Swift Package Manager**: Preferred dependency manager for Swift projects
- **Minimize Dependencies**: Only add packages that provide significant value
- **Evaluate Performance**: Check package impact on compile time and binary size
- **Common Packages**:
  - Avoid unnecessary dependencies when Foundation/AppKit can handle it
  - For this project, keep dependencies minimal for a lightweight app

### Testing & Debugging

- **Unit Tests**: Test business logic, models, and utility functions
- **Instruments**: Profile with Xcode Instruments for performance bottlenecks
- **Memory Graph**: Check for retain cycles and memory leaks
- **View Debugging**: Use Xcode's view hierarchy debugger for layout issues

### Version Control

- **Atomic Commits**: One logical change per commit
- **Descriptive Messages**: Clear commit messages explaining the change
- **Branch Strategy**: Feature branches for new functionality
- **Code Review**: Review changes before merging to main

### Performance Considerations

- Canvas drawing uses CoreGraphics for optimal rendering
- Minimize `needsDisplay` calls by batching annotation updates
- Use `context.saveGState()/restoreGState()` for isolated rendering contexts

## Common Patterns in This Project

### Adding a New Annotation Type

1. Create struct conforming to `Annotation` (and `ResizableAnnotation` if needed)
2. Implement `draw(in:imageSize:)` method
3. Add case to `AnnotationTool` enum
4. Add handling in `AnnotationCanvasView` mouse events
5. **Critical**: Add case in `adjustAnnotationCoordinates` method in `AnnotationState.swift`
6. Add UI controls in toolbar sections

### Coordinate System

- Canvas uses absolute coordinates including padding
- Padding changes require coordinate adjustment for all existing annotations
- Image coordinates start at `(padding, padding)` when gradient is enabled

### Drawing Flow

1. User interaction captured in `AnnotationCanvasView` mouse events
2. Temporary preview drawn in `drawCurrentShape`
3. Final annotation created in `mouseUp` and added to state
4. State change triggers redraw of all annotations
