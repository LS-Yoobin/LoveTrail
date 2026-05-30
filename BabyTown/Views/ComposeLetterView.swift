import SwiftUI

struct ComposeLetterView: View {

    @Environment(\.dismiss) private var dismiss

    @State private var letterTitle = ""
    @State private var letterBody = ""
    @State private var showLetter = false
    @State private var iconPulse = false
    @State private var showScheduleSheet = false
    @State private var scheduledDate = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
    @FocusState private var focusedField: Field?

    private enum Field {
        case title
        case body
    }

    var body: some View {
        ZStack {
            BabyTownTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.top, 8)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        letterCard
                            .padding(.horizontal, 20)
                            .padding(.top, 16)

                        Image("First Page Cat")
                            .resizable()
                            .scaledToFit()
                            .padding(.horizontal, 40)
                            .padding(.top, 8)
                            .padding(.bottom, 120)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomActionBar
        }
        .sheet(isPresented: $showScheduleSheet) {
            scheduleSheet
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                showLetter = true
            }
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                iconPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                focusedField = .title
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.3))
            }

            Spacer()

            Image(systemName: "envelope.fill")
                .font(.system(size: 20))
                .foregroundStyle(BabyTownTheme.accent)
                .scaleEffect(iconPulse ? 1.15 : 1.0)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    // MARK: - Letter Card

    private var letterCard: some View {
        BabyTownLetterCardStyle.letterChrome(
            cornerRadius: 20,
            canvasWidth: BabyTownLetterCardStyle.referenceCanvasWidth
        ) {
            VStack(alignment: .leading, spacing: 16) {
                ZStack(alignment: .leading) {
                    if letterTitle.isEmpty {
                        Text("Letter Title")
                            .font(.system(size: 22, weight: .bold, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.48))
                    }

                    TextField("", text: $letterTitle)
                        .font(.system(size: 22, weight: .bold, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary)
                        .focused($focusedField, equals: .title)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .body
                        }
                }

                Rectangle()
                    .fill(BabyTownTheme.accent.opacity(0.3))
                    .frame(height: 1)

                ZStack(alignment: .topLeading) {
                    if letterBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Start writing your letter...")
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.35))
                            .padding(.top, 8)
                    }

                    TextEditor(text: $letterBody)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .foregroundStyle(BabyTownTheme.textPrimary.opacity(0.8))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 220)
                        .focused($focusedField, equals: .body)
                }
            }
            .padding(28)
        }
        .scaleEffect(showLetter ? 1.0 : 0.9)
        .opacity(showLetter ? 1.0 : 0.0)
    }

    // MARK: - Bottom Actions

    private var bottomActionBar: some View {
        HStack {
            Button {
                showScheduleSheet = true
            } label: {
                Text("Schedule")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(Color.black.opacity(0.55))
                    )
            }
            .disabled(!canSaveLetter)
            .opacity(canSaveLetter ? 1 : 0.45)

            Spacer()

            Button {
                sendLetter(scheduledFor: nil)
            } label: {
                Text("Send")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(BabyTownTheme.accentGradient)
                    )
            }
            .disabled(!canSaveLetter)
            .opacity(canSaveLetter ? 1 : 0.45)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(
            BabyTownTheme.backgroundGradient
                .opacity(0.95)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var scheduleSheet: some View {
        NavigationStack {
            VStack(spacing: 20) {
                DatePicker(
                    "Deliver on",
                    selection: $scheduledDate,
                    in: Date()...,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal, 16)

                Spacer()
            }
            .padding(.top, 8)
            .navigationTitle("Schedule Letter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showScheduleSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        sendLetter(scheduledFor: scheduledDate)
                        showScheduleSheet = false
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSaveLetter)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canSaveLetter: Bool {
        !letterBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendLetter(scheduledFor: Date?) {
        guard canSaveLetter else { return }

        let letter = UserLetter(
            id: UUID(),
            title: letterTitle,
            body: letterBody.trimmingCharacters(in: .whitespacesAndNewlines),
            createdAt: Date(),
            scheduledFor: scheduledFor,
            sentAt: scheduledFor == nil ? Date() : nil
        )
        DataPersistenceManager.shared.appendUserLetter(letter)
        dismiss()
    }
}

#Preview {
    ComposeLetterView()
}
