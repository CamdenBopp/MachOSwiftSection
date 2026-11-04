import Foundation
import MachOKit
import MachOBase

@LocatableLayoutWrapping
public struct MethodDescriptor: ResolvableLocatableLayoutWrapper {
    public struct Layout: LayoutProtocol {
        public let flags: MethodDescriptorFlags
        public let implementation: RelativeDirectRawPointer
    }
}

extension MethodDescriptor {
    /// File offset of the method's implementation, or `nil` when the pointer
    /// is null (an abstract method, or one whose implementation is not in
    /// this image). Pure pointer arithmetic on the descriptor's own offset —
    /// no reader involved. Attributing symbol names to that offset is
    /// `SwiftInspection`'s `implementationSymbols(in:)`, one layer up.
    @available(*, deprecated, message: "The pointer's delta counts in memory: pass a ReadingContext, implementationOffset(in: context).")
    public var implementationOffset: Int? {
        resolvedDirectOffset(from: \.implementation)
    }

    /// The offset of the implementation in `context`, `nil` for a null pointer
    /// or one that leads to no bytes.
    public func implementationOffset(in context: some ReadingContext) -> Int? {
        resolvedDirectOffset(from: \.implementation, in: context)
    }
}

// MARK: - ReadingContext Support

extension MethodDescriptor {
    /// The implementation's location as an address in `context` (a file
    /// offset for `MachOContext`, a pointer in-process), or `nil` for a null
    /// pointer.
    public func implementationAddress<Context: ReadingContext>(in context: Context) throws -> Context.Address? {
        guard let implementationOffset = implementationOffset(in: context) else { return nil }
        return try context.addressFromOffset(implementationOffset)
    }
}
