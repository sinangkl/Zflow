import SwiftUI
import PhotosUI

// MARK: - AI Chat Message Model

struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date
    var scanResult: ScannedReceipt? = nil

    enum Role { case user, assistant }
}

// MARK: - AIChatView

struct AIChatView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme

    @State private var messages: [AIChatMessage] = [
        AIChatMessage(
            role: .assistant,
            text: NSLocalizedString("ai.greeting", comment: ""),
            timestamp: .now
        )
    ]
    @State private var inputText        = ""
    @State private var isTyping         = false
    @State private var isScanning       = false
    @State private var scanError: String?
    @State private var showScanError    = false
    @State private var showAddTransaction = false
    @State private var pendingScan: ScannedReceipt?

    // Photo / Camera
    @State private var showMediaPicker  = false
    @State private var showSourceMenu   = false
    @State private var cameraItem: UIImage?
    @State private var photosItem: PhotosPickerItem?
    @State private var showCamera       = false

    @FocusState private var inputFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                PremiumBackground()

                VStack(spacing: 0) {
                    scrollArea
                    Divider().opacity(0.3)
                    inputBar
                }
            }
            .navigationTitle(NSLocalizedString("ai.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
        }
        // Sheets
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                Task { await processScanImage(image) }
            }
        }
        .sheet(isPresented: $showAddTransaction) {
            if let scan = pendingScan {
                AddTransactionView(scan: scan)
                    .environmentObject(transactionVM)
                    .environmentObject(AuthViewModel())
            }
        }
        // Photo picker
        .photosPicker(
            isPresented: $showMediaPicker,
            selection: $photosItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: photosItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    photosItem = nil
                    await processScanImage(image)
                }
            }
        }
        // Error alert
        .alert(NSLocalizedString("scan.error.title", comment: ""), isPresented: $showScanError) {
            Button(NSLocalizedString("common.done", comment: ""), role: .cancel) {}
        } message: {
            Text(scanError ?? "")
        }
        // Source picker
        .confirmationDialog(
            NSLocalizedString("scan.chooseSource", comment: ""),
            isPresented: $showSourceMenu,
            titleVisibility: .visible
        ) {
            Button(NSLocalizedString("scan.camera", comment: ""))    { showCamera = true }
            Button(NSLocalizedString("scan.photoLibrary", comment: "")) { showMediaPicker = true }
            Button(NSLocalizedString("common.cancel", comment: ""), role: .cancel) {}
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button(NSLocalizedString("common.close", comment: "")) { dismiss() }
                .foregroundColor(ZColor.indigo)
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                clearChat()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(ZColor.indigo)
            }
            .disabled(messages.count <= 1)
        }
    }

    // MARK: - Scroll Area

    private var scrollArea: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { msg in
                        if let scan = msg.scanResult {
                            ScanResultBubble(scan: scan) {
                                pendingScan = scan
                                showAddTransaction = true
                            }
                            .id(msg.id)
                        } else {
                            MessageBubble(message: msg)
                                .id(msg.id)
                        }
                    }

                    if isTyping || isScanning {
                        TypingIndicator(label: isScanning
                                        ? NSLocalizedString("scan.analyzing", comment: "")
                                        : nil)
                        .id("typing")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation(.easeOut(duration: 0.3)) {
                    proxy.scrollTo(messages.last?.id, anchor: .bottom)
                }
            }
            .onChange(of: isTyping) { _, typing in
                if typing {
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
            .onChange(of: isScanning) { _, scanning in
                if scanning {
                    withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo("typing", anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Camera / scan button
            Button {
                showSourceMenu = true
                Haptic.light()
            } label: {
                ZStack {
                    Circle()
                        .fill(scheme == .dark
                              ? Color.white.opacity(0.1)
                              : Color.black.opacity(0.06))
                        .frame(width: 38, height: 38)
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.accentGradient)
                }
            }
            .disabled(isScanning || isTyping)

            // Text field
            TextField(NSLocalizedString("ai.inputPlaceholder", comment: ""), text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(scheme == .dark
                              ? Color.white.opacity(0.08)
                              : Color.black.opacity(0.06))
                )
                .focused($inputFocused)

            // Send button
            Button { sendMessage() } label: {
                ZStack {
                    Circle()
                        .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                              ? AnyShapeStyle(Color.secondary.opacity(0.25))
                              : AnyShapeStyle(AppTheme.accentGradient))
                        .frame(width: 38, height: 38)
                    Image(systemName: "arrow.up")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isTyping || isScanning)
            .animation(.easeInOut(duration: 0.15), value: inputText.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(scheme == .dark
                    ? Color(UIColor.systemBackground).opacity(0.9)
                    : Color(UIColor.systemBackground))
    }

    // MARK: - Send Text Message

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        Haptic.light()
        append(.user, text: text)
        inputText = ""
        inputFocused = false
        generateReply(for: text)
    }

    // MARK: - Scan Image

    private func processScanImage(_ image: UIImage) async {
        // User message with thumbnail placeholder
        append(.user, text: NSLocalizedString("ai.scan.userMessage", comment: ""))

        isScanning = true
        defer { isScanning = false }

        do {
            let userId = authVM.userProfile?.id.uuidString ?? ""
            let businessId = authVM.userProfile?.isBusiness == true ? authVM.userProfile?.id.uuidString : nil
            let result = try await ReceiptScanService.shared.scan(image: image, userId: userId, businessId: businessId)
            Haptic.success()

            // Add assistant message with embedded scan result
            let reply = String(format: NSLocalizedString("ai.scan.success", comment: ""),
                               result.merchant.isEmpty ? NSLocalizedString("ai.scan.unknownMerchant", comment: "") : result.merchant,
                               result.amount,
                               result.currency)

            var msg = AIChatMessage(role: .assistant, text: reply, timestamp: .now)
            msg.scanResult = result
            withAnimation { messages.append(msg) }

        } catch {
            Haptic.warning()
            append(.assistant, text: String(format: NSLocalizedString("ai.scan.failed", comment: ""),
                                             error.localizedDescription))
        }
    }

    // MARK: - Local Replies

    private func generateReply(for query: String) {
        isTyping = true
        let delay = Double.random(in: 0.7...1.4)

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            let lowered = query.lowercased()
            let totalExpense = transactionVM.transactions
                .filter { $0.type == "expense" }.reduce(0.0) { $0 + $1.amount }
            let totalIncome = transactionVM.transactions
                .filter { $0.type == "income" }.reduce(0.0) { $0 + $1.amount }
            let currency = transactionVM.primaryCurrency

            let reply: String
            if lowered.contains("harca") || lowered.contains("gider") || lowered.contains("expense") {
                reply = String(format: NSLocalizedString("ai.reply.expense", comment: ""), totalExpense, currency)
            } else if lowered.contains("gelir") || lowered.contains("kazanç") || lowered.contains("income") {
                reply = String(format: NSLocalizedString("ai.reply.income", comment: ""), totalIncome, currency)
            } else if lowered.contains("bakiy") || lowered.contains("balance") {
                reply = String(format: NSLocalizedString("ai.reply.balance", comment: ""), totalIncome - totalExpense, currency)
            } else if lowered.contains("işlem") || lowered.contains("transaction") {
                reply = String(format: NSLocalizedString("ai.reply.transactions", comment: ""), transactionVM.transactions.count)
            } else if lowered.contains("tara") || lowered.contains("scan") || lowered.contains("fatura") || lowered.contains("fiş") {
                reply = NSLocalizedString("ai.reply.scanHint", comment: "")
            } else if lowered.contains("merhaba") || lowered.contains("selam") || lowered.contains("hello") || lowered.contains("hi") {
                reply = NSLocalizedString("ai.reply.hello", comment: "")
            } else if lowered.contains("teşekkür") || lowered.contains("thanks") {
                reply = NSLocalizedString("ai.reply.thanks", comment: "")
            } else {
                reply = NSLocalizedString("ai.reply.default", comment: "")
            }

            self.isTyping = false
            self.append(.assistant, text: reply)
            Haptic.light()
        }
    }

    // MARK: - Helpers

    private func append(_ role: AIChatMessage.Role, text: String) {
        withAnimation {
            messages.append(AIChatMessage(role: role, text: text, timestamp: .now))
        }
    }

    private func clearChat() {
        Haptic.light()
        withAnimation {
            messages = [
                AIChatMessage(role: .assistant,
                              text: NSLocalizedString("ai.greeting", comment: ""),
                              timestamp: .now)
            ]
        }
    }
}

// MARK: - Scan Result Bubble

private struct ScanResultBubble: View {
    let scan: ScannedReceipt
    let onAdd: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // AI avatar
            ZStack {
                Circle().fill(AppTheme.accentGradient).frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 10) {
                // Receipt image thumbnail
                if let url = URL(string: scan.imageUrl), !scan.imageUrl.isEmpty {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: 140)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        case .failure:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 80)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(.secondary)
                                }
                        default:
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 80)
                                .overlay { ProgressView() }
                        }
                    }
                }

                // Header
                Label(NSLocalizedString("scan.result.title", comment: ""),
                      systemImage: "doc.text.magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppTheme.accentGradient)

                Divider()

                // Fields
                receiptRow(icon: "storefront.fill",      label: NSLocalizedString("scan.result.merchant", comment: ""),  value: scan.merchant.isEmpty ? "-" : scan.merchant)
                receiptRow(icon: "turkishlirasign.circle.fill", label: NSLocalizedString("scan.result.amount", comment: ""),   value: "\(String(format: "%.2f", scan.amount)) \(scan.currency)")
                receiptRow(icon: "tag.fill",             label: NSLocalizedString("scan.result.category", comment: ""), value: scan.category.isEmpty ? "-" : scan.category)
                receiptRow(icon: "calendar",             label: NSLocalizedString("scan.result.date", comment: ""),     value: scan.date.formatted(.dateTime.day().month().year()))

                if !scan.taxNumber.isEmpty {
                    receiptRow(icon: "number.circle.fill", label: NSLocalizedString("scan.result.taxNumber", comment: ""), value: scan.taxNumber)
                }
                if !scan.salesItems.isEmpty {
                    receiptRow(icon: "cart.fill", label: NSLocalizedString("scan.result.items", comment: ""), value: "\(scan.salesItems.count)")
                }

                // Add button
                Button(action: onAdd) {
                    Label(NSLocalizedString("scan.result.addTransaction", comment: ""),
                          systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppTheme.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(scheme == .dark ? Color.white.opacity(0.1) : Color.black.opacity(0.06))
            )

            Spacer(minLength: 8)
        }
    }

    private func receiptRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: AIChatMessage
    @Environment(\.colorScheme) private var scheme
    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser { Spacer(minLength: 48) }

            if !isUser {
                ZStack {
                    Circle().fill(AppTheme.accentGradient).frame(width: 30, height: 30)
                    Image(systemName: "sparkles")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white)
                }
            }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.text)
                    .font(.system(size: 15))
                    .foregroundColor(isUser ? .white : (scheme == .dark ? .white : Color(UIColor.label)))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        isUser
                            ? AnyShapeStyle(AppTheme.accentGradient)
                            : AnyShapeStyle(scheme == .dark
                                            ? Color.white.opacity(0.1)
                                            : Color.black.opacity(0.06))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 4)
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }
}

// MARK: - Typing Indicator

private struct TypingIndicator: View {
    var label: String?
    @State private var phase = 0

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ZStack {
                Circle().fill(AppTheme.accentGradient).frame(width: 30, height: 30)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 6) {
                if let label {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 5) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(Color.secondary)
                            .frame(width: 7, height: 7)
                            .scaleEffect(phase == i ? 1.3 : 0.8)
                            .animation(
                                .easeInOut(duration: 0.4).repeatForever().delay(Double(i) * 0.15),
                                value: phase
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.secondary.opacity(0.12))
            )

            Spacer(minLength: 48)
        }
        .onAppear { phase = 1 }
    }
}

// MARK: - Camera Picker (UIImagePickerController wrapper)

struct CameraPickerView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView
        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            picker.dismiss(animated: true)
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}
