//
//  File.swift
//  
//
//  Created by yuki on 2023/03/27.
//

import Foundation

public protocol _RangeExpression {    
    func relative(to count: Int) -> Range<Int>
}

extension Range: _RangeExpression where Bound == Int {
    public func relative(to count: Int) -> Range<Int> { return self }
}

extension ClosedRange: _RangeExpression where Bound == Int {
    public func relative(to count: Int) -> Range<Int> { self.lowerBound..<self.upperBound+1 }
}

extension PartialRangeFrom: _RangeExpression where Bound == Int {
    public func relative(to count: Int) -> Range<Int> { self.lowerBound..<count }
}

extension PartialRangeUpTo: _RangeExpression where Bound == Int {
    public func relative(to count: Int) -> Range<Int> { 0..<self.upperBound }
}

extension PartialRangeThrough: _RangeExpression where Bound == Int {
    public func relative(to count: Int) -> Range<Int> { 0..<self.upperBound+1 }
}
