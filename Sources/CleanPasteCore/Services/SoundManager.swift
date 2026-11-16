import Foundation
import AppKit

public final class SoundManager {
    public static let shared = SoundManager()

    public enum Effect {
        case capture
        case paste
        case stackAdd
        case stackDone
        case delete
    }

    private init() {}

    public func play(_ effect: Effect, enabled: Bool) {
        guard enabled else { return }
        let (soundName, volume): (String, Float) = {
            switch effect {
            case .capture: return ("Pop", 0.20)
            case .paste: return ("Tink", 0.25)
            case .stackAdd: return ("Tink", 0.30)
            case .stackDone: return ("Glass", 0.25)
            case .delete: return ("Funk", 0.15)
            }
        }()

        if let sound = NSSound(named: NSSound.Name(soundName)) {
            sound.volume = volume
            sound.play()
        }
    }
}
