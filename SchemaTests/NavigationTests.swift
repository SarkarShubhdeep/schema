//
//  NavigationTests.swift
//  SchemaTests
//
//  One destination, back and forward (#118).
//

import Foundation
import Testing
@testable import Schema

@MainActor
struct NavigationTests {
    @Test func startsOnToday() {
        let navigation = Navigation()
        #expect(navigation.destination == .view(.today))
        #expect(!navigation.canGoBack)
        #expect(!navigation.canGoForward)
    }

    @Test func backAndForwardRetraceSteps() {
        let a = UUID(), b = UUID()
        let navigation = Navigation()
        navigation.go(to: .page(a))
        navigation.go(to: .page(b))
        navigation.go(to: .tool(.pomodoro))

        navigation.goBack()
        #expect(navigation.destination == .page(b))
        navigation.goBack()
        #expect(navigation.destination == .page(a))
        navigation.goForward()
        #expect(navigation.destination == .page(b))
        #expect(navigation.canGoForward)

        // Going somewhere new drops what was ahead.
        navigation.go(to: .view(.everything))
        #expect(!navigation.canGoForward)
        navigation.goBack()
        #expect(navigation.destination == .page(b))
    }

    @Test func goingWhereYouAreDoesNothing() {
        let navigation = Navigation()
        navigation.go(to: .view(.today))
        #expect(!navigation.canGoBack)
    }

    @Test func forgettingTheOpenPageGoesBack() {
        let a = UUID(), b = UUID()
        let navigation = Navigation()
        navigation.go(to: .page(a))
        navigation.go(to: .view(.upcoming))
        navigation.go(to: .page(b))
        navigation.go(to: .page(a))

        navigation.forget(page: a)
        #expect(navigation.destination == .page(b))
        #expect(navigation.backStack == [.view(.today), .view(.upcoming)])
    }
}

@MainActor
struct PinTests {
    @Test func destinationsRoundTripThroughStorage() {
        let id = UUID()
        for destination in [Destination.page(id), .view(.upcoming), .tool(.pomodoro)] {
            #expect(Destination(storageKey: destination.storageKey) == destination)
        }
        #expect(Destination(storageKey: "page:nope") == nil)
        #expect(Destination(storageKey: "junk") == nil)
    }
}
