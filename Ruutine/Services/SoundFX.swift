import AudioToolbox

enum SoundFX {
    private static func play(_ id: SystemSoundID) { AudioServicesPlaySystemSound(id) }
    static func setComplete()     { play(1104) }
    static func workoutComplete() { play(1025) }
}
