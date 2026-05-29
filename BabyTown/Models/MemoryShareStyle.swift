/// Fixed decoration assets for memory share exports.
///
/// Feed cards rotate `cat_variant_1`…`cat_variant_5` by list index; share output always
/// uses this style so every exported image matches the Welcome letter mascots.
enum MemoryShareStyle {

    /// Two-cat mascot below the letter (`First Page Cat` imageset).
    static let heroCatAssetName = "First Page Cat"

    /// Tape-style corner icons on the white letter card — identical on every share.
    static let letterCornerStickers = BabyTownLetterCardStyle.welcomeLetterCornerStickers
}
