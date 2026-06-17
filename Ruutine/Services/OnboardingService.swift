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
    @Published var isSkipping = false
    @Published var step: OnboardingStep = .greetingName
    @Published private(set) var collected = OnboardingChatData()
    @Published private(set) var program: OnboardingProgramPayload?
    @Published var measurementHeightCm = ""
    @Published var measurementWeightKg = ""
    @Published var measurementHeightFeet = ""
    @Published var measurementHeightInches = ""
    @Published var measurementWeightLbs = ""
    @Published var measurementsUseImperial = false

    private(set) var flow: OnboardingFlow = .onboarding
    private var userId: UUID?
    private var accessToken: String?
    private var didSeedGreeting = false

    var isProgramBuildFlow: Bool { flow == .programBuild }

    private let chatURL = URL(string: "https://www.ruutine.app/api/onboarding/chat")!
    private let generateURL = URL(string: "https://www.ruutine.app/api/onboarding/generate")!
    private let completeURL = URL(string: "https://www.ruutine.app/api/onboarding/complete")!
    private static let systemPrompt =
        "You are Ruu, a personal training coach inside Ruutine. Introduce and refer to yourself as Ruu."

    var showsStructuredMeasurements: Bool {
        step == .measurementsAsk || step == .measurementsInput
    }

    var canSubmitMeasurements: Bool {
        resolvedMeasurementValues() != nil
    }

    var showInitialGreeting: Bool {
        flow == .onboarding && messages.isEmpty && step == .greetingName
    }

    var showsQuickReplyChips: Bool {
        !hidesInputBar && !quickReplyChips.isEmpty
    }

    /// Chips follow the latest assistant question; falls back to `step` when parsing is inconclusive.
    var effectiveChipStep: OnboardingStep {
        if step == .generating || step == .programPreview || isGenerating {
            return .none
        }

        // Height/weight are free-text — no quick-reply chips (input only).
        if step == .measurementsAsk || step == .measurementsInput {
            return .none
        }

        let lastAssistantMessage = messages.last(where: { $0.role == .assistant })?.content ?? ""
        if Self.isGeneratingHandoffMessage(lastAssistantMessage) {
            return .none
        }

        let stepsWithChips: Set<OnboardingStep> = [
            .goal, .experience, .daysPerWeek, .trainingDays,
            .equipment, .injuries, .injuriesCustom, .gender,
        ]

        let parsedStep = chipStepFromMessage(lastAssistantMessage)
        let effective: OnboardingStep
        if parsedStep != .none,
           parsedStep != .greetingName,
           stepsWithChips.contains(parsedStep) {
            effective = parsedStep
        } else if stepsWithChips.contains(step) {
            effective = step
        } else {
            return .none
        }

        if (effective == .injuries || effective == .injuriesCustom) && conversationMentionsInjury() {
            return .none
        }

        return effective
    }

    var quickReplyChips: [String] {
        let effective = effectiveChipStep
        guard effective != .none else { return [] }
        return OnboardingMaps.chips(for: effective)
    }

    var canGoBack: Bool {
        guard !isTyping, !isGenerating, !isSaving, !isSkipping else { return false }
        guard step != .generating, step != .programPreview else { return false }
        let normalized = normalizedStepForNavigation(step)
        guard let index = navigableStepOrder.firstIndex(of: normalized) else { return false }
        return index > 0
    }

    func goBack() {
        guard canGoBack else { return }
        let current = normalizedStepForNavigation(step)
        guard let index = navigableStepOrder.firstIndex(of: current), index > 0 else { return }

        let previous = navigableStepOrder[index - 1]
        clearCollected(for: current)
        clearCollected(for: previous)
        trimLastTransition()
        step = previous
    }

    private var navigableStepOrder: [OnboardingStep] {
        if flow == .programBuild {
            return [
                .goal, .experience, .daysPerWeek, .trainingDays, .equipment,
                .injuries, .gender, .measurementsAsk,
            ]
        }
        return [
            .greetingName, .goal, .experience, .daysPerWeek, .trainingDays, .equipment,
            .injuries, .gender, .measurementsAsk,
        ]
    }

    private func normalizedStepForNavigation(_ step: OnboardingStep) -> OnboardingStep {
        if step == .injuriesCustom { return .injuries }
        return step
    }

    private func clearCollected(for step: OnboardingStep) {
        switch step {
        case .greetingName:
            collected.name = ""
            collected.nameSkipped = false
        case .goal:
            collected.goal = ""
        case .experience:
            collected.experienceLevel = ""
        case .daysPerWeek:
            collected.daysPerWeek = 0
        case .trainingDays:
            collected.trainingDays = []
        case .equipment:
            collected.equipmentAccess = []
        case .injuries, .injuriesCustom:
            collected.injuriesLimitations = nil
        case .gender:
            collected.gender = nil
        case .measurementsAsk:
            collected.measurementsSkip = false
            collected.measurementsSure = false
            resetMeasurementFields()
        case .measurementsInput:
            collected.heightCm = nil
            collected.weightKg = nil
            collected.measurementsSure = false
            resetMeasurementFields()
        default:
            break
        }
    }

    private func trimLastTransition() {
        if messages.last?.role == .assistant,
           !Self.isGeneratingHandoffMessage(messages.last?.content ?? "") {
            messages.removeLast()
        }
        if messages.last?.role == .user {
            messages.removeLast()
        }
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
        if step == .generating || step == .programPreview || isGenerating {
            return true
        }
        if showsStructuredMeasurements {
            return true
        }
        let lastAssistant = messages.last(where: { $0.role == .assistant })?.content ?? ""
        return Self.isGeneratingHandoffMessage(lastAssistant)
    }

    /// Atlas transition copy — not a question; Capacitor hides input and auto-starts generate.
    static func isGeneratingHandoffMessage(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("everything i need")
            || lower.contains("generating your personalized program")
            || lower.contains("generating your program")
            || (lower.contains("got everything") && lower.contains("program"))
    }

    func handleGeneratingHandoffIfNeeded() async {
        guard !isGenerating, step != .generating, step != .programPreview else { return }
        guard let last = messages.last(where: { $0.role == .assistant })?.content else { return }
        guard Self.isGeneratingHandoffMessage(last) else { return }
        if shouldDeferGenerateForMeasurementsGate() {
            step = nextStep(from: collected)
            return
        }
        step = .generating
        await triggerGenerate()
    }

    func configure(session: Session) {
        flow = .onboarding
        userId = session.user.id
        accessToken = session.accessToken
        seedGreetingIfNeeded()
    }

    func configureForProgramBuild(session: Session) async throws {
        flow = .programBuild
        userId = session.user.id
        accessToken = session.accessToken

        let profile: ProfileDetail = try await SupabaseClient.shared
            .from("user_profiles")
            .select()
            .eq("id", value: session.user.id)
            .single()
            .execute()
            .value

        collected = OnboardingChatData.forProgramBuild(from: profile)
        measurementsUseImperial = profile.unitPreference == "imperial"
        step = .goal
        messages = []
        program = nil
        measurementHeightCm = ""
        measurementWeightKg = ""
        didSeedGreeting = true

        appendAssistant(OnboardingMaps.programBuildOpener)
        appendAssistant(OnboardingMaps.programBuildGoalQuestion)
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

        if step == .greetingName, (trimmed.count < 2 || !UserDisplayName.hasRealName(trimmed)), trimmed.lowercased() != "skip" {
            return
        }

        applyNameFromUserMessage(trimmed)

        if showsStructuredMeasurements {
            if matchesSkip(trimmed) {
                await skipMeasurements()
            }
            return
        }

        await sendToAtlas(trimmed)
    }

    func selectChip(_ label: String) async {
        guard !isTyping, !isGenerating else { return }

        if label == "Skip" {
            await handleSkip(for: effectiveChipStep == .none ? step : effectiveChipStep)
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
            if label == "I'll skip this" || label == "Skip" {
                await skipMeasurements()
                return
            }
        }

        await sendToAtlas(label)
    }

    func prepareMeasurementsStep() {
        guard showsStructuredMeasurements else { return }
        if step == .measurementsInput {
            step = .measurementsAsk
        }
        measurementsUseImperial = collected.unitPreference == "imperial"
    }

    func syncMeasurementsUnitPreference() {
        collected.unitPreference = measurementsUseImperial ? "imperial" : "metric"
    }

    func submitMeasurements() async {
        guard let values = resolvedMeasurementValues() else { return }

        collected.heightCm = values.heightCm
        collected.weightKg = values.weightKg
        collected.measurementsSkip = false
        collected.measurementsSure = false
        collected.unitPreference = measurementsUseImperial ? "imperial" : "metric"

        let userText = formattedMeasurementSubmission(heightCm: values.heightCm, weightKg: values.weightKg)
        appendUser(userText)
        step = .generating
        await triggerGenerate()
    }

    func skipMeasurements() async {
        collected.measurementsSkip = true
        appendUser("I'll skip this")
        step = .generating
        await triggerGenerate()
    }

    func completeOnboarding() async throws {
        guard let userId, let program else {
            throw OnboardingError.missingData
        }
        isSaving = true
        defer { isSaving = false }

        if flow == .programBuild {
            try await completeProgramBuild(userId: userId)
            await persistOnboardingMessagesIfNeeded(userId: userId)
            return
        }

        if let token = accessToken, !token.isEmpty {
            let succeeded = await completeViaAPI(userId: userId, token: token)
            if succeeded {
                await persistOnboardingMessagesIfNeeded(userId: userId)
                return
            }
            print("[OnboardingService] complete API failed — falling back to Supabase client")
        }

        try await completeViaSupabase(userId: userId)
        await persistOnboardingMessagesIfNeeded(userId: userId)
    }

    private func completeProgramBuild(userId: UUID) async throws {
        guard program != nil else { throw OnboardingError.missingData }
        try await updateProfile(userId: userId)
        try await upsertProgram(userId: userId)
    }

    /// Completes onboarding with safe defaults and no generated program (header Skip escape hatch).
    func skipOnboarding() async throws {
        guard let userId else { throw OnboardingError.missingData }
        isSkipping = true
        defer { isSkipping = false }

        collected = Self.defaultSkipData(preservingNameFrom: collected)

        if let token = accessToken, !token.isEmpty {
            if await completeSkipViaAPI(token: token) { return }
            print("[OnboardingService] skip complete API failed — falling back to Supabase client")
        }

        try await completeProfileOnlyViaSupabase(userId: userId)
    }

    static func defaultSkipData(preservingNameFrom existing: OnboardingChatData) -> OnboardingChatData {
        var data = OnboardingChatData()
        let trimmedName = existing.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if UserDisplayName.hasRealName(trimmedName) {
            data.name = trimmedName
        } else {
            data.name = ""
            data.nameSkipped = true
        }
        data.goal = "general"
        data.experienceLevel = "beginner"
        data.daysPerWeek = 3
        data.trainingDays = [1, 3, 5]
        data.equipmentAccess = ["full_gym"]
        data.injuriesLimitations = nil
        data.gender = "prefer_not_to_say"
        data.measurementsSkip = true
        return data
    }

    // MARK: - Chat API

    private func sendToAtlas(_ message: String) async {
        isTyping = true
        await Task.yield()
        appendUser(message)
        defer { isTyping = false }

        let history = messages.dropLast().map { ["role": $0.role.rawValue, "content": $0.content] }
        let body: [String: Any] = [
            "message": message,
            "messages": history,
            "collected": collectedPayload(),
            "currentStep": step.rawValue,
            "systemPrompt": Self.systemPrompt,
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
                appendAssistant("Ruu request failed (HTTP \(status)).")
                return
            }

            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                appendAssistant("Ruu returned an unexpected response.")
                return
            }

            let text = json["text"] as? String ?? ""
            let extracted = json["extracted"] as? [String: Any] ?? [:]

            let cleaned = cleanAtlasMessage(text)
            collected = mergeExtracted(collected, extracted: extracted)

            if Self.isGeneratingHandoffMessage(cleaned) {
                if shouldDeferGenerateForMeasurementsGate() {
                    step = nextStep(from: collected)
                    return
                }
                step = .generating
                await triggerGenerate()
                return
            }

            if !cleaned.isEmpty {
                appendAssistant(cleaned)
            }

            let next = nextStep(from: collected)
            step = next
            if next == .generating {
                await triggerGenerate()
            }
        } catch {
            print("[OnboardingService] chat network error: \(error)")
            appendAssistant("Couldn't reach Ruu. Check your connection and try again.")
        }
    }

    private func triggerGenerate() async {
        guard !isGenerating else { return }
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

            let introPrefix = UserDisplayName.hasRealName(collected.name)
                ? "Alright \(UserDisplayName.address(collected.name)),"
                : "Alright —"

            let intro: String
            if hasInjury, let injury {
                intro = "\(introPrefix) based on everything you've told me — here's your Week 1. I've built this around your \(goalLabel), your \(days) training days, and kept your \(injury) in mind throughout. This is just the starting point — we'll adjust as you go, and you can always come back to chat with me anytime."
            } else {
                intro = "\(introPrefix) based on everything you've told me — here's your Week 1. I've built this around your \(goalLabel) and your \(days) training days. This is just the starting point — we'll adjust as you go, and you can always come back to chat with me anytime."
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

    private func completeSkipViaAPI(token: String) async -> Bool {
        let body: [String: Any] = ["data": generatePayload()]
        do {
            let (data, response) = try await postJSON(to: completeURL, body: body, authToken: token)
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let raw = String(data: data, encoding: .utf8) ?? ""
            print("[OnboardingService] POST \(completeURL.absoluteString) (skip)")
            print("[OnboardingService] HTTP status: \(status)")
            print("[OnboardingService] raw response: \(raw)")
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return false
            }
            if parseError(from: data) != nil { return false }
            return true
        } catch {
            print("[OnboardingService] skip complete API error: \(error)")
            return false
        }
    }

    private func completeViaSupabase(userId: UUID) async throws {
        guard let program else { throw OnboardingError.missingData }

        try await insertProfile(userId: userId)

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

    private func completeProfileOnlyViaSupabase(userId: UUID) async throws {
        try await insertProfile(userId: userId)
    }

    private func persistOnboardingMessagesIfNeeded(userId: UUID) async {
        await CoachMessageService.persistOnboardingConversation(
            profileId: userId,
            messages: messages
        )
    }

    private func insertProfile(userId: UUID) async throws {
        let profileInsert = makeProfileInsert(userId: userId)
        print("[OnboardingService] Supabase insert user_profiles: \(profileInsert)")
        try await SupabaseClient.shared
            .from("user_profiles")
            .insert(profileInsert)
            .execute()
    }

    private func updateProfile(userId: UUID) async throws {
        let profileUpdate = makeProfileUpdate()
        print("[OnboardingService] Supabase update user_profiles: \(profileUpdate)")
        try await SupabaseClient.shared
            .from("user_profiles")
            .update(profileUpdate)
            .eq("id", value: userId)
            .execute()
    }

    private func upsertProgram(userId: UUID) async throws {
        guard let program else { throw OnboardingError.missingData }

        struct ExistingProgram: Decodable {
            let id: UUID
        }

        let existing: [ExistingProgram] = try await SupabaseClient.shared
            .from("training_programs")
            .select("id")
            .eq("user_profile_id", value: userId)
            .eq("week_number", value: 1)
            .limit(1)
            .execute()
            .value

        if let programId = existing.first?.id {
            print("[OnboardingService] Supabase update training_programs: \(programId)")
            try await SupabaseClient.shared
                .from("training_programs")
                .update(TrainingProgramContentUpdate(programContent: program))
                .eq("id", value: programId)
                .execute()
        } else {
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
    }

    private func makeProfileInsert(userId: UUID) -> OnboardingProfileInsert {
        let unitPreference = ["metric", "imperial"].contains(collected.unitPreference)
            ? collected.unitPreference
            : "metric"
        let trainingDays = collected.trainingDays.isEmpty ? [1, 3, 5] : collected.trainingDays

        return OnboardingProfileInsert(
            id: userId,
            name: UserDisplayName.normalizedStoredName(collected.name),
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
    }

    private func makeProfileUpdate() -> OnboardingProfileUpdate {
        let unitPreference = ["metric", "imperial"].contains(collected.unitPreference)
            ? collected.unitPreference
            : "metric"
        let trainingDays = collected.trainingDays.isEmpty ? [1, 3, 5] : collected.trainingDays

        return OnboardingProfileUpdate(
            name: UserDisplayName.storedName(from: collected.name),
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
            unitPreference: unitPreference
        )
    }

    // MARK: - Step logic (Capacitor onboarding-chat.tsx)

    /// Gender answered but height/weight not yet collected, skipped, or shown via the structured step.
    private var measurementsNotYetAddressed: Bool {
        !collected.measurementsSkip
            && !(collected.heightCm != nil && collected.weightKg != nil)
            && step != .measurementsAsk
            && step != .measurementsInput
    }

    private func shouldDeferGenerateForMeasurementsGate() -> Bool {
        let genderPresent = collected.gender.map {
            !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        } ?? false
        return genderPresent && measurementsNotYetAddressed
    }

    private func nextStep(from data: OnboardingChatData) -> OnboardingStep {
        if flow == .onboarding,
           !UserDisplayName.hasRealName(data.name),
           !data.nameSkipped {
            return .greetingName
        }
        if data.goal.isEmpty { return .goal }
        if data.experienceLevel.isEmpty { return .experience }
        if data.daysPerWeek < 2 { return .daysPerWeek }
        if data.trainingDays.isEmpty || data.trainingDays.count != data.daysPerWeek { return .trainingDays }
        if data.equipmentAccess.isEmpty { return .equipment }
        if data.injuriesLimitations == nil { return .injuries }
        if data.gender == nil || data.gender!.isEmpty { return .gender }
        if data.measurementsSkip { return .generating }
        if data.heightCm != nil, data.weightKg != nil { return .generating }
        return .measurementsAsk
    }

    private func mergeExtracted(_ data: OnboardingChatData, extracted: [String: Any]) -> OnboardingChatData {
        var next = data
        if let name = extracted["name"] as? String, let stored = UserDisplayName.storedName(from: name) {
            next.name = stored
            next.nameSkipped = false
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
        let text = message.lowercased()

        // Name question — free text only (pinned greeting is display-only; no chips).
        if text.contains("what should i call you")
            || text.contains("what can i call you")
            || text.contains("what do you want me to call you") {
            return .greetingName
        }

        // Gender — including re-ask phrasings.
        if text.contains("male or female")
            || text.contains("your gender")
            || text.contains("need to know your gender")
            || text.contains("are you male")
            || text.contains("are you female")
            || text.contains("identify as")
            || text.contains("pronouns")
            || (text.contains("gender") && (text.contains("male") || text.contains("female") || text.contains("calibrate"))) {
            return .gender
        }

        // Measurements (guarded out of chips at effectiveChipStep, but parsed for completeness).
        if text.contains("measurements")
            || (text.contains("height") && text.contains("weight")) {
            return .measurementsAsk
        }

        // Training days before days-per-week (more specific first).
        if text.contains("which days")
            || text.contains("what days")
            || text.contains("days work best")
            || text.contains("days of the week")
            || text.contains("days would you like to train")
            || text.contains("days do you want to train") {
            return .trainingDays
        }

        if text.contains("how many days")
            || text.contains("days per week")
            || text.contains("days a week")
            || text.contains("realistically train")
            || text.contains("train per week")
            || text.contains("times per week") {
            return .daysPerWeek
        }

        // Injuries — including re-ask and "areas to program around".
        if text.contains("injur")
            || text.contains("limitation")
            || text.contains("program around")
            || text.contains("watch out for")
            || text.contains("areas i should")
            || text.contains("areas to avoid")
            || (text.contains("areas") && text.contains("around"))
            || text.contains("anything i should know about") {
            return .injuries
        }

        // Equipment.
        if text.contains("equipment")
            || text.contains("have access to")
            || text.contains("what do you have access")
            || text.contains("working out at")
            || text.contains("dumbbells")
            || text.contains("barbells")
            || (text.contains("gym") && (text.contains("access") || text.contains("have") || text.contains("equipment"))) {
            return .equipment
        }

        // Experience — including re-ask and conversational phrasings.
        if text.contains("experience level")
            || text.contains("experience with")
            || text.contains("how long have you been lifting")
            || text.contains("how long have you been training")
            || text.contains("been training")
            || text.contains("training history")
            || text.contains("are you a beginner")
            || text.contains("lifting for")
            || text.contains("how experienced")
            || text.contains("new to lifting")
            || text.contains("new to training")
            || (text.contains("beginner") && text.contains("advanced"))
            || (text.contains("beginner") && text.contains("intermediate"))
            || (text.contains("experience") && text.contains("training")) {
            return .experience
        }

        // Goal.
        if text.contains("training goal")
            || text.contains("primary goal")
            || text.contains("what's your goal")
            || text.contains("what is your goal")
            || text.contains("looking to achieve")
            || text.contains("what are you training for")
            || text.contains("main goal")
            || (text.contains("goal") && (text.contains("primary") || text.contains("training") || text.contains("fitness"))) {
            return .goal
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
            updated.name = ""
            updated.nameSkipped = true
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
        collected = updated
        let next = nextStep(from: updated)
        step = next

        let ack: String
        switch stepKey {
        case .greetingName:
            ack = "No problem. What's your primary training goal?"
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
            ack = ""
        default:
            ack = "Moving on..."
        }

        if next != .generating, !ack.isEmpty {
            appendAssistant(ack)
        }
        if next == .generating {
            await triggerGenerate()
        }
    }

    // MARK: - Helpers

    private func resetMeasurementFields() {
        measurementHeightCm = ""
        measurementWeightKg = ""
        measurementHeightFeet = ""
        measurementHeightInches = ""
        measurementWeightLbs = ""
    }

    private func resolvedMeasurementValues() -> (heightCm: Double, weightKg: Double)? {
        if measurementsUseImperial {
            let feetText = measurementHeightFeet.trimmingCharacters(in: .whitespacesAndNewlines)
            let inchesText = measurementHeightInches.trimmingCharacters(in: .whitespacesAndNewlines)
            let lbsText = measurementWeightLbs.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let feet = Int(feetText), feet >= 0,
                  let inches = Int(inchesText), inches >= 0, inches <= 11,
                  let lbs = Double(lbsText), lbs > 0
            else { return nil }

            let totalInches = Double(feet * 12 + inches)
            guard totalInches > 0 else { return nil }

            let heightCm = (totalInches * 2.54 * 10).rounded() / 10
            let weightKg = (lbs / 2.20462 * 10).rounded() / 10
            return (heightCm, weightKg)
        }

        let cmText = measurementHeightCm.trimmingCharacters(in: .whitespacesAndNewlines)
        let kgText = measurementWeightKg.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let cm = Double(cmText), cm > 0,
              let kg = Double(kgText), kg > 0
        else { return nil }

        return ((cm * 10).rounded() / 10, (kg * 10).rounded() / 10)
    }

    private func formattedMeasurementSubmission(heightCm: Double, weightKg: Double) -> String {
        let height = Self.formatMeasurementNumber(heightCm)
        let weight = Self.formatMeasurementNumber(weightKg)
        return "Height: \(height) cm, Weight: \(weight) kg"
    }

    private static func formatMeasurementNumber(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

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

    private func applyNameFromUserMessage(_ text: String) {
        if step == .greetingName,
           text.lowercased() != "skip",
           let stored = UserDisplayName.storedName(from: text) {
            collected.name = stored
            collected.nameSkipped = false
            return
        }

        if let extracted = UserDisplayName.extractFromMessage(text) {
            collected.name = extracted
            collected.nameSkipped = false
        }
    }

    private func matchesSkip(_ text: String) -> Bool {
        text.range(of: #"skip|no|pass|i'll skip"#, options: [.regularExpression, .caseInsensitive]) != nil
    }

    private func collectedPayload() -> [String: Any] {
        var payload: [String: Any] = [
            "goal": collected.goal,
            "experienceLevel": collected.experienceLevel,
            "daysPerWeek": collected.daysPerWeek,
            "trainingDays": collected.trainingDays,
            "equipmentAccess": collected.equipmentAccess,
            "unitPreference": collected.unitPreference,
        ]
        if let name = UserDisplayName.storedName(from: collected.name) {
            payload["name"] = name
        }
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

private struct OnboardingProfileUpdate: Encodable {
    let name: String?
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

    enum CodingKeys: String, CodingKey {
        case name, goal
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

private struct TrainingProgramContentUpdate: Encodable {
    let programContent: OnboardingProgramPayload

    enum CodingKeys: String, CodingKey {
        case programContent = "program_content"
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
