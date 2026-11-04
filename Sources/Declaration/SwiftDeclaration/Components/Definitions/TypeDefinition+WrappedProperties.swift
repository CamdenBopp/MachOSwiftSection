@_spi(Internals) import Demangling
import Dependencies
import MachOSwiftSection
import SwiftDeclarationRendering
@_spi(Internals) import MachOSymbols

/// Wrapped-property recovery, the last step of `TypeDefinition.index(in:)`.
///
/// For every stored field `_x` whose type is a property wrapper, the
/// definition gains a `WrappedPropertyDefinition` (see that type for what
/// it carries). A field is a wrapper's storage when its nominal type has
/// `wrappedValue` accessors: first looked for in this image's own symbol
/// index (which also knows an internal wrapper), then in the export tries
/// the image's `PropertyWrapperTypeCatalog` can reach (a wrapper from
/// another image). A field whose type is not a wrapper — a hand-written
/// `_manual` behind a computed `manual` — is left alone: `Int` has no
/// `wrappedValue`.
///
/// A wrapper-typed `_x` beside an `x` is also what a hand-written pair looks
/// like, so the shape alone proves nothing and neither does `@propertyWrapper`,
/// which is not in the binary. The proof is the backing initializer the
/// compiler emits for each wrapped property and nothing else (`…vpfP`). Without
/// it `_x` stays the stored field the record says it is.
extension TypeDefinition {
    package func recoverWrappedProperties(in machO: some MachOSwiftSectionRepresentableWithCache) {
        @Dependency(\.symbolIndexStore)
        var symbolIndexStore
        let catalog = PropertyWrapperTypeCatalogStore.shared.catalog(for: machO)
        var recovered: [WrappedPropertyDefinition] = []
        for field in fields where !field.flags.contains(.isArtificial) && field.name.hasPrefix("_") && field.name.count > 1 {
            let propertyName = String(field.name.dropFirst())
            let fieldTypeNode = field.typeNode.materialize()
            guard let wrapperNominalTypeNode = WrappedPropertyRecovery.nominalTypeNode(ofFieldType: fieldTypeNode) else { continue }
            let wrapperTypeName = TypeName(
                node: InternedNodeReferenceCache.shared.reference(interning: wrapperNominalTypeNode, in: machO),
                kind: wrapperNominalTypeNode.typeKind ?? .struct
            )
            let ownImageEvidence = WrappedPropertyRecovery.evidence(
                fromWrappedValueSymbols: symbolIndexStore.memberSymbols(
                    of: .variable(inExtension: false, isStatic: false, isStorage: false),
                    .variable(inExtension: false, isStatic: false, isStorage: true),
                    .variable(inExtension: true, isStatic: false, isStorage: false),
                    for: wrapperTypeName.name,
                    node: wrapperTypeName.node,
                    in: machO
                )
            )
            guard let evidence = ownImageEvidence ?? catalog.evidence(forWrapperCandidate: wrapperNominalTypeNode) else { continue }

            // `x`'s accessors are stripped, or `x` has no backing initializer:
            // nothing shows the source declared `x` with this wrapper, and a
            // declaration rebuilt from `wrappedValue` would be invented.
            guard let declaredMember = variables.first(where: { $0.name == propertyName }),
                  declaredMember.accessors.contains(where: { accessor in
                      WrappedPropertyRecovery.backingInitializerSymbolName(ofAccessorNamed: accessor.symbol.name).map {
                          symbolIndexStore.containsSymbol(named: $0, in: machO)
                      } ?? false
                  })
            else { continue }
            let origin = WrappedPropertyDefinition.Origin.declaredMember
            let declaredTypeNode = WrappedPropertyRecovery.declaredTypeNode(of: declaredMember)
            let attributeTypeNode = WrappedPropertyRecovery.attributeTypeNode(
                fieldTypeNode: fieldTypeNode,
                wrapperNominalTypeNode: wrapperNominalTypeNode,
                wrappedPropertyTypeNode: declaredTypeNode
            )
            recovered.append(WrappedPropertyDefinition(
                name: propertyName,
                backingFieldName: field.name,
                projectionName: "$" + propertyName,
                attributeTypeNode: InternedNodeReferenceCache.shared.reference(interning: attributeTypeNode, in: machO),
                origin: origin
            ))
        }
        wrappedProperties = recovered
    }
}
