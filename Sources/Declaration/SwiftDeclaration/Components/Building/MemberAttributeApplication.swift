import Demangling
import MachOSwiftSection
@_spi(Internals) import MachOSymbols

/// Cross-references `@objc` / `@nonobjc` / `distributed` thunk attribute
/// members (pre-extracted and bucketed by parent type name inside
/// `SymbolIndexStore`) with already-built member definitions, appending the
/// matching attribute to each affected member. Shared by `TypeDefinition`
/// and `ExtensionDefinition` — the sweep unwraps extension contexts when it
/// buckets a thunk, so an extension's members are filed under the extended
/// type's name and node, and one lookup serves both containers.
package enum MemberAttributeApplication {
    package static let thunkKindsAndAttributes: [(thunkKind: Node.Kind, attribute: SwiftAttribute, suffix: String)] = [
        (.objCAttribute, .objc, "To"),
        (.nonObjCAttribute, .nonobjc, "TO"),
        (.distributedThunk, .distributed, "TE"),
    ]

    /// Whether the thunk of one member exists: the member's own symbol with
    /// the thunk's suffix. A thunk names its member by its whole signature,
    /// and the bucket above keeps only the base name, so `@objc init()` must
    /// not reach `init(t:)`, nor one overload's `@objc` its sibling. An
    /// allocator's thunk hangs off the initializer (`…fC` has `…fcTo`).
    private static func hasThunk(suffix: String, ofSymbolNamed name: String, symbolIndexStore: SymbolIndexStore, in machO: some MachORepresentableWithCache) -> Bool {
        if symbolIndexStore.containsSymbol(named: name + suffix, in: machO) {
            return true
        }
        guard name.hasSuffix("fC") else { return false }
        return symbolIndexStore.containsSymbol(named: String(name.dropLast(2)) + "fc" + suffix, in: machO)
    }

    package static func applyThunkAttributes(
        symbolIndexStore: SymbolIndexStore,
        typeName: String,
        typeNode: NodeReference,
        in machO: some MachORepresentableWithCache,
        functions: inout [FunctionDefinition],
        variables: inout [VariableDefinition],
        staticFunctions: inout [FunctionDefinition],
        staticVariables: inout [VariableDefinition],
        allocators: inout [FunctionDefinition]
    ) {
        for (thunkKind, attribute, suffix) in thunkKindsAndAttributes {
            let hasOwnThunk: (String) -> Bool = {
                hasThunk(suffix: suffix, ofSymbolNamed: $0, symbolIndexStore: symbolIndexStore, in: machO)
            }
            // Node-matched: the member-name matching below is string-based,
            // so a same-named private sibling's thunks must never reach it
            // (issue #115's family).
            let members = symbolIndexStore.thunkAttributeMembers(of: thunkKind, for: typeName, node: typeNode, in: machO)
            for member in members {
                if member.isStatic {
                    apply(attribute, toFunctionNamed: member.memberName, in: &staticFunctions, where: hasOwnThunk)
                    apply(attribute, toVariableNamed: member.memberName, in: &staticVariables)
                } else {
                    apply(attribute, toFunctionNamed: member.memberName, in: &functions, where: hasOwnThunk)
                    apply(attribute, toVariableNamed: member.memberName, in: &variables)
                    if member.isInit {
                        apply(attribute, toEveryAllocatorIn: &allocators, where: hasOwnThunk)
                    }
                }
            }
        }
    }

    package static func apply(_ attribute: SwiftAttribute, toFunctionNamed name: String, in definitions: inout [FunctionDefinition], where hasOwnThunk: (String) -> Bool = { _ in true }) {
        for definitionIndex in definitions.indices {
            if definitions[definitionIndex].name == name && !definitions[definitionIndex].attributes.contains(attribute) && hasOwnThunk(definitions[definitionIndex].symbol.name) {
                definitions[definitionIndex].attributes.append(attribute)
            }
        }
    }

    package static func apply(_ attribute: SwiftAttribute, toVariableNamed name: String, in definitions: inout [VariableDefinition]) {
        for definitionIndex in definitions.indices {
            if definitions[definitionIndex].name == name && !definitions[definitionIndex].attributes.contains(attribute) {
                definitions[definitionIndex].attributes.append(attribute)
            }
        }
    }

    package static func apply(_ attribute: SwiftAttribute, toEveryAllocatorIn definitions: inout [FunctionDefinition], where hasOwnThunk: (String) -> Bool = { _ in true }) {
        for definitionIndex in definitions.indices {
            if !definitions[definitionIndex].attributes.contains(attribute) && hasOwnThunk(definitions[definitionIndex].symbol.name) {
                definitions[definitionIndex].attributes.append(attribute)
            }
        }
    }
}
