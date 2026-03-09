#if canImport(SwiftUI)
import SwiftUI
#if canImport(Combine)
import Combine
#endif

public struct SendMoneyView: View {
    @StateObject private var viewModel = TransactionViewModel()
    @Environment(\.dismiss) private var dismiss

    @State private var amountText: String = ""
    @State private var currency: String = "USD"
    @State private var recipientId: String = ""
    @State private var description: String = ""
    @State private var showConfirmation = false
    @State private var didSend = false
#if canImport(Combine)
    @State private var cancellables = Set<AnyCancellable>()
#endif

    private let currencies = ["USD", "EUR", "GBP", "JPY"]

    private var amount: Double { Double(amountText) ?? 0 }

    private var canSend: Bool {
        amount > 0 && !recipientId.isEmpty && !viewModel.isLoading
    }

    public init() {}

    public var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        // Amount input
                        VStack(spacing: 6) {
                            Text("Amount")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(alignment: .firstTextBaseline, spacing: 4) {
                                Text(currencySymbol)
                                    .font(.title)
                                    .foregroundColor(.secondary)
                                TextField("0.00", text: $amountText)
                                    .keyboardType(.decimalPad)
                                    .font(.system(size: 48, weight: .bold, design: .rounded))
                                    .multilineTextAlignment(.center)
                            }

                            Picker("Currency", selection: $currency) {
                                ForEach(currencies, id: \.self) { code in
                                    Text(code).tag(code)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        .padding(.horizontal)

                        // Recipient & description
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Recipient ID", systemImage: "person")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("Enter recipient user ID", text: $recipientId)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .textFieldStyle(.roundedBorder)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Label("Description (optional)", systemImage: "text.bubble")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                TextField("What's this for?", text: $description)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(16)
                        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
                        .padding(.horizontal)

                        // Error
                        if let error = viewModel.errorMessage {
                            ErrorBanner(message: error)
                                .padding(.horizontal)
                        }

                        // Success
                        if didSend {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.payPilotGreen)
                                Text("Transaction sent successfully!")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.payPilotGreen)
                            }
                            .padding()
                            .background(Color.payPilotGreen.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                        }

                        // Send button
                        Button {
                            showConfirmation = true
                        } label: {
                            Group {
                                if viewModel.isLoading {
                                    ProgressView().progressViewStyle(.circular).tint(.white)
                                } else {
                                    Label("Send Money", systemImage: "paperplane.fill")
                                        .fontWeight(.semibold)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.payPilotBlue)
                        .disabled(!canSend)
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
            .navigationTitle("Send Money")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Confirm Transfer", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Send") { sendMoney() }
            } message: {
                Text("Send \(amount.formatted(asCurrency: currency)) to \(recipientId)?")
            }
        }
    }

    private var currencySymbol: String {
        switch currency {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        default:    return currency
        }
    }

    private func sendMoney() {
        let countBefore = viewModel.transactions.count
        viewModel.createTransaction(
            amount: amount,
            currency: currency,
            recipientId: recipientId,
            description: description.isEmpty ? nil : description
        )
#if canImport(Combine)
        // Reactively observe the viewModel for success (new transaction inserted) or failure (errorMessage set)
        viewModel.$transactions
            .dropFirst()
            .filter { $0.count > countBefore }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [self] _ in
                didSend = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    dismiss()
                }
            }
            .store(in: &cancellables)
#endif
    }
}

#endif // canImport(SwiftUI)
