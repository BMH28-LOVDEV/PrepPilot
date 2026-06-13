import AuthenticationServices
import SwiftUI

struct AuthenticationView: View {
    @AppStorage("isSignedIn") private var isSignedIn = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?

    var body: some View {
        PremiumBackground {
            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 18) {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundStyle(PrepPilotTheme.studyGradient)
                        .frame(width: 116, height: 116)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                    VStack(spacing: 8) {
                        Text("Sign in to PrepPilot")
                            .font(.largeTitle.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text("Keep lectures, notes, flashcards, and quiz progress synced across your devices.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                VStack(spacing: 12) {
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        handle(result)
                    }
                    .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                    .frame(height: 54)
                    .clipShape(RoundedRectangle(cornerRadius: PrepPilotTheme.cornerRadius, style: .continuous))

                    Button("Continue in Development") {
                        Haptics.success()
                        isSignedIn = true
                    }
                    .font(.headline)
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
                .padding(.horizontal)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success:
            Haptics.success()
            isSignedIn = true
        case .failure(let error):
            Haptics.warning()
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    AuthenticationView()
}
