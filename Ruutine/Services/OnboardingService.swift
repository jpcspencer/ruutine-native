import Auth
import Combine
import Foundation
import Supabase

@MainActor
final class OnboardingService: ObservableObject {
    @Published private(set) var messages: [AtlasMessage] = []
    @Published var isTyping = false
    @Published var isGenerating = false
    @Published var isSaving = false
    @Published var step: OnboardingStep = .greetingName
    @Published private(set) var collected = OnboardingChatData()
    @Published private(set) var program: OnboardingProgramPayload?
    @Published var measurementHeightCm = ""
    @Published var measurementWeightKg = ""

    private var userId: UUID?
    private var accessToken: String?
    private var didSeedGreeting = false

    private let chatURL = URL(string: "https://ruutine.app/api/onboarding/chat")!
    private let generateURL = URL(string: "https://ruutine.app/api/onboarding/generate")!
    private let completeURL = URL(string: "https://ruutine.app/api/onboarding/complete")!

    var showInitialGreeting: Bool {
        messages.isEmpty && step == .greetingName
    }

    /// Matches Capacitor `onboarding-chat.tsx` chip selection (lines 578–584).
    var effectiveChipStep: OnboardingStep {
        if step == .measurementsInput || step == .generating || step == .programPreview {
            return .none
        }

        let lastAssistantMessage = messages.last(where: { $0.role == .assistant })?.content ?? ""
        var chipStep = chipStepFromMessage(lastAssistantMessage)

        if chipStep == .none {
            if messages.isEmpty && step == .greetingName {
                chipStep = .greetingName
            } else {
                chipStep = step
            }
        }

        if (chipStep == .injuries || chipStep == .injuriesCustom) && conversationMentionsInjury() {
            chipStep = .none
        }

        let stepsWithChips: Set<OnboardingStep> = [
            .greetingName, .goal, .experience, .daysPerWeek, .trainingDays,
            .equipment, .injuries, .injuriesCustom, .gender, .measurementsAsk, .measurementsInput,
        ]

        var effective = chipStep == .none && stepsWithChips.contains(step) ? step : chipStep

        if effective != .none, stepsWithChips.contains(step), stepIndex(step) > stepIndex(effective) {
            effective = step
        }

        return effective == .none ? .none : effective
    }

    var quickReplyChips: [String] {
        let effective = effectiveChipStep
        guard effective != .none else { return [] }
        return OnboardingMaps.chips(for: effective)
    }

    private static let stepOrder: [OnboardingStep] = [
        .greetingName, .goal, .experience, .daysPerWeek, .trainingDays,
        .equipment, .injuries, .injuriesCustom, .gender, .measurementsAsk, .measurementsInput,
        .generating, .programPreview,
    ]

    private func stepIndex(_ value: OnboardingStep) -> Int {
        Self.stepOrder.firstIndex(of: value) ?? -1
    }

    var hidesInputBar: Bool {
        step == .generating || step == .programPreview
    }

    func configure(session: Session) {
        userId = session.user.id
        accessToken = session.accessToken
        seedGreetingIfNeeded()
    }

    func seedGreetingIfNeeded() {
        guard !didSeedGreeting else { return }
        didSeedGreeting = true
    }

    func isTrainingDaySelected(_ day: Int) -> Bool {
        collected.trainingDays.contains(day)
    }

    func sendMessage(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isTyping, !isGenerating else { return }

        if step == .greetingName, trimmed.count < 2, trimmed.lowercased() != "skip" {
            return
        }

        if step == .measurementsInput {
            await submitMeasurements()
            return
        }

        if step == .measurementsAsk {
            if matchesSkip(trimmed) {
                await skipMeasurements()
                return
            }
            if matchesManualEntry(trimmed) {
                appendUser(trimmed)
                appendAssistant("Enter your height and weight below.")
                step = .measurementsInput
                return
            }
        }

        await sendToAtlas(trimmed)
    }

    func selectChip(_ label: String) async {
        guard !isTyping, !isGenerating else { return }

        if label == "Skip" {
            await handleSkip(for: effectiveChipStep == .none ? step : effectiveChipStep)
            return
        }

        if effectiveChipStep == .injuries, label == "Type my own..." {
            step = .injuriesCustom
            return
        }

        if effectiveChipStep == .trainingDays {
            guard let dayId = OnboardingMaps.dayLabels.first(where: { $0.value == label })?.key else { return }
            var next = collected.trainingDays
            if next.contains(dayId) {
                next.removeAll { $0 == dayId }
            } else if next.count < max(collected.daysPerWeek, 1) {
                next.append(dayId)
                next.sort()
            } else if !next.isEmpty {
                next.removeFirst()
                next.append(dayId)
                next.sort()
            }
            collected.trainingDays = next
            if next.count == collected.daysPerWeek, collected.daysPerWeek >= 2 {
                let joined = next.compactMap { OnboardingMaps.dayLabels[$0] }.joined(separator: ", ")
                await sendToAtlas(joined)
            }
            return
        }

        if effectiveChipStep == .measurementsAsk {
            if label == "Enter manually" || label == "Sure" {
                appendUser("Enter manually")
                appendAssistant("Enter your height and weight below.")
                step = .measurementsInput
                return
            }
            if label == "I'll skip this" || label == "Skip" {
                await skipMeasurements()
                return
            }
        }

        if step == .measurementsInput, label == "I'll skip this" || label == "Skip" {
            await skipMeasurements()
            return
        }

        await sendToAtlas(label)
    }

    func submitMeasurements() async {
        let height = Double(measurementHeightCm.trimmingCharacters(in: .whitespacesAndNewlines))
        let weight = Double(measurementWeightKg.trimmingCharacters(in: .whitespacesAndNewlines))
        collected.heightCm = height
        collected.weightKg = weight
        collected.measurementsSure = false
        let userText: String
        if let height, let weight {
            userText = "\(Int(height))cm, \(weight)kg"
        } else {
            userText = "Skip"
        }
        appendUser(userText)
        appendAssistant("Perfect — I have everything I need. Generating your personalized program now...")
        step = .generating
        await triggerGenerate()
    }

    func completeOnboarding() async throws {
        guard let userId, let program else {
            throw OnboardingError.missingData
        }
        isSaving = true
        defer { isSaving = false }

        if let token = accessToken, !token.isEmpty {
            let succeeded = await completeViaAPI(userId: userId, token: token)
            if succeeded { return }
            print("[OnboardingService] complete API failed — falling back to Supabase client")
        }

        try await completeViaSupabase(userId: userId)
    }

    // MARK: - Chat API

    private func sendToAtlas(_ message: String) async {
        appendUser(message)
        isTyping = true
        defer { isTyping = false }

        let history = messages.dropLast().map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = [
            "message": message,
            "messages": history,
            "collected": collectedPayload(),
            "currentStep": step.rawValue,
        ]

        do {
            let (data, response) = try await postJSON(to: chatURL, body: body, authToken: nil)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("[OnboardingService] POST \(chatURL.absoluteString)")
            print("[OnboardingService] request body: \(String(data: try JSONSerialization.data(withJSONObject: body), encoding: .utf8) ?? "")")
            print("[OnboardingService] HTTP status: \(status)")
            print("[OnboardingService] raw response: \(raw)")

            if let error = parseError(from: data) {
                appendAssistant(error)
                return
            }

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                appendAssistant("Atlas request failed (HTTP \(status)).")
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                appendAssistant("Atlas returned an unexpected response.")
                return
            }

            let text = json["text"] as? String ?? ""
            let extracted = json["extracted"] as? [String: Any] ?? [:]
            collected = mergeExtracted(collected, extracted: extracted)

            if !cleanAtlasMessage(text).isEmpty {
                appendAssistant(cleanAtlasMessage(text))
            }

            let next = nextStep(from: collected)
            step = next
            if next == .generating {
                await triggerGenerate()
            }
        } catch {
            print("[OnboardingService] chat network error: \(error)")
            appendAssistant("Couldn't reach Atlas. Check your connection and try again.")
        }
    }

    private func triggerGenerate() async {
        isGenerating = true
        step = .generating
        defer { isGenerating = false }

        let payload = generatePayload()
        do {
            let bodyData = try JSONSerialization.data(withJSONObject: payload)
            var request = URLRequest(url: generateURL)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = bodyData

            print("[OnboardingService] POST \(generateURL.absoluteString)")
            print("[OnboardingService] request body: \(String(data: bodyData, encoding: .utf8) ?? "")")

            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("[OnboardingService] HTTP status: \(status)")
            print("[OnboardingService] raw response: \(raw)")

            if let error = parseError(from: data) {
                appendAssistant(error)
                step = .measurementsAsk
                return
            }

            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                appendAssistant("Program generation failed (HTTP \(status)).")
                step = .measurementsAsk
                return
            }

            let decoder = JSONDecoder()
            struct GenerateResponse: Decodable {
                let program: OnboardingProgramPayload
            }
            let decoded = try decoder.decode(GenerateResponse.self, from: data)
            program = decoded.program

            let name = collected.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "there" : collected.name
            let goalLabel: String = {
                switch collected.goal {
                case "strength": return "strength"
                case "hypertrophy": return "muscle building"
                case "weight_loss": return "fat loss"
                case "general": return "general fitness"
                default: return collected.goal.isEmpty ? "goals" : collected.goal
                }
            }()
            let days = collected.daysPerWeek
            let injury = collected.injuriesLimitations?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let hasInjury = injury != nil && !injury!.isEmpty && injury!.lowercased() != "none"

            let intro: String
            if hasInjury, let injury {
                intro = "Alright \(name), based on everything you've told me — here's your Week 1. I've built this around your \(goalLabel), your \(days) training days, and kept your \(injury) in mind throughout. This is just the starting point — we'll adjust as you go, and you can always come back to chat with me anytime."
            } else {
                intro = "Alright \(name), based on everything you've told me — here's your Week 1. I've built this around your \(goalLabel) and your \(days) training days. This is just the starting point — we'll adjust as you go, and you can always come back to chat with me anytime."
            }
            appendAssistant(intro)
            step = .programPreview
        } catch {
            print("[OnboardingService] generate error: \(error)")
            appendAssistant("Something went wrong building your program. Please try again.")
            step = .measurementsAsk
        }
    }

    // MARK: - Complete

    private func completeViaAPI(userId: UUID, token: String) async -> Bool {
        guard let program else { return false }
        let body: [String: Any] = [
            "data": generatePayload(),
            "program": encodeProgram(program),
        ]
        do {
            let (data, response) = try await postJSON(to: completeURL, body: body, authToken: token)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("[OnboardingService] POST \(completeURL.absoluteString)")
            print("[OnboardingService] HTTP status: \(status)")
            print("[OnboardingService] raw response: \(raw)")
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            if parseError(from: data) != nil { return false }
            return true
        } catch {
            print("[OnboardingService] complete API error: \(error)")
            return false
        }
    }

    private func completeViaSupabase(userId: UUID) async throws {
        guard let program else { throw OnboardingError.missingData }

        let unitPreference = ["metric", "imperial"].contains(collected.unitPreference)
            ? collected.unitPreference
            : "metric"
        let trainingDays = collected.trainingDays.isEmpty ? [1, 3, 5] : collected.trainingDays

        let profileInsert = OnboardingProfileInsert(
            id: userId,
            name: collected.name.trimmingCharacters(in: .whitespacesAndNewlines),
            goal: collected.goal,
            experienceLevel: collected.experienceLevel,
            daysPerWeek: collected.daysPerWeek,
            trainingDays: trainingDays,
            equipmentAccess: collected.equipmentAccess,
            injuriesLimitations: collected.injuriesLimitations?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .nilIfEmpty(),
            heightCm: collected.heightCm,
            weightKg: collected.weightKg,
            biologicalSex: collected.gender?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty(),
            unitPreference: unitPreference,
            theme: "onyx"
        )

        print("[OnboardingService] Supabase insert user_profiles: \(profileInsert)")
        try await SupabaseClient.shared
            .from("user_profiles")
            .insert(profileInsert)
            .execute()

        let programInsert = TrainingProgramInsert(
            userProfileId: userId,
            weekNumber: 1,
            programContent: program
        )
        print("[OnboardingService] Supabase insert training_programs: week 1")
        try await SupabaseClient.shared
            .from("training_programs")
            .insert(programInsert)
            .execute()
    }

    // MARK: - Step logic (Capacitor onboarding-chat.tsx)

    private func nextStep(from data: OnboardingChatData) -> OnboardingStep {
        if data.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .greetingName }
        if data.goal.isEmpty { return .goal }
        if data.experienceLevel.isEmpty { return .experience }
        if data.daysPerWeek < 2 { return .daysPerWeek }
        if data.trainingDays.isEmpty || data.trainingDays.count != data.daysPerWeek { return .trainingDays }
        if data.equipmentAccess.isEmpty { return .equipment }
        if data.injuriesLimitations == nil { return .injuries }
        if data.gender == nil || data.gender!.isEmpty { return .gender }
        if data.measurementsSkip { return .generating }
        if data.measurementsSure { return .measurementsInput }
        if data.heightCm != nil, data.weightKg != nil { return .generating }
        return .measurementsAsk
    }

    private func mergeExtracted(_ data: OnboardingChatData, extracted: [String: Any]) -> OnboardingChatData {
        var next = data
        if let name = extracted["name"] as? String, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            next.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let goal = extracted["goal"] as? String { next.goal = goal }
        if let experience = extracted["experienceLevel"] as? String { next.experienceLevel = experience }
        if let days = extracted["daysPerWeek"] as? Int { next.daysPerWeek = days }
        if let days = extracted["daysPerWeek"] as? Double { next.daysPerWeek = Int(days) }
        if let trainingDays = extracted["trainingDays"] as? [Int] { next.trainingDays = trainingDays }
        if let equipment = extracted["equipmentAccess"] as? [String] { next.equipmentAccess = equipment }
        if let injuries = extracted["injuriesLimitations"] {
            if injuries is NSNull { next.injuriesLimitations = nil }
            else { next.injuriesLimitations = String(describing: injuries) }
        }
        if let gender = extracted["gender"] as? String { next.gender = gender }
        if let height = extracted["heightCm"] as? Double { next.heightCm = height }
        if let height = extracted["heightCm"] as? Int { next.heightCm = Double(height) }
        if let weight = extracted["weightKg"] as? Double { next.weightKg = weight }
        if let weight = extracted["weightKg"] as? Int { next.weightKg = Double(weight) }
        if extracted["measurements_skip"] as? Bool == true { next.measurementsSkip = true }
        if extracted["measurements_sure"] as? Bool == true { next.measurementsSure = true }
        return next
    }

    private func chipStepFromMessage(_ message: String) -> OnboardingStep {
        let sentences = message
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let last = (sentences.last ?? "").lowercased()

        if last.contains("how many days") || last.contains("days per week") || last.contains("days a week") || last.contains("realistically train") {
            return .daysPerWeek
        }
        if last.contains("which days") || last.contains("what days") || last.contains("days work best") || last.contains("days of the week") {
            return .trainingDays
        }
        if last.contains("equipment") || last.contains("gym") || last.contains("access to") || last.contains("working out") {
            return .equipment
        }
        if last.contains("injur") || last.contains("limitation") || last.contains("pain") || last.contains("areas") || last.contains("watch out") {
            return .injuries
        }
        if last.contains("gender") || last.contains("identify") || last.contains("pronouns") || last.contains("male or female") {
            return .gender
        }
        if last.contains("height") || last.contains("weight") || last.contains("measurements") {
            return .measurementsAsk
        }
        if last.contains("goal") || last.contains("looking to") || last.contains("training goal") {
            return .goal
        }
        if last.contains("experience") || last.contains("beginner") || last.contains("lifting for") {
            return .experience
        }
        return .none
    }

    private func conversationMentionsInjury() -> Bool {
        let keywords = ["knee", "shoulder", "back", "wrist", "hip", "injury", "pain", "hurt", "injured", "limitation"]
        let text = messages
            .filter { $0.role == .user }
            .map(\.content)
            .joined(separator: " ")
            .lowercased()
        return keywords.contains { text.contains($0) }
    }

    private func handleSkip(for stepKey: OnboardingStep) async {
        let days = collected.daysPerWeek >= 2 ? collected.daysPerWeek : 3
        let defaultDays = Array([1, 3, 5].prefix(min(days, 3)))
        var updated = collected

        switch stepKey {
        case .greetingName:
            updated.name = "there"
        case .goal:
            updated.goal = "general"
        case .experience:
            updated.experienceLevel = "beginner"
        case .daysPerWeek:
            updated.daysPerWeek = 3
        case .trainingDays:
            updated.trainingDays = defaultDays
            updated.daysPerWeek = days
        case .equipment:
            updated.equipmentAccess = ["full_gym"]
        case .injuries, .injuriesCustom:
            updated.injuriesLimitations = "none"
        case .gender:
            updated.gender = "prefer_not_to_say"
        case .measurementsAsk, .measurementsInput:
            updated.measurementsSkip = true
        default:
            break
        }

        appendUser("Skip")
        let ack: String
        switch stepKey {
        case .greetingName:
            ack = "No problem — I'll call you 'there' for now. What's your primary training goal?"
        case .goal:
            ack = "Got it. What's your experience level with lifting?"
        case .experience:
            ack = "No worries. How many days per week can you realistically train?"
        case .daysPerWeek:
            ack = "Understood. Which days of the week work best for you?"
        case .trainingDays:
            ack = "No problem. What equipment do you have access to?"
        case .equipment:
            ack = "Got it. Any injuries or areas I should program around?"
        case .injuries, .injuriesCustom:
            ack = "Perfect. One last thing — are you male or female? This helps me calibrate your program."
        case .gender, .measurementsAsk, .measurementsInput:
            ack = "Perfect — I have everything I need. Generating your personalized program now..."
        default:
            ack = "Moving on..."
        }
        appendAssistant(ack)
        collected = updated
        let next = nextStep(from: updated)
        step = next
        if next == .generating {
            await triggerGenerate()
        }
    }

    private func skipMeasurements() async {
        collected.measurementsSkip = true
        appendUser("I'll skip this")
        appendAssistant("Perfect — I have everything I need. Generating your personalized program now...")
        step = .generating
        await triggerGenerate()
    }

    // MARK: - Helpers

    private func appendUser(_ content: String) {
        messages.append(AtlasMessage(role: .user, content: content))
    }

    private func appendAssistant(_ content: String) {
        messages.append(AtlasMessage(role: .assistant, content: content))
    }

    func appendErrorMessage(_ content: String) {
        appendAssistant(content)
    }

    private func cleanAtlasMessage(_ content: String) -> String {
        content
            .replacingOccurrences(of: "```[\\w]*\\n?", with: "", options: .regularExpression)
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func matchesSkip(_ text: String) -> Bool {
        text.range(of: #"skip|no|pass|i'll skip"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func matchesManualEntry(_ text: String) -> Bool {
        text.range(of: #"sure|yes|add|enter manually|manual"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func collectedPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "name": collected.name,
            "goal": collected.goal,
            "experienceLevel": collected.experienceLevel,
            "daysPerWeek": collected.daysPerWeek,
            "trainingDays": collected.trainingDays,
            "equipmentAccess": collected.equipmentAccess,
            "unitPreference": collected.unitPreference,
        ]
        if let injuries = collected.injuriesLimitations {
            payload["injuriesLimitations"] = injuries
        }
        if let gender = collected.gender { payload["gender"] = gender }
        if let height = collected.heightCm { payload["heightCm"] = height }
        if let weight = collected.weightKg { payload["weightKg"] = weight }
        if collected.measurementsSkip { payload["measurements_skip"] = true }
        if collected.measurementsSure { payload["measurements_sure"] = true }
        return payload
    }

    private func generatePayload() -> [String: Any] {
        var payload = collectedPayload()
        payload["injuriesLimitations"] = collected.injuriesLimitations ?? NSNull()
        return payload
    }

    private func encodeProgram(_ program: OnboardingProgramPayload) -> [String: Any] {
        guard let data = try? JSONEncoder().encode(program),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return object
    }

    private func postJSON(to url: URL, body: [String: Any], authToken: String?) async throws -> (Data, URLResponse) {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let authToken, !authToken.isEmpty {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await URLSession.shared.data(for: request)
    }

    private func parseError(from data: Data) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let error = json["error"] as? String,
              !error.isEmpty
        else { return nil }
        return error
    }
}

enum OnboardingError: LocalizedError {
    case missingData

    var errorDescription: String? {
        switch self {
        case .missingData: return "Missing onboarding data."
        }
    }
}

private struct OnboardingProfileInsert: Encodable {
    let id: UUID
    let name: String
    let goal: String
    let experienceLevel: String
    let daysPerWeek: Int
    let trainingDays: [Int]
    let equipmentAccess: [String]
    let injuriesLimitations: String?
    let heightCm: Double?
    let weightKg: Double?
    let biologicalSex: String?
    let unitPreference: String
    let theme: String

    enum CodingKeys: String, CodingKey {
        case id, name, goal, theme
        case experienceLevel = "experience_level"
        case daysPerWeek = "days_per_week"
        case trainingDays = "training_days"
        case equipmentAccess = "equipment_access"
        case injuriesLimitations = "injuries_limitations"
        case heightCm = "height_cm"
        case weightKg = "weight_kg"
        case biologicalSex = "biological_sex"
        case unitPreference = "unit_preference"
    }
}

private struct TrainingProgramInsert: Encodable {
    let userProfileId: UUID
    let weekNumber: Int
    let programContent: OnboardingProgramPayload

    enum CodingKeys: String, CodingKey {
        case userProfileId = "user_profile_id"
        case weekNumber = "week_number"
        case programContent = "program_content"
    }
}

private extension String {
    func nilIfEmpty() -> String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
