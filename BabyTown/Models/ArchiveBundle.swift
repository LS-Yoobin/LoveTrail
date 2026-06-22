import Foundation
import GardenCore

struct ArchiveBundle: Codable {
    let coupleId: String
    let breakupDate: Date
    var expiryDate: Date
    var userASteppedOut: Bool
    var userBSteppedOut: Bool
    var moments: [Moment]
    var coupleProfile: CoupleProfile
    var petState: PetState
    var gardenState: GardenState
    var playlist: [CouplePlaylistTrack]
    var preludeChapter: PreludeChapter?

    init(
        coupleId: String,
        breakupDate: Date,
        expiryDate: Date,
        userASteppedOut: Bool = false,
        userBSteppedOut: Bool = false,
        moments: [Moment] = [],
        coupleProfile: CoupleProfile = CoupleProfile(),
        petState: PetState = PetState(),
        gardenState: GardenState = GardenState(),
        playlist: [CouplePlaylistTrack] = [],
        preludeChapter: PreludeChapter? = nil
    ) {
        self.coupleId = coupleId
        self.breakupDate = breakupDate
        self.expiryDate = expiryDate
        self.userASteppedOut = userASteppedOut
        self.userBSteppedOut = userBSteppedOut
        self.moments = moments
        self.coupleProfile = coupleProfile
        self.petState = petState
        self.gardenState = gardenState
        self.playlist = playlist
        self.preludeChapter = preludeChapter
    }

    enum CodingKeys: String, CodingKey {
        case coupleId, breakupDate, expiryDate
        case userASteppedOut, userBSteppedOut
        case moments, coupleProfile, petState, gardenState, playlist, preludeChapter
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        coupleId = try c.decode(String.self, forKey: .coupleId)
        breakupDate = try c.decode(Date.self, forKey: .breakupDate)
        expiryDate = try c.decode(Date.self, forKey: .expiryDate)
        userASteppedOut = try c.decodeIfPresent(Bool.self, forKey: .userASteppedOut) ?? false
        userBSteppedOut = try c.decodeIfPresent(Bool.self, forKey: .userBSteppedOut) ?? false
        moments = try c.decodeIfPresent([Moment].self, forKey: .moments) ?? []
        coupleProfile = try c.decodeIfPresent(CoupleProfile.self, forKey: .coupleProfile) ?? CoupleProfile()
        petState = try c.decodeIfPresent(PetState.self, forKey: .petState) ?? PetState()
        gardenState = try c.decodeIfPresent(GardenState.self, forKey: .gardenState) ?? GardenState()
        playlist = try c.decodeIfPresent([CouplePlaylistTrack].self, forKey: .playlist) ?? []
        preludeChapter = try c.decodeIfPresent(PreludeChapter.self, forKey: .preludeChapter)
    }
}
