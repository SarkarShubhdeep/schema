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

@MainActor
struct TaskPageNavigationTests {
    @Test func aTaskPageSitsOverWhereItWasOpened() {
        let list = UUID(), first = UUID(), second = UUID()
        let navigation = Navigation()
        navigation.go(to: .page(list))
        navigation.go(to: .task(first))
        #expect(navigation.context == .page(list))

        // Previous and next replace the step, so Back leaves the task pages.
        navigation.replace(with: .task(second))
        #expect(navigation.context == .page(list))
        navigation.goBack()
        #expect(navigation.destination == .page(list))
        navigation.goForward()
        #expect(navigation.destination == .task(second))
    }

    @Test func forgettingADeletedTask() {
        let list = UUID(), task = UUID()
        let navigation = Navigation()
        navigation.go(to: .page(list))
        navigation.go(to: .task(task))
        navigation.forget(task: task, fallback: navigation.context)
        #expect(navigation.destination == .page(list))
        #expect(!navigation.canGoForward)
    }
}
