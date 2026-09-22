import FoundationModels
import Observation

/// Which AI capabilities are available right now (spec §5 — Device & Model
/// Eligibility Matrix).
enum AIEligibilityTier: Equatable {
    case unavailable(reason: String)
    case textOnly
    case fullMultimodal

    var isUsable: Bool {
        switch self {
        case .unavailable: return false
        case .textOnly, .fullMultimodal: return true
        }
    }
}

@Observable
final class AIEligibilityChecker {
    private(set) var tier: AIEligibilityTier = .unavailable(reason: "Checking…")
    private(set) var privateCloudComputeAvailable = false

    /// Use this model for the tagging/summarization flow — it's Apple's
    /// adapter tuned for tagging and extraction, not open-ended chat.
    let taggingModel = SystemLanguageModel(useCase: .contentTagging)

    func refresh() {
        switch taggingModel.availability {
        case .available:
            tier = .textOnly
            checkMultimodalSupport()
        case .unavailable(let reason):
            tier = .unavailable(reason: describe(reason))
        }

        privateCloudComputeAvailable = PrivateCloudComputeLanguageModel().isAvailable
    }

    private func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Apple Intelligence is off — enable it in Settings."
        case .modelNotReady:
            return "The on-device model is still downloading."
        @unknown default:
            return "AI features aren't available right now."
        }
    }

    /// Placeholder — upgrades `tier` to `.fullMultimodal` once image-input
    /// capability is confirmed for this device. See the note inside.
    private func checkMultimodalSupport() {
        // Honest flag: as of this writing (weeks after multimodal image
        // input shipped), the sources this spec was built from don't
        // confirm a dedicated capability flag for "does THIS tier accept
        // image input." Two options — pick one after checking the current
        // FoundationModels docs in Xcode:
        //   1. Apple exposes a real capability property — swap it in here
        //      (check Xcode Quick Help on SystemLanguageModel / UseCase for
        //      anything like "supportedModalities").
        //   2. If nothing exists yet: attempt one real multimodal request
        //      behind a do/catch the first time a photo is attached, set
        //      `tier = .fullMultimodal` if it succeeds, leave it at
        //      `.textOnly` if it throws. Cache the result for the session
        //      so you're not re-probing on every entry.
        // `tier` stays at the conservative `.textOnly` default until this
        // is verified against the live SDK.
    }
}

// MARK: - Context budget / long-entry handling (spec §1.2)

extension AIEligibilityChecker {
    /// Rough estimate — good enough for a soft UI warning, not for billing.
    /// ~4 characters per token is the usual back-of-envelope figure for English.
    func estimatedTokenCount(for text: String) -> Int {
        max(1, text.count / 4)
    }

    /// True when an entry is long enough that the on-device context window
    /// probably can't hold it, AND the user has opted into the PCC fallback
    /// in Settings (spec §1.6 — this must stay opt-in, default off).
    func shouldOfferEnhancedProcessing(for entryText: String) -> Bool {
        estimatedTokenCount(for: entryText) > taggingModel.contextSize
            && privateCloudComputeAvailable
    }
}

// MARK: - Generating tags + summary

@Generable
struct EntryAISuggestions {
    let oneLineSummary: String
    let suggestedTags: [String]
}

enum AIGenerationError: Error {
    case unavailable
}

func generateSuggestions(
    for entryText: String,
    checker: AIEligibilityChecker,
    useEnhancedProcessing: Bool
) async throws -> EntryAISuggestions {
    guard checker.tier.isUsable else {
        throw AIGenerationError.unavailable
    }

    let session = useEnhancedProcessing
        ? LanguageModelSession(model: PrivateCloudComputeLanguageModel())
        : LanguageModelSession(model: checker.taggingModel)

    return try await session.respond(
        to: "Summarize this journal entry in one sentence and suggest 2-4 topic tags: \(entryText)",
        generating: EntryAISuggestions.self
    ).content
}
