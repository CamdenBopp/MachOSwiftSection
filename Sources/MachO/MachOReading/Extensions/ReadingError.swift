import MachOKitExtensions

/// Errors that can occur when reading data from MachO files or memory.
public enum ReadingError: Error {
    /// The data size is smaller than expected for the requested read operation.
    case invalidDataSize

    /// The layout size does not match the memory layout size.
    case invalidLayoutSize

    /// The address is invalid or cannot be converted (e.g., null pointer).
    case invalidAddress(Int)

    /// A relative pointer or an address leads to no bytes in the file: into
    /// memory the loader zero-fills, or outside every segment.
    case noFileBytes
}

extension MachONamespace {
    func throwIfInvalid(_ isValid: Bool, error: ReadingError) throws {
        if !isValid {
            throw error
        }
    }
}
