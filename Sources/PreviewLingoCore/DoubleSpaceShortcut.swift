import Foundation

public struct DoubleSpaceShortcut {
    public enum Decision: Equatable {
        case passThrough
        case consume
        case trigger
    }

    private var firstPressTime: TimeInterval?
    private var firstContext: String?
    private var spaceIsHeld = false
    private var consumeRelease = false

    public init() {}

    public mutating func cancelSequence() {
        firstPressTime = nil
        firstContext = nil
    }

    public mutating func handle(
        keyCode: Int64,
        isDown: Bool,
        isRepeat: Bool = false,
        hasModifiers: Bool = false,
        context: String?,
        timestamp: TimeInterval
    ) -> Decision {
        guard keyCode == 49 else {
            if isDown { cancelSequence() }
            return .passThrough
        }
        if !isDown {
            let consumed = consumeRelease
            spaceIsHeld = false
            consumeRelease = false
            return consumed ? .consume : .passThrough
        }
        if spaceIsHeld || isRepeat {
            return consumeRelease ? .consume : .passThrough
        }
        spaceIsHeld = true
        guard !hasModifiers, let context = context else {
            cancelSequence()
            return .passThrough
        }
        consumeRelease = true
        if let firstTime = firstPressTime,
           context == firstContext,
           timestamp > firstTime,
           timestamp - firstTime <= 0.5 {
            cancelSequence()
            return .trigger
        }
        firstPressTime = timestamp
        firstContext = context
        return .consume
    }
}
