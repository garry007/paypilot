#if canImport(SwiftUI)
import SwiftUI

public struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showRegister = false

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "creditcard.fill")
                                .font(.system(size: 56))
                                .foregroundColor(.payPilotBlue)
                            Text("PayPilot")
                                .font(.largeTitle.bold())
                            Text("Secure payments, simplified.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 48)

                        // Form
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Username", systemImage: "person")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter your username", text: $username)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .keyboardType(.asciiCapable)
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Password", systemImage: "lock")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                SecureField("Enter your password", text: $password)
                                    .textFieldStyle(.roundedBorder)
                            }

                            if let error = viewModel.errorMessage {
                                ErrorBanner(message: error)
                            }

                            Button {
                                viewModel.login(username: username, password: password)
                            } label: {
                                Group {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .tint(.white)
                                    } else {
                                        Text("Sign In")
                                            .fontWeight(.semibold)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 50)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.payPilotBlue)
                            .disabled(viewModel.isLoading || username.isEmpty || password.isEmpty)

                            NavigationLink(destination: RegisterView()) {
                                Text("Don't have an account? ")
                                    .foregroundColor(.secondary)
                                + Text("Sign Up")
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
            .navigationBarHidden(true)
        }
    }
}

#endif // canImport(SwiftUI)
