import MachOKit
import MachOReading
import MachOResolving
import MachOKitExtensions

public protocol RelativePointerProtocol<Pointee>: Sendable, Equatable {
    associatedtype Pointee: Resolvable
    associatedtype Offset: FixedWidthInteger & SignedInteger

    var relativeOffset: Offset { get }

    func resolve<Context: ReadingContext>(at address: Context.Address, in context: Context) throws -> Pointee

    func resolveAny<T: Resolvable, Context: ReadingContext>(at address: Context.Address, in context: Context) throws -> T

    func resolveDirectOffset(from offset: Int) -> Int
    func resolveDirectAddress<Context: ReadingContext>(at address: Context.Address, in context: Context) throws -> Context.Address

}

extension RelativePointerProtocol {
    @available(*, deprecated, message: "The delta counts in memory: pass a ReadingContext, resolveDirectOffset(from: offset, in: context).")
    public func resolveDirectOffset(from offset: Int) -> Int {
        return Int(offset) + Int(relativeOffset)
    }

    public func resolveDirectAddress<Context: ReadingContext>(at address: Context.Address, in context: Context) throws -> Context.Address {
        return try context.checkedAddress(context.advanceAddress(address, by: .init(relativeOffset)))
    }

    /// Where the pointer stored at `offset` leads, as an offset, or `nil` when
    /// that holds no bytes. The delta counts in memory, so the context says
    /// where it lands.
    public func resolveDirectOffset(from offset: Int, in context: some ReadingContext) -> Int? {
        guard let address = try? context.addressFromOffset(offset),
              let target = try? resolveDirectAddress(at: address, in: context) else {
            return nil
        }
        return try? context.offsetFromAddress(target)
    }

    public var isNull: Bool {
        return relativeOffset == 0
    }

    public var isValid: Bool {
        return relativeOffset != 0
    }
}

// MARK: - Deprecated Mach-O and pointer forms

extension RelativePointerProtocol {
    @available(*, deprecated, message: "Pass a ReadingContext: resolve(at: offset, in: machO.context).")
    public func resolve(from offset: Int, in machO: some MachORepresentableWithCache & Readable) throws -> Pointee {
        try resolve(at: offset, in: machO.context)
    }

    @available(*, deprecated, message: "Pass a ReadingContext: resolve(at: pointer, in: .inProcess).")
    public func resolve(from ptr: UnsafeRawPointer) throws -> Pointee {
        try resolve(at: ptr, in: InProcessContext.shared)
    }

    @available(*, deprecated, message: "Pass a ReadingContext: resolveAny(at: offset, in: machO.context).")
    public func resolveAny<T: Resolvable>(from offset: Int, in machO: some MachORepresentableWithCache & Readable) throws -> T {
        try resolveAny(at: offset, in: machO.context)
    }

    @available(*, deprecated, message: "Pass a ReadingContext: resolveAny(at: pointer, in: .inProcess).")
    public func resolveAny<T: Resolvable>(from ptr: UnsafeRawPointer) throws -> T {
        try resolveAny(at: ptr, in: InProcessContext.shared)
    }

    @available(*, deprecated, message: "Pass a ReadingContext: resolveDirectAddress(at: pointer, in: .inProcess).")
    public func resolveDirectOffset(from ptr: UnsafeRawPointer) throws -> UnsafeRawPointer {
        try resolveDirectAddress(at: ptr, in: InProcessContext.shared)
    }
}
