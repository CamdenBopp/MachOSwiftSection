import SwiftDeclarationRendering
import SwiftDeclaration
import Semantic

// MARK: - Offset Comment

/// An offset comment that outputs a comment when enabled.
struct OffsetComment: SemanticStringComponent {
    let prefix: String

    let offset: Int?

    let emit: Bool

    init(prefix: String, offset: Int?, emit: Bool) {
        self.prefix = prefix
        self.offset = offset
        self.emit = emit
    }

    package func buildComponents() -> [AtomicComponent] {
        guard emit, let offset else { return [] }

        return Comment("\(prefix): 0x\(String(offset, radix: 16))").buildComponents()
    }
}

// MARK: - Address Comment

/// An address comment that outputs a member address comment when enabled.
struct AddressComment: SemanticStringComponent {
    let addressString: String?

    let label: String?

    let emit: Bool

    init(addressString: String?, label: String? = nil, emit: Bool) {
        self.addressString = addressString
        self.label = label
        self.emit = emit
    }

    package func buildComponents() -> [AtomicComponent] {
        guard emit, let addressString else { return [] }

        if let label {
            return Comment("Address (\(label)): 0x\(addressString)").buildComponents()
        } else {
            return Comment("Address: 0x\(addressString)").buildComponents()
        }
    }
}

// MARK: - VTable Offset Comment

/// A vtable offset comment that outputs a vtable slot offset comment when enabled.
struct VTableOffsetComment: SemanticStringComponent {
    let vtableOffset: Int?

    let label: String?

    let emit: Bool

    let transformer: (@Sendable (Int, String?) -> SemanticString)?

    /// The class has a resilient superclass, so its descriptor's offsets count
    /// from the end of a vtable whose size is known only at run time.
    let isRelative: Bool

    init(vtableOffset: Int?, label: String? = nil, emit: Bool, transformer: (@Sendable (Int, String?) -> SemanticString)?, isRelative: Bool = false) {
        self.vtableOffset = vtableOffset
        self.label = label
        self.emit = emit
        self.transformer = transformer
        self.isRelative = isRelative
    }

    package func buildComponents() -> [AtomicComponent] {
        guard emit, let vtableOffset else { return [] }

        if let transformer {
            return transformer(vtableOffset, label).buildComponents()
        } else if let label {
            return Comment("VTable offset (\(label)): \(vtableOffset)\(isRelative ? VTableOffsetSpelling.relativeSuffix : "")").buildComponents()
        } else {
            return Comment("VTable offset: \(vtableOffset)\(isRelative ? VTableOffsetSpelling.relativeSuffix : "")").buildComponents()
        }
    }
}

// MARK: - Export Status Comment

/// A `not exported` comment (evolution proposal 0008): emitted only when
/// the member's symbols provably have no export-trie entry. `isExported`
/// `nil` means "no verdict" — no export information in the image, or no
/// symbol evidence on the member — and emits nothing, so the annotation
/// never guesses. Unlike its sibling comment components this one carries
/// no `emit` flag: the caller gates on the configuration flag BEFORE
/// running the export query, so a constructed component is already past
/// the gate.
struct ExportStatusComment: SemanticStringComponent {
    let isExported: Bool?

    init(isExported: Bool?) {
        self.isExported = isExported
    }

    package func buildComponents() -> [AtomicComponent] {
        guard isExported == false else { return [] }

        return Comment("not exported").buildComponents()
    }
}

// MARK: - Imports Block

/// A block of import statements.
package struct ImportsBlock: SemanticStringComponent {
    package let modules: [String]

    package init(_ modules: [String]) {
        self.modules = modules
    }

    package init(_ modules: String...) {
        self.modules = modules
    }

    package func buildComponents() -> [AtomicComponent] {
        guard !modules.isEmpty else { return [] }

        var result: [AtomicComponent] = []
        for module in modules {
            result.append(contentsOf: Standard("import \(module)").buildComponents())
            result.append(contentsOf: BreakLine().buildComponents())
        }
        return result
    }
}
