import SwiftUI

// MARK: - Palette

/// Colours sampled from the notes-v4 HTML prototype so the note / first flows
/// match the design exactly.
enum PreludePalette {
    static let noteBackground   = Color(red: 240 / 255, green: 230 / 255, blue: 216 / 255) // #F0E6D8
    static let promptBrown      = Color(red: 135 / 255, green: 108 / 255, blue: 81 / 255)  // #876C51
    static let textAreaFill     = Color(red: 220 / 255, green: 208 / 255, blue: 195 / 255) // #DCD0C3
    static let bodyText         = Color(red: 61 / 255, green: 53 / 255, blue: 48 / 255)    // #3D3530
    static let placeholderInk   = Color(red: 176 / 255, green: 163 / 255, blue: 153 / 255) // #B0A399
    static let promptChipBorder = Color(red: 184 / 255, green: 169 / 255, blue: 154 / 255) // #B8A99A
    static let promptChipText   = Color(red: 78 / 255, green: 62 / 255, blue: 52 / 255)    // #4E3E34
    static let optionalItalic   = Color(red: 168 / 255, green: 144 / 255, blue: 128 / 255) // #A89080

    static let sheetBackground  = Color(red: 251 / 255, green: 245 / 255, blue: 237 / 255) // #FBF5ED
    static let sectionLabel     = Color(red: 58 / 255, green: 49 / 255, blue: 40 / 255)    // #3A3128
    static let optionFill       = Color(red: 181 / 255, green: 163 / 255, blue: 143 / 255) // #B5A38F
    static let optionInk        = Color(red: 82 / 255, green: 58 / 255, blue: 39 / 255)    // #523A27
    static let optionPicked     = Color(red: 68 / 255, green: 43 / 255, blue: 24 / 255)    // #442B18
    static let optionPickedInk  = Color(red: 242 / 255, green: 237 / 255, blue: 230 / 255) // #F2EDE6
    static let generateBorder   = Color(red: 180 / 255, green: 154 / 255, blue: 128 / 255) // #B49A80
    static let generateFill     = Color(red: 235 / 255, green: 228 / 255, blue: 220 / 255) // #EBE4DC
    static let generateInk      = Color(red: 124 / 255, green: 101 / 255, blue: 81 / 255)  // #7C6551
    static let orPickInk        = Color(red: 148 / 255, green: 140 / 255, blue: 130 / 255) // #948C82
    static let dashedBorder     = Color(red: 128 / 255, green: 128 / 255, blue: 128 / 255) // #808080
    static let focusBlue        = Color(red: 59 / 255, green: 156 / 255, blue: 255 / 255)  // #3B9CFF
    static let dateInk          = Color(red: 20 / 255, green: 17 / 255, blue: 15 / 255)    // #14110F
    static let dateYearInk      = Color(red: 124 / 255, green: 118 / 255, blue: 111 / 255) // #7C766F
    static let dateHintInk      = Color(red: 110 / 255, green: 104 / 255, blue: 98 / 255)  // #6E6862

    static let calendarBorder   = Color(red: 217 / 255, green: 217 / 255, blue: 217 / 255) // #D9D9D9
    static let calendarDayInk   = Color(red: 47 / 255, green: 47 / 255, blue: 47 / 255)    // #2F2F2F
    static let calendarMutedInk = Color(red: 199 / 255, green: 199 / 255, blue: 199 / 255) // #C7C7C7
    static let calendarDOWInk   = Color(red: 138 / 255, green: 138 / 255, blue: 138 / 255) // #8A8A8A
    static let calendarSelected = Color(red: 44 / 255, green: 44 / 255, blue: 44 / 255)    // #2C2C2C

    static let monthPink        = Color(red: 245 / 255, green: 130 / 255, blue: 152 / 255) // #F58298
    static let monthSelected    = Color(red: 240 / 255, green: 47 / 255, blue: 82 / 255)   // #F02F52

    // Voice memo + Reason, sampled from the notesv6 prototype.
    static let voiceHeading     = Color(red: 68 / 255, green: 43 / 255, blue: 24 / 255)    // #442B18
    static let voiceCopy        = Color(red: 105 / 255, green: 83 / 255, blue: 67 / 255)   // #695343
    static let wavePink         = Color(red: 245 / 255, green: 146 / 255, blue: 159 / 255) // #F5929F
    static let timerInk         = Color(red: 89 / 255, green: 89 / 255, blue: 89 / 255)    // #595959
    static let captionInk       = Color(red: 108 / 255, green: 108 / 255, blue: 108 / 255) // #6C6C6C
    static let recordRed        = Color(red: 234 / 255, green: 49 / 255, blue: 85 / 255)   // #EA3155
    static let savedRed         = Color(red: 240 / 255, green: 47 / 255, blue: 82 / 255)   // #F02F52
    static let rerecordInk      = Color(red: 113 / 255, green: 113 / 255, blue: 113 / 255) // #717171
    static let reasonInk        = Color(red: 46 / 255, green: 41 / 255, blue: 38 / 255)    // #2E2926
    static let reasonPlaceholder = Color(red: 141 / 255, green: 129 / 255, blue: 119 / 255) // #8D8177
    static let paperclipSteel   = Color(red: 173 / 255, green: 171 / 255, blue: 168 / 255) // #ADABA8
}

// MARK: - Taped prompt bar

/// The brown prompt bar used by the Reason and Voice Memo sheets: a flat
/// rectangle with 4pt corners, text vertically centred and left aligned to one
/// line, with the washi tape layered in front of its top edge.
struct PreludeTapedPromptBar: View {
    let text: String
    var barHeight: CGFloat = 38
    var tapeWidth: CGFloat = 56
    /// How far the tape rises above the bar.
    var tapeOverhang: CGFloat = 9

    var body: some View {
        ZStack(alignment: .top) {
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 15)
                .frame(height: barHeight)
                .background(
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(PreludePalette.promptBrown)
                )
                .padding(.top, tapeOverhang)

            WashiTapeStrip(width: tapeWidth)
        }
    }
}

// MARK: - Paperclip

/// Paperclip outline pinned over the top-left corner of the Reason field.
struct PreludePaperclip: View {
    var body: some View {
        ZStack {
            clipPath
                .stroke(PreludePalette.paperclipSteel,
                        style: StrokeStyle(lineWidth: 1.7, lineCap: .round))
            clipPath
                .stroke(.white, style: StrokeStyle(lineWidth: 0.6, lineCap: .round))
                .offset(x: -0.55, y: -0.45)
                .opacity(0.85)
        }
        .frame(width: 19, height: 48)
        .rotationEffect(.degrees(-7))
        .allowsHitTesting(false)
    }

    /// Same geometry as the prototype's SVG path. The two caps are drawn as
    /// cubic curves rather than addArc, whose `clockwise` flag is ambiguous in
    /// SwiftUI's y-down space — these bow the way they are written.
    private var clipPath: Path {
        var p = Path()
        // Inner leg, bottom to top.
        p.move(to: CGPoint(x: 12.6, y: 33))
        p.addLine(to: CGPoint(x: 12.6, y: 11))
        // Cap over the top, bulging up (r 4.3).
        p.addCurve(to: CGPoint(x: 4, y: 11),
                   control1: CGPoint(x: 12.6, y: 11 - 5.73),
                   control2: CGPoint(x: 4, y: 11 - 5.73))
        // Outer leg, top to bottom.
        p.addLine(to: CGPoint(x: 4, y: 37.5))
        // Cap under the bottom, bulging down (r 5.7).
        p.addCurve(to: CGPoint(x: 15.4, y: 37.5),
                   control1: CGPoint(x: 4, y: 37.5 + 7.6),
                   control2: CGPoint(x: 15.4, y: 37.5 + 7.6))
        // Tallest leg back up.
        p.addLine(to: CGPoint(x: 15.4, y: 7.5))
        return p
    }
}

// MARK: - Recording bar

/// The live recording bar. Six pink bars sit at their resting heights until
/// `isLive`, then re-randomise around those heights on a short timer, which is
/// what makes the bar read as listening.
struct PreludeWaveBars: View {
    var isLive: Bool

    private static let restHeights: [CGFloat] = [10, 26, 42, 21, 33, 14]
    private static let step: TimeInterval = 0.11

    var body: some View {
        // TimelineView drives this, not a Timer held in the struct: the parent
        // re-evaluates its body ten times a second while the clock runs, which
        // would keep restarting a stored timer before it ever fired.
        TimelineView(.periodic(from: .now, by: Self.step)) { context in
            HStack(alignment: .center, spacing: 9) {
                ForEach(Self.restHeights.indices, id: \.self) { i in
                    Capsule()
                        .fill(PreludePalette.wavePink)
                        .frame(width: 4.5,
                               height: height(bar: i, at: context.date))
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: 42)
    }

    /// Resting shape until live, then deterministic per-bar noise so every tick
    /// lands somewhere new without needing stored state.
    private func height(bar i: Int, at date: Date) -> CGFloat {
        let base = Self.restHeights[i]
        guard isLive else { return base }
        let tick = (date.timeIntervalSinceReferenceDate / Self.step).rounded(.down)
        let raw = sin(tick * 12.9898 + Double(i) * 78.233) * 43758.5453
        let noise = raw - raw.rounded(.down)            // 0 ..< 1
        return min(42, max(6, base * CGFloat(0.45 + noise * 1.1)))
    }
}

// MARK: - Washi tape

/// The washi-tape strip that sits in front of the prompt bar / option cards.
struct WashiTapeStrip: View {
    var width: CGFloat = 86

    var body: some View {
        Image("note_washi_tape")
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: width)
            .rotationEffect(.degrees(-1))
            .shadow(color: .black.opacity(0.16), radius: 1, x: 0, y: 1)
            .allowsHitTesting(false)
    }
}

// MARK: - Polaroid photo well

/// Polaroid frame from the design. The dark interior and the "+" are part of the
/// artwork, so an empty well is just the image; a chosen photo is inset into it.
struct PolaroidPhotoWell: View {
    let image: UIImage?
    var onTap: () -> Void
    var onRemove: () -> Void

    private let frameWidth: CGFloat = 125
    private let frameHeight: CGFloat = 152

    // The grey window inside the polaroid artwork, measured off the PNG:
    // a 113x113 square whose top-left corner sits at (6, 9) in the 125x152 art.
    // An uploaded photo fills exactly this square, edge to edge.
    private let wellSize: CGFloat = 113
    private let wellX: CGFloat = 6
    private let wellY: CGFloat = 9

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image("note_polaroid_frame")
                .resizable()
                .interpolation(.high)
                .frame(width: frameWidth, height: frameHeight)
                .overlay(alignment: .topLeading) {
                    if let image {
                        // Color.clear pins the well's exact size; the photo is
                        // drawn as an overlay on it so it is handed that size
                        // directly, fills it, and anything past the edges is
                        // clipped away. Nothing of the grey square shows.
                        Color.clear
                            .frame(width: wellSize, height: wellSize)
                            .overlay {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            }
                            .clipped()
                            .padding(.leading, wellX)
                            .padding(.top, wellY)
                    }
                }
                .frame(width: frameWidth, height: frameHeight, alignment: .topLeading)
                .contentShape(Rectangle())
                .onTapGesture { onTap() }

            if image != nil {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(.black.opacity(0.52)))
                }
                .buttonStyle(.plain)
                .padding(.top, 3)
                .padding(.trailing, 3)
                .accessibilityLabel("Remove photo")
            }
        }
        .frame(width: frameWidth, height: frameHeight, alignment: .topLeading)
    }
}

// MARK: - Inline calendar

/// Month grid used by the "Our First" editor. Metrics are taken from the
/// reference calendar: 30pt dropdowns, 41pt cells, 39x40 selection chip.
/// It lives in the normal layout flow — opening it pushes the content below
/// it down rather than covering it.
struct PreludeInlineCalendar: View {
    @Binding var month: Int          // 0-11
    @Binding var year: Int
    @Binding var selection: Date

    private static let monthNames = [
        "January", "February", "March", "April", "May", "June",
        "July", "August", "September", "October", "November", "December"
    ]
    private static let weekdayInitials = ["S", "M", "T", "W", "T", "F", "S"]

    private let cellHeight: CGFloat = 41
    private let selectionWidth: CGFloat = 39
    private let selectionHeight: CGFloat = 40
    private let dropdownHeight: CGFloat = 30
    private let monthWidth: CGFloat = 91
    private let yearWidth: CGFloat = 90

    private var years: [Int] {
        let current = Calendar.current.component(.year, from: Date())
        return Array((current - 10)...(current + 10))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 15)

            weekdayRow
                .padding(.bottom, 4)

            grid
        }
        .padding(.top, 19)
        .padding(.horizontal, 26)
        .padding(.bottom, 33)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(PreludePalette.calendarBorder, lineWidth: 1)
                )
        )
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 16) {
            Menu {
                Picker("Month", selection: $month) {
                    ForEach(0..<12, id: \.self) { i in
                        Text(Self.monthNames[i]).tag(i)
                    }
                }
            } label: {
                dropdownLabel(Self.monthNames[month], width: monthWidth)
            }

            Menu {
                Picker("Year", selection: $year) {
                    ForEach(years, id: \.self) { y in
                        Text(String(y)).tag(y)
                    }
                }
            } label: {
                dropdownLabel(String(year), width: yearWidth)
            }

            Spacer(minLength: 0)
        }
    }

    private func dropdownLabel(_ text: String, width: CGFloat) -> some View {
        HStack(spacing: 6) {
            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(PreludePalette.dateInk)
            Spacer(minLength: 0)
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(PreludePalette.calendarDOWInk)
        }
        .padding(.horizontal, 10)
        .frame(width: width, height: dropdownHeight)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(PreludePalette.calendarBorder, lineWidth: 1)
        )
    }

    // MARK: Grid

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Self.weekdayInitials.indices, id: \.self) { i in
                Text(Self.weekdayInitials[i])
                    .font(.system(size: 12))
                    .foregroundStyle(PreludePalette.calendarDOWInk)
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(height: 24)
    }

    private var grid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
                  spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                if let day {
                    dayCell(day)
                } else {
                    Color.clear.frame(height: cellHeight)
                }
            }
        }
    }

    private func dayCell(_ day: Int) -> some View {
        let picked = isSelected(day)
        return Text(String(day))
            .font(.system(size: 14))
            .foregroundStyle(picked ? .white : PreludePalette.calendarDayInk)
            .frame(width: selectionWidth, height: selectionHeight)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(picked ? PreludePalette.calendarSelected : .clear)
            )
            .frame(maxWidth: .infinity, minHeight: cellHeight)
            .contentShape(Rectangle())
            .onTapGesture { pick(day) }
    }

    // MARK: Dates

    /// Leading nils pad the first row out to the correct weekday.
    private var cells: [Int?] {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        guard let first = cal.date(from: DateComponents(year: year, month: month + 1, day: 1)),
              let range = cal.range(of: .day, in: .month, for: first)
        else { return [] }
        let leading = cal.component(.weekday, from: first) - 1
        let pad: [Int?] = Array(repeating: nil, count: leading)
        let days: [Int?] = range.map { Optional($0) }
        return pad + days
    }

    private func isSelected(_ day: Int) -> Bool {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: selection)
        return c.year == year && c.month == month + 1 && c.day == day
    }

    private func pick(_ day: Int) {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1
        if let d = cal.date(from: DateComponents(year: year, month: month + 1, day: day)) {
            selection = d
        }
    }
}

// MARK: - Gift flow

/// Colours sampled from the "Your Gift" mock.
extension PreludePalette {
    static let giftTileSubtitle = Color(red: 100 / 255, green: 98 / 255, blue: 95 / 255)   // #64625F
}
