import AppKit

/// The tone a clip makes when it is recorded from another app's copy. It fires
/// far more often than the paste sound, so it is deliberately quiet: Tink is
/// the sound macOS itself uses for a successful copy, at a third of its
/// volume.
///
/// One long-lived player is reused instead of a new `NSSound` per capture: it
/// keeps a burst of copies from allocating players, and stopping before
/// playing restarts the tone so two copies in quick succession are both heard
/// rather than the second one being dropped while the first still rings.
enum CaptureSound {
    private static let volume: Float = 0.35
    private static let fileName = "Tink"

    private static let player: NSSound? = {
        let path = "/System/Library/Sounds/\(fileName).aiff"
        let sound = NSSound(contentsOfFile: path, byReference: true)
            ?? NSSound(named: NSSound.Name(fileName))
        sound?.volume = volume
        return sound
    }()

    static func play() {
        guard let player else {
            // A machine without the bundled tone should still confirm the copy
            // rather than fail silently.
            NSSound.beep()
            return
        }
        player.stop()
        player.play()
    }
}
