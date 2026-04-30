import AppCore
import AppKit
import CoreGraphics
import Foundation

public enum ScreenCapturePermissionState: String, Codable, Sendable {
    case granted
    case deniedOrNotDetermined
}

public enum ScreenCaptureError: Error, CustomStringConvertible {
    case imageUnavailable
    case pngEncodingFailed
    case writeFailed(String)

    public var description: String {
        switch self {
        case .imageUnavailable:
            return "Could not capture the main display."
        case .pngEncodingFailed:
            return "Could not encode the screen preview as PNG."
        case .writeFailed(let message):
            return "Could not write screen preview: \(message)"
        }
    }
}

public protocol ScreenImageCapturing: Sendable {
    func captureMainDisplayPreview() throws -> URL
}

public protocol ScreenPreviewCoordinating {
    func permissionState() -> ScreenCapturePermissionState
    @discardableResult func requestPermission() -> Bool
    func capturePreviewBundle(displayName: String) throws -> VisualContextBundle
    func markPreviewAccepted(_ bundle: VisualContextBundle) -> VisualContextBundle
}

public struct MainDisplayScreenCapturer: ScreenImageCapturing {
    private let outputDirectory: URL

    public init(outputDirectory: URL = FileManager.default.temporaryDirectory) {
        self.outputDirectory = outputDirectory
    }

    public func captureMainDisplayPreview() throws -> URL {
        guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
            throw ScreenCaptureError.imageUnavailable
        }
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.pngEncodingFailed
        }
        let url = outputDirectory
            .appendingPathComponent("sidecar-screen-\(UUID().uuidString)")
            .appendingPathExtension("png")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            throw ScreenCaptureError.writeFailed(error.localizedDescription)
        }
    }
}

public final class ScreenContextCoordinator: ScreenPreviewCoordinating {
    private let capturer: ScreenImageCapturing

    public init(capturer: ScreenImageCapturing = MainDisplayScreenCapturer()) {
        self.capturer = capturer
    }

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

    public func capturePreviewBundle(displayName: String = "Full desktop") throws -> VisualContextBundle {
        let previewURL = try capturer.captureMainDisplayPreview()
        return VisualContextBundle(
            displayName: displayName,
            imagePath: previewURL.path,
            previewAccepted: false,
            sentToModel: false
        )
    }

    public func markPreviewAccepted(_ bundle: VisualContextBundle) -> VisualContextBundle {
        var copy = bundle
        copy.previewAccepted = true
        return copy
    }
}
