import AppCore
import CoreGraphics
import Foundation

public enum ScreenCapturePermissionState: String, Codable, Sendable {
    case granted
    case deniedOrNotDetermined
}

public final class ScreenContextCoordinator {
    public init() {}

    public func permissionState() -> ScreenCapturePermissionState {
        CGPreflightScreenCaptureAccess() ? .granted : .deniedOrNotDetermined
    }

    @discardableResult
    public func requestPermission() -> Bool {
        CGRequestScreenCaptureAccess()
    }

    public func makePendingBundle(displayName: String = "Full desktop") -> VisualContextBundle {
        VisualContextBundle(displayName: displayName, previewAccepted: false, sentToModel: false)
    }

    public func markPreviewAccepted(_ bundle: VisualContextBundle) -> VisualContextBundle {
        var copy = bundle
        copy.previewAccepted = true
        return copy
    }
}
