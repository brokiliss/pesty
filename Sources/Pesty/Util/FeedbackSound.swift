import AppKit

/// The one sound Pesty plays for clipboard events.
///
/// macOS 26 renamed the alert sounds: the file `Blow.aiff` is the entry the
/// Sound settings list shows as "Breeze". Loading the file instead of looking
/// the name up keeps the sound independent of that display-name mapping.
@MainActor
enum FeedbackSound {
    private static let player: NSSound? = {
        if let sound = NSSound(contentsOfFile: "/System/Library/Sounds/Blow.aiff",
                               byReference: false) {
            return sound
        }
        return NSSound(named: NSSound.Name("Blow"))
    }()

    static func play() {
        play(volume: Settings.shared.soundVolume)
    }

    static func play(volume: Double) {
        guard let player else { return }
        player.volume = Float(min(1, max(0, volume)))
        // A single long-lived player is reused instead of building one per
        // event: rapid copies would otherwise stack players that keep their
        // decoded audio alive until they finish.
        if player.isPlaying { player.stop() }
        player.play()
    }
}
