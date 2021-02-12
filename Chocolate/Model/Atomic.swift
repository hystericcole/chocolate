//
//  Atomic.swift
//  MaggicTones
//
//  Created by Eric Cole on 12/24/20.
//

import Foundation

/// Lock free thread safe boolean type value.
struct AtomicFlag {
	private var flag = atomic_flag()
	
	/// Return false if the flag was already set, true if the flag was clear and is now set.
	mutating func acquire() -> Bool { return !atomic_flag_test_and_set(&flag) }
	mutating func acquire(memoryOrder:memory_order) -> Bool { return !atomic_flag_test_and_set_explicit(&flag, memoryOrder) }
	
	/// Clear the flag so the next call to set will return true.
	mutating func clear() { atomic_flag_clear(&flag) }
	mutating func clear(memoryOrder:memory_order) { atomic_flag_clear_explicit(&flag, memoryOrder) }
}

/// Lock free thread safe integer value.
/// # Performance
/// Twice as fast as DispatchQueue.  Much faster than locks and semaphores.
struct AtomicInt: ExpressibleByIntegerLiteral, CustomStringConvertible {
	typealias IntegerLiteralType = Int32
	
	var raw:Int32
	var value:Int {
		get { return Int(raw) }
		set { raw = Int32(newValue) }
	}
	
	var description:String { return "⚛" + String(raw) }
	
	init(_ value:IntegerLiteralType) { raw = value }
	init(integerLiteral value:IntegerLiteralType) { raw = value }
	
	/// Atomic +
	/// - Parameter add: To add
	/// - Returns: value + add
	@discardableResult
	mutating func sum(_ add:Int32) -> Int32 {
		return OSAtomicAdd32(add, &raw)
	}
	
	/// Atomic &
	/// - Parameter bits: To and
	/// - Returns: value & bits
	@discardableResult
	mutating func and(_ bits:UInt32) -> Int32 {
		return withUnsafeMutableBytes(of:&raw) { OSAtomicAnd32(bits, $0.baseAddress!.assumingMemoryBound(to:UInt32.self)) }
	}
	
	/// Atomic ^
	/// - Parameter bits: To xor
	/// - Returns: value ^ bits
	@discardableResult
	mutating func xor(_ bits:UInt32) -> Int32 {
		return withUnsafeMutableBytes(of:&raw) { OSAtomicXor32(bits, $0.baseAddress!.assumingMemoryBound(to:UInt32.self)) }
	}
	
	/// Atomic |
	/// - Parameter bits: To or
	/// - Returns: value | bits
	@discardableResult
	mutating func or(_ bits:UInt32) -> Int32 {
		return withUnsafeMutableBytes(of:&raw) { OSAtomicOr32(bits, $0.baseAddress!.assumingMemoryBound(to:UInt32.self)) }
	}
	
	/// Atomic test and set
	/// ```
	/// result = (value >> bit) & 1
	/// value |= 1 << bit
	/// return result
	/// ```
	/// - Parameter bit: The bit position to set
	/// - Returns: the initial state of the bit
	@discardableResult
	mutating func set(bit:Int) -> Bool {
		return OSAtomicTestAndSet(UInt32(bit ^ 7), &raw)
	}
	
	/// Atomic test and clear
	/// ```
	/// result = (value >> bit) & 1
	/// value &= ~(1 << bit)
	/// return result
	/// ```
	/// - Parameter bit: The bit position to clear
	/// - Returns: the initial state of the bit
	@discardableResult
	mutating func clear(bit:Int) -> Bool {
		return OSAtomicTestAndClear(UInt32(bit ^ 7), &raw)
	}
	
	/// Atomic swap
	/// ```
	/// if value == old {
	/// 	value = new
	/// 	return true
	/// } else {
	/// 	return false
	/// }
	/// ```
	/// - Parameters:
	///   - old: expected value
	///   - new: replacement value
	/// - Returns: True if the value was equal to old and was set to new
	@discardableResult
	mutating func swap(old:Int32, new:Int32) -> Bool {
		return OSAtomicCompareAndSwap32(old, new, &raw)
	}
}

struct AtomicInt64 {
	typealias IntegerLiteralType = Int64
	
	var raw:Int64
	var value:Int {
		get { return Int(raw) }
		set { raw = Int64(newValue) }
	}
	
	var description:String { return "⚛" + String(raw) }
	
	init(_ value:IntegerLiteralType) { raw = value }
	init(integerLiteral value:IntegerLiteralType) { raw = value }
	
	/// Atomic +
	/// - Parameter add: To add
	/// - Returns: value + add
	@discardableResult
	mutating func sum(_ add:Int64) -> Int64 {
		return OSAtomicAdd64(add, &raw)
	}
	
	/// Atomic swap
	/// ```
	/// if value == old {
	/// 	value = new
	/// 	return true
	/// } else {
	/// 	return false
	/// }
	/// ```
	/// - Parameters:
	///   - old: expected value
	///   - new: replacement value
	/// - Returns: True if the value was equal to old and was set to new
	@discardableResult
	mutating func swap(old:Int64, new:Int64) -> Bool {
		return OSAtomicCompareAndSwap64(old, new, &raw)
	}
}
