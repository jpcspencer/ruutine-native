import Combine
import Foundation
import Supabase

@MainActor
final class ProgramViewModel: ObservableObject {
    @Published var days: [ProgramDay] = []
    @Published var programName = "My Program"
    @Published var isLoading = true
    @Published var errorMessage: String?

    func load(userId: UUID) async {
        isLoading = true
        errorMessage = nil

        do {
            let program: TrainingProgram = try await SupabaseClient.shared
                .from("training_programs")
                .select()
                .eq("user_profile_id", value: userId)
                .eq("week_number", value: 1)
                .single()
                .execute()
                .value

            programName = program.programContent.name ?? "My Program"
            days = program.programContent.days ?? []
        } catch {
            days = []
            programName = "My Program"
        }

        isLoading = false
    }
}
