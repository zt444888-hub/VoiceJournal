import Foundation

struct DailyPrompt {
    private static let prompts: [String] = [
        "What are you grateful for today?",
        "What was the best moment of your day?",
        "What challenged you today?",
        "If you could relive one moment today, which would it be?",
        "What did you learn today?",
        "How are you feeling right now?",
        "Who made a difference in your day?",
        "What are you looking forward to tomorrow?",
        "What's something small that made you smile?",
        "Describe your day in three words.",
        "What would you do differently if you could?",
        "What's on your mind that you haven't said out loud?",
        "What energy are you bringing into tomorrow?",
        "What's a win from today, no matter how small?",
        "If today had a color, what would it be and why?"
    ]
    
    static func todayPrompt() -> String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return prompts[(dayOfYear - 1) % prompts.count]
    }
}
