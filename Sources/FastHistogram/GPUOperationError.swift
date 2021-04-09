/**
 GPU histogram generation and rendering errors.
 */
public enum GPUOperationError: Error {
    case illegalArgument
    case initializationError
    case textureFormatError
}
