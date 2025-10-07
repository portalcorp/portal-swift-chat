#if os(iOS)
import Foundation
import SwiftUI
import UIKit

struct ImageAttachment: Identifiable, Equatable {
    let id = UUID()
    let image: UIImage
}

struct FileAttachment: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let displayName: String
}

enum AttachmentSheet: Identifiable {
    case camera
    case photos
    case files

    var id: String {
        switch self {
        case .camera: "camera"
        case .photos: "photos"
        case .files: "files"
        }
    }
}
#endif
