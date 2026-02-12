import Foundation
import Combine

final class JinkyPromptGenerator: ObservableObject {
    
    private let romanticPrompts: [String] = [
        "Find a photo where you felt safest with me",
        "Pick a moment that made you laugh so hard you forgot the world",
        "Choose a picture that feels like home",
        "Show me our favorite kind of ordinary day",
        "Find the moment when you knew we were something special",
        "Pick a photo that captures how you feel when we're together",
        "Show me a memory that still makes your heart skip",
        "Choose the day that changed everything for us",
        "Find a moment where time stood still",
        "Pick a photo that shows what love looks like to you",
        "Show me when you felt most yourself with me",
        "Choose a memory that makes you smile every time",
        "Find the moment you realized I was your person",
        "Pick a photo that captures our kind of magic",
        "Show me a day that felt like forever",
        "Choose a moment when everything felt right",
        "Find a photo that shows how we make each other better",
        "Pick a memory that proves soulmates are real",
        "Show me the moment you knew you were loved",
        "Choose a photo that captures our perfect imperfect",
        "Find a day when we were just us, nothing else mattered",
        "Pick a moment that shows why we work",
        "Show me when you felt most alive with me",
        "Choose a photo that makes you grateful for us",
        "Find a memory that shows our favorite way to be together",
        "Pick a moment that reminds you why you chose me",
        "Show me a photo that captures our adventure",
        "Choose a day that felt like a dream come true",
        "Find a moment when words weren't needed",
        "Pick a photo that shows what forever looks like"
    ]
    
    private var usedPrompts: Set<String> = []
    
    func getPromptOfTheDay(date: Date = Date()) -> PromptItem {
        let calendar = Calendar.current
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let index = dayOfYear % romanticPrompts.count
        let promptText = romanticPrompts[index]
        usedPrompts.insert(promptText)
        return PromptItem(text: promptText)
    }
    
    func getThreeAlternatives(excluding: PromptItem? = nil) -> [PromptItem] {
        var availablePrompts = romanticPrompts.filter { prompt in
            if let excluding = excluding {
                return prompt != excluding.text && !usedPrompts.contains(prompt)
            }
            return !usedPrompts.contains(prompt)
        }
        
        if availablePrompts.isEmpty {
            usedPrompts.removeAll()
            availablePrompts = romanticPrompts
        }
        
        availablePrompts.shuffle()
        let selected = Array(availablePrompts.prefix(3))
        selected.forEach { usedPrompts.insert($0) }
        
        return selected.map { PromptItem(text: $0) }
    }
    
    func resetUsedPrompts() {
        usedPrompts.removeAll()
    }
}
