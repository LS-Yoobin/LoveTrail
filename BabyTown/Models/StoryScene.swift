import Foundation

struct StoryScene: Identifiable {
    let id: Int
    let title: String
    let subtitle: String?
    let storyText: String
    let ctaText: String
    let interactionType: InteractionType
    
    enum InteractionType {
        case concertLight
        case phoneCall
        case checklist
        case mapNavigate
        case heartTrail
    }
}

extension StoryScene {
    static let allScenes: [StoryScene] = [
        StoryScene(
            id: 1,
            title: "Oct 28, 2023",
            subtitle: "Shoreline Amphitheatre, Mountain View",
            storyText: "Trish and Yoobin's story begins at the Chainsmokers event.",
            ctaText: "Concert Lights",
            interactionType: .concertLight
        ),
        StoryScene(
            id: 2,
            title: "The Unexpected Call",
            subtitle: nil,
            storyText: "On the highway with major car trouble, Trish called someone she'd never met.",
            ctaText: "Answer the call",
            interactionType: .phoneCall
        ),
        StoryScene(
            id: 3,
            title: "Knight in Pajamas",
            subtitle: nil,
            storyText: "Yoobin burst out of bed, grabbed his tools, and rushed into the night.",
            ctaText: "Ride into the night",
            interactionType: .checklist
        ),
        StoryScene(
            id: 4,
            title: "Daddy Rescue",
            subtitle: nil,
            storyText: "Her dad was closer and got her to safety first.",
            ctaText: "We're safe",
            interactionType: .mapNavigate
        ),
        StoryScene(
            id: 5,
            title: "The Best Night",
            subtitle: nil,
            storyText: "Yoobin finally met Trish and had the best night of his life in Mountain View.",
            ctaText: "Save our memories",
            interactionType: .heartTrail
        )
    ]
}
