#if canImport(SwiftUI)
import SwiftUI

public struct RegisterView: View {
    @StateObject private var viewModel = AuthViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var username: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var validationError: String? = nil

    public init() {}

    private var localError: String? {
        if !username.isEmpty, username.count < 3 {
            return "Username must be at least 3 characters."
        }
        if !email.isEmpty, !email.isValidEmail {
            return "Please enter a valid email address."
        }
        if !password.isEmpty, !password.isValidPassword {
            return "Password must be at least 8 characters."
        }
        if !confirmPassword.isEmpty, password != confirmPassword {
            return "Passwords do not match."
        }
        return nil
    }

    private var canSubmit: Bool {
        !username.isEmpty && !email.isEmpty &&
        !password.isEmpty && !confirmPassword.isEmpty &&
        localError == nil && !viewModel.isLoading
    }

    public var body: some View {
        ZStack {
            Color(.systemGroupedBackground).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 6) {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.payPilotBlue)
                        Text("Create Account")
                            .font(.title.bold())
                    }
                    .padding(.top, 32)

                    // Form card
                    VStack(spacing: 16) {
                        FormField(title: "Username", icon: "person", placeholder: "Choose a username") {
                            TextField("Choose a username", text: $username)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                        }

                        FormField(title: "Email", icon: "envelope", placeholder: "Enter your email") {
                            TextField("Enter your email", text: $email)
                                .keyboardType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .textFieldStyle(.roundedBorder)
                        }

                        FormField(title: "Password", icon: "lock", placeholder: "At least 8 characters") {
                            SecureField("At least 8 characters", text: $password)
                                .textFieldStyle(.roundedBorder)
                        }

                        FormField(title: "Confirm Password", icon: "lock.rotation", placeholder: "Repeat password") {
                            SecureField("Repeat password", text: $confirmPassword)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Show local validation or server error
                        if let err = localError ?? viewModel.errorMessage {
                            ErrorBanner(message: err)
                        }

                        Button {
                            viewModel.register(username: username, email: email, password: password)
                        } label: {
                            Group {
                                if viewModel.isLoading {
                                    ProgressView().progressViewStyle(.circular).tint(.white)
                                } else {
                                    Text("Create Account").fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.payPilotBlue)
                        .disabled(!canSubmit)

                        Button {
                            dismiss()
                        } label: {
                            Text("Already have an account? ")
                                .foregroundColor(.secondary)
                            + Text("Sign In")
                                .foregroundColor(.payPilotBlue)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 2)
                    .padding(.horizontal)
                }
            }
        }
        .navigationTitle("Register")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - FormField helper
private struct FormField<Content: View>: View {
    let title: String
    let icon: String
    let placeholder: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            content()
        }
    }
}

#endif // canImport(SwiftUI)
