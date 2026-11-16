//
//  BlockOrderingTests.swift
//  SchemaTests
//

import Testing
@testable import Schema

struct BlockOrderingTests {
    @Test func firstBlockInAnEmptyPage() {
        #expect(BlockOrdering.index(between: nil, and: nil) == 1)
    }

    @Test func appendAfterTheLastBlock() {
        #expect(BlockOrdering.index(between: 3, and: nil) == 4)
    }

    @Test func insertBeforeTheFirstBlock() {
        #expect(BlockOrdering.index(between: nil, and: 1) == 0)
    }

    @Test func insertBetweenTwoBlocksTakesTheMidpoint() {
        let index = BlockOrdering.index(between: 1, and: 2)
        #expect(index == 1.5)
        #expect(index > 1 && index < 2)
    }

    @Test func repeatedInsertsKeepOrderUntilRenumbering() {
        var low = 1.0
        let high = 2.0
        for _ in 0..<20 {
            let next = BlockOrdering.index(between: low, and: high)
            #expect(next > low && next < high)
            low = next
        }
        #expect(!BlockOrdering.needsRenumbering(between: low, and: high))
        #expect(BlockOrdering.needsRenumbering(between: 1, and: 1 + 1e-12))
    }

    @Test func renumberingSpacesBlocksEvenly() {
        #expect(BlockOrdering.renumbered(count: 4) == [1, 2, 3, 4])
        #expect(BlockOrdering.renumbered(count: 0).isEmpty)
    }

    @Test func onlyToDosAreCheckableAndDividersHoldNoText() {
        #expect(BlockKind.todo.isCheckable)
        #expect(!BlockKind.text.isCheckable)
        #expect(!BlockKind.divider.holdsText)
        #expect(BlockKind.heading.holdsText)
    }
}
