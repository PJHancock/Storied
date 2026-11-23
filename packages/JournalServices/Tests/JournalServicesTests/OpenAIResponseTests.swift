import Foundation
import Testing
@testable import JournalServices

@Suite struct OpenAIResponseTests {
    @Test func joinsCompletedTextParts() throws {
        let data = Data(#"{"status":"completed","output":[{"type":"reasoning"},{"type":"message","content":[{"type":"output_text","text":"first"},{"type":"output_text","text":"second"}]}]}"#.utf8)
        #expect(try OpenAISummaryProvider.outputText(from: data) == "firstsecond")
    }
    @Test func rejectsTruncatedOutputEvenWhenTextExists() throws {
        let data = Data(#"{"status":"incomplete","incomplete_details":{"reason":"max_output_tokens"},"output":[{"type":"message","content":[{"type":"output_text","text":"partial"}]}]}"#.utf8)
        do {
            _ = try OpenAISummaryProvider.outputText(from: data)
            Issue.record("Truncated output must be rejected")
        } catch let error as ServiceError { #expect(error.code == "output_limit") }
    }
    @Test func distinguishesRefusalFromMissingText() throws {
        let data = Data(#"{"status":"completed","output":[{"type":"message","content":[{"type":"refusal","refusal":"declined"}]}]}"#.utf8)
        do {
            _ = try OpenAISummaryProvider.outputText(from: data)
            Issue.record("Refusal must be surfaced")
        } catch let error as ServiceError { #expect(error.code == "refusal") }
    }
}
