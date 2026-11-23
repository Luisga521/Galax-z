#if os(Android)
import Android

// Android's C library gives these for Double only; Darwin and Glibc give them for Float too.
@inlinable func sin(_ x: Float) -> Float { sinf(x) }
@inlinable func cos(_ x: Float) -> Float { cosf(x) }
@inlinable func exp(_ x: Float) -> Float { expf(x) }
@inlinable func log10(_ x: Float) -> Float { log10f(x) }
@inlinable func pow(_ x: Float, _ y: Float) -> Float { powf(x, y) }
@inlinable func tanh(_ x: Float) -> Float { tanhf(x) }
#endif
