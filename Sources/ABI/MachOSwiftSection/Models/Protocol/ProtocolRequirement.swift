import MachOKit
import MachOBase

@LocatableLayoutWrapping
public struct ProtocolRequirement: ResolvableLocatableLayoutWrapper {
    public struct Layout: LayoutProtocol {
        public let flags: ProtocolRequirementFlags
        public let defaultImplementation: RelativeDirectRawPointer
    }
}

extension ProtocolRequirement {
    /// File offset of the requirement's default implementation, or `nil`
    /// when the requirement has none. Pure pointer arithmetic on the
    /// descriptor's own offset; symbol attribution is `SwiftInspection`'s
    /// `defaultImplementationSymbols(in:)`, one layer up.
    @available(*, deprecated, message: "The pointer's delta counts in memory: pass a ReadingContext, defaultImplementationOffset(in: context).")
    public var defaultImplementationOffset: Int? {
        resolvedDirectOffset(from: \.defaultImplementation)
    }

    /// The offset of the default implementation in `context`, `nil` when the
    /// requirement has none or the pointer leads to no bytes.
    public func defaultImplementationOffset(in context: some ReadingContext) -> Int? {
        resolvedDirectOffset(from: \.defaultImplementation, in: context)
    }
}

@LocatableLayoutWrapping
public struct ProtocolBaseRequirement: ResolvableLocatableLayoutWrapper {
    public struct Layout: LayoutProtocol {}
}

// MARK: - ReadingContext Support

extension ProtocolRequirement {
    /// The default implementation's location as an address in `context`, or
    /// `nil` when the requirement has none.
    public func defaultImplementationAddress<Context: ReadingContext>(in context: Context) throws -> Context.Address? {
        guard let defaultImplementationOffset = defaultImplementationOffset(in: context) else { return nil }
        return try context.addressFromOffset(defaultImplementationOffset)
    }
}
