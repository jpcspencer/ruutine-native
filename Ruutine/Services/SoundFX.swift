import AudioToolbox

enum SoundFX {
    private static func play(_ id: SystemSoundID) {
        guard AppPreferences.shared.soundsEnabled else { return }
        AudioServicesPlaySystemSound(id)
    }
    static func setComplete()     { play(1104) }
    static func workoutComplete() { play(1025) }
    static func restEnd()         { play(1005) }
    static func select()          { play(1104) }
    static func add()             { play(1104) }
    static func openNewWorkout()  { play(1306) }
    static func startWorkout()    { play(1113) }
    static func onboardingComplete() { play(1394) }
}
