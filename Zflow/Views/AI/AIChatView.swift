import SwiftUI
import PhotosUI

// MARK: - AI Chat Message Model

struct AIChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let text: String
    let timestamp: Date
    var scanResult: ScannedReceipt? = nil
    var replyTo: QuotedMessage? = nil

    enum Role { case user, assistant }
}

struct QuotedMessage: Identifiable {
    let id = UUID()
    let text: String
    let role: AIChatMessage.Role
}

// MARK: - AIChatView

struct AIChatView: View {
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var scheduledPaymentVM: ScheduledPaymentViewModel
    @EnvironmentObject var budgetManager: BudgetManager
    @EnvironmentObject var recurringVM: RecurringTransactionViewModel
    @EnvironmentObject var calMgr: CalendarManager
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
    @State private var activeReceipt: ScannedReceipt?
    @State private var replyingTo: AIChatMessage?

    // Photo / Camera
    @State private var showMediaPicker  = false
    @State private var cameraItem: UIImage?
    @State private var photosItem: PhotosPickerItem?
    @State private var showCamera       = false

    // Attach menu (+ button)
    @State private var showAttachMenu   = false
    @State private var showFileImporter = false
    @State private var bulkImportURL: URL?
    @State private var showBulkImportFromChat = false

    @FocusState private var inputFocused: Bool

    @State private var suggestedPrompts = [
        "💰 Bu ayki özetim nedir?",
        "📉 Nereden tasarruf edebilirim?",
        "🚕 Bugün taksiye 250 TL verdim",
        "📅 Yaklaşan ödemelerim neler?"
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    scrollArea
                    
                    VStack(spacing: 0) {
                        if showAttachMenu {
                            attachMenuPanel
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else if !suggestedPrompts.isEmpty && inputText.isEmpty && replyingTo == nil && !inputFocused {
                            suggestedPromptsView
                                .padding(.bottom, 8)
                        }

                        if let _ = replyingTo {
                            replyPreview
                        }
                        inputBar
                    }
                    .background(.ultraThinMaterial.opacity(0.1), ignoresSafeAreaEdges: .bottom)
                }
            }
            .navigationTitle(NSLocalizedString("ai.title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarItems }
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showAttachMenu)
        }
        // Sheets
        .sheet(isPresented: $showCamera) {
            CameraPickerView { image in
                Task { await processScanImage(image) }
            }
        }
        .photosPicker(isPresented: $showMediaPicker, selection: $photosItem, matching: .images)
        .onChange(of: photosItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await processScanImage(image)
                }
                photosItem = nil
            }
        }
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.pdf, .commaSeparatedText, .text],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                bulkImportURL = url
                showBulkImportFromChat = true
            }
        }
        .fullScreenCover(isPresented: $showBulkImportFromChat) {
            if let url = bulkImportURL {
                BulkImportView(
                    viewModel: BulkImportViewModel(categories: transactionVM.categories),
                    fileURL: url
                )
                .environmentObject(transactionVM)
                .environmentObject(authVM)
            }
        }
        .fullScreenCover(item: $activeReceipt) { receipt in
            AddTransactionView(scan: receipt) { type, amount, currency in
                // Add AI confirmation message
                let typeKey = type == .income ? "dashboard.income" : "dashboard.expense"
                let typeText = NSLocalizedString(typeKey, comment: "")
                let format = NSLocalizedString("ai.scan.saveSuccess", comment: "")
                let amountStr = String(format: "%.2f", amount)
                let msg = "**\(typeText)**\n\(String(format: format, amountStr, currency.symbol, typeText))"

                messages.append(AIChatMessage(role: .assistant, text: msg, timestamp: .now))
            }
            .environmentObject(transactionVM)
            .environmentObject(authVM)
            .environmentObject(scheduledPaymentVM)
            .environmentObject(calMgr)
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            Button { dismiss() } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .bold))
                    Text(NSLocalizedString("common.close", comment: ""))
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(Color(hex: "#FFD700"))
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                clearChat()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(hex: "#FFD700"))
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
                                activeReceipt = scan
                            }
                            .id(msg.id)
                        } else {
                            MessageBubble(message: msg, replyingTo: $replyingTo)
                                .id(msg.id)
                        }
                    }

                    if isTyping || isScanning {
                        TypingIndicator(label: isScanning
                                        ? NSLocalizedString("scan.analyzing", comment: "")
                                        : nil)
                        .id("typing")
                    }
                    
                    Color.clear
                        .frame(height: 1)
                        .id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 10) 
            }
            .scrollDismissesKeyboard(.immediately)
            .onTapGesture { inputFocused = false }
            .onChange(of: messages.count) {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: isTyping) { _, typing in
                if typing { scrollToBottom(proxy: proxy, id: "typing") }
            }
            .onChange(of: isScanning) { _, scanning in
                if scanning { scrollToBottom(proxy: proxy, id: "typing") }
            }
            .onChange(of: inputFocused) { _, focused in
                if focused {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToBottom(proxy: proxy)
                    }
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy, id: String? = nil) {
        // Use a slight delay to ensure the keyboard or new message layout is stable
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                if let targetId = id {
                    proxy.scrollTo(targetId, anchor: .bottom)
                } else {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        HStack(spacing: 8) {
            // Attach / + button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showAttachMenu.toggle()
                    if showAttachMenu { inputFocused = false }
                }
                Haptic.light()
            } label: {
                ZStack {
                    Circle()
                        .fill(showAttachMenu
                              ? AppTheme.baseColor.opacity(0.25)
                              : Color.white.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                        .rotationEffect(.degrees(showAttachMenu ? 45 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showAttachMenu)
                }
            }
            .buttonStyle(.plain)
            .disabled(isScanning || isTyping)

            // Text field container
            HStack(spacing: 8) {
                TextField("CFO'ya mesaj yaz...", text: $inputText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.white)
                    .submitLabel(.send)
                
                // Send button
                Button {
                    if !inputText.trimmingCharacters(in: .whitespaces).isEmpty {
                        sendMessage()
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 34, height: 34)
                        .background(
                            Circle()
                                .fill(inputText.trimmingCharacters(in: .whitespaces).isEmpty 
                                      ? AnyShapeStyle(Color.white.opacity(0.1)) 
                                      : AnyShapeStyle(Color.green.opacity(0.8)))
                        )
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isTyping || isScanning)
            }
            .padding(.trailing, 6)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(
            ZStack {
                Capsule()
                    .fill(Color.black.opacity(0.4))
                Capsule()
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            }
            .background(Capsule().fill(.ultraThinMaterial))
            .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 10)
        )
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, inputFocused ? 12 : 16)
    }

    // MARK: - Attach Menu (+ button expand)

    private var attachMenuPanel: some View {
        HStack(spacing: 0) {
            attachButton(title: NSLocalizedString("scan.camera", comment: "Kamera"),
                         icon: "camera.fill",
                         color: Color(hex: "#FF6B6B")) {
                showAttachMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showCamera = true }
            }
            attachButton(title: NSLocalizedString("scan.photoLibrary", comment: "Galeri"),
                         icon: "photo.on.rectangle.angled",
                         color: AppTheme.baseColor) {
                showAttachMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showMediaPicker = true }
            }
            attachButton(title: NSLocalizedString("action.addFile", comment: "Dosya"),
                         icon: "doc.badge.plus",
                         color: Color(hex: "#30D158")) {
                showAttachMenu = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { showFileImporter = true }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.25), radius: 20, x: 0, y: -4)
        )
    }

    private func attachButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.selection()
            action()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 52, height: 52)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(color.opacity(0.2), lineWidth: 0.5)
                        )
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Suggested Prompts

    private var replyPreview: some View {
        HStack(spacing: 12) {
            // Compact Indicator
            Capsule()
                .fill(AppTheme.accentGradient)
                .frame(width: 3.5, height: 32) // FIXED HEIGHT to avoid expansion
            
            VStack(alignment: .leading, spacing: 1) {
                Text(replyingTo?.role == .user ? NSLocalizedString("chat.you", comment: "") : NSLocalizedString("chat.assistant", comment: ""))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.accentGradient)
                
                Text(replyingTo?.text ?? "")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                withAnimation { replyingTo = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.hierarchical)
                    .font(.system(size: 20))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 6) // Tuck it tight against the input bar
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .opacity.combined(with: .scale(scale: 0.95))
        ))
    }

    private var suggestedPromptsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(suggestedPrompts, id: \.self) { prompt in
                    Button {
                        sendMessage(text: prompt)
                    } label: {
                        Text(prompt)
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(Color.green.opacity(0.15))
                                    .background(Capsule().fill(.ultraThinMaterial))
                                    .overlay(Capsule().stroke(Color.green.opacity(0.2), lineWidth: 0.5))
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 12)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Send Text Message

    private func sendMessage(text: String? = nil) {
        let textToSend = (text ?? inputText).trimmingCharacters(in: .whitespaces)
        guard !textToSend.isEmpty else { return }

        Haptic.light()
        
        var newMessage = AIChatMessage(role: .user, text: textToSend, timestamp: .now)
        if let replyingTo {
            newMessage.replyTo = QuotedMessage(text: replyingTo.text, role: replyingTo.role)
        }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            messages.append(newMessage)
            if text == nil { inputText = "" }
            replyingTo = nil
        }
        
        // if text == nil {
        //     inputText = ""
        // } else {
        //     // Optional: Remove clicked prompt to simplify UI
        //     // withAnimation { suggestedPrompts.removeAll { $0 == text } }
        // }
        
        
        // inputFocused = false // Keep keyboard open like WhatsApp
        generateReply(for: textToSend)
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
            
            // Show sheet immediately after successful scan
            activeReceipt = result

        } catch {
            Haptic.warning()
            append(.assistant, text: String(format: NSLocalizedString("ai.scan.failed", comment: ""),
                                             error.localizedDescription))
        }
    }

    // MARK: - Local Replies

    private func generateReply(for query: String) {
        isTyping = true
        print("💬 [AIChatView] Starting generateReply for: \(query)")
        
        let userId = authVM.userProfile?.id.uuidString ?? "anonymous"
        let userName = authVM.userProfile?.fullName
        
        // Map history (excluding current user message and scan results)
        let historyPayload: [[String: String]] = messages.dropLast().compactMap { msg in
            // Skip messages that have scan results to keep context clean
            if msg.scanResult != nil { return nil }
            return [
                "role": msg.role == .user ? "user" : "assistant",
                "content": msg.text
            ]
        }
        
        ZFlowNetworkManager.shared.sendChatMessage(message: query, userId: userId, userName: userName, history: historyPayload) { result in
            DispatchQueue.main.async {
                self.isTyping = false

                switch result {
                case .success(let chatResponse):
                    let reply = chatResponse.reply
                    let action = chatResponse.action
                    print("💬 [AIChatView] Received reply: \(reply), action: \(action ?? "nil")")

                    // 0. Server-side tool call saved to DB — refresh immediately
                    if action == "transaction_added" || action == "budget_set" || action == "recurring_added" || action == "transaction_deleted" || action == "spending_summary_fetched" {
                        self.append(.assistant, text: reply)
                        Haptic.success()
                        Task { @MainActor in
                            guard let uid = self.authVM.currentUserId else { return }
                            let userType = self.authVM.userProfile?.userType ?? "personal"
                            await self.transactionVM.refreshData(userId: uid, userType: userType)
                            await self.budgetManager.fetchBudgets(userId: uid)
                            await self.scheduledPaymentVM.fetchScheduledPayments(userId: uid)
                            await self.recurringVM.fetchAll(userId: uid)
                            self.transactionVM.updateEcosystem()
                        }
                        return
                    }

                    // 1. Check for Transaction
                    if let scanResult = parseTransaction(from: reply) {
                        let cleanReply = reply.replacingOccurrences(of: #"\[TRANS:.*?\]"#, with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        self.append(.assistant, text: cleanReply)
                        
                        // AUTO-SAVE to Supabase
                        Task { @MainActor in
                            guard let uid = authVM.currentUserId else { return }
                            let currency = Currency(rawValue: scanResult.currency) ?? .try_
                            let type: TransactionType = scanResult.type == "income" ? .income : .expense
                            
                            // Try to find category UUID
                            var categoryId: UUID? = nil
                            if let catIdStr = scanResult.categoryId, let uuid = UUID(uuidString: catIdStr) {
                                categoryId = uuid
                            } else {
                                categoryId = transactionVM.categories.first(where: { 
                                    $0.name.lowercased() == scanResult.category.lowercased() 
                                })?.id
                            }
                            
                            let success = await transactionVM.addTransaction(
                                userId: uid,
                                amount: scanResult.amount,
                                currency: currency,
                                type: type,
                                categoryId: categoryId,
                                note: scanResult.note,
                                date: scanResult.date
                            )
                            
                            if success {
                                let savedMsg = NSLocalizedString("ai.transactionSaved", comment: "AI saved the transaction automatically")
                                self.append(.assistant, text: "✅ \(savedMsg)")
                                Haptic.success()

                                // FORCE REFRESH: This ensures Dashboard & Reports update instantly
                                await transactionVM.refreshData(userId: uid, userType: authVM.userProfile?.userType ?? "personal")
                                await budgetManager.fetchBudgets(userId: uid)
                                await scheduledPaymentVM.fetchScheduledPayments(userId: uid)
                                await recurringVM.fetchAll(userId: uid)
                                transactionVM.updateEcosystem()
                            }
                        }
                    } 
                    // 3. Clean up other payloads (SCHEDULE, RECURRING) which are handled by the backend persistence
                    // but might have tags in the reply text
                    else {
                        var cleanReply = reply
                        let patterns = [
                            #"\[SCHEDULE_PAYMENT:.*?\]"#,
                            #"\[RECURRING_REMINDER:.*?\]"#,
                            #"\[TRANS:.*?\]"#,
                            #"\[BUDGET:.*?\]"#
                        ]
                        for p in patterns {
                            cleanReply = cleanReply.replacingOccurrences(of: p, with: "", options: .regularExpression)
                        }
                        cleanReply = cleanReply.trimmingCharacters(in: .whitespacesAndNewlines)
                        self.append(.assistant, text: cleanReply)
                    }
                    Haptic.light()
                    
                case .failure(let error):
                    print("💬 [AIChatView] ERROR: \(error.localizedDescription)")
                    let errorMsg = NSLocalizedString("ai.reply.error", comment: "AI communication error")
                    self.append(.assistant, text: "\(errorMsg) (\(error.localizedDescription))")
                    Haptic.warning()
                }
            }
        }
    }

    // MARK: - Helpers

    private func parseTransaction(from text: String) -> ScannedReceipt? {
        let pattern = #"\[TRANS:(.*?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let contentRange = match.range(at: 1)
        guard let range = Range(contentRange, in: text) else { return nil }
        let content = String(text[range])
        
        var dict: [String: String] = [:]
        content.split(separator: ";").forEach { pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                dict[String(parts[0])] = String(parts[1])
            }
        }
        
        let amount = Double(dict["amount"] ?? "0") ?? 0
        guard amount > 0 else { return nil }
        
        return ScannedReceipt(
            amount: amount,
            currency: dict["currency"] ?? "TRY",
            merchant: dict["merchant"] ?? "",
            category: dict["category"] ?? "",
            categoryId: dict["category"] ?? "", // Fallback to category string if ID not explicitly provided
            date: Date(),
            note: dict["merchant"] ?? dict["category"] ?? "AI Transaction",
            type: "expense",
            taxNumber: "",
            salesItems: [],
            imageUrl: "" // Text based
        )
    }

    private func parseBudget(from text: String) -> (category: String, limit: Double, currency: String)? {
        let pattern = #"\[BUDGET:(.*?)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []),
              let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        let contentRange = match.range(at: 1)
        guard let range = Range(contentRange, in: text) else { return nil }
        let content = String(text[range])
        
        var dict: [String: String] = [:]
        content.split(separator: ";").forEach { pair in
            let parts = pair.split(separator: "=", maxSplits: 1)
            if parts.count == 2 {
                dict[String(parts[0])] = String(parts[1])
            }
        }
        
        let limit = Double(dict["limit"] ?? "0") ?? 0
        let category = dict["category"] ?? ""
        
        guard limit > 0, !category.isEmpty else { return nil }
        
        return (category: category, limit: limit, currency: dict["currency"] ?? "TRY")
    }

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
            replyingTo = nil
        }
    }
}

// MARK: - Scan Result Bubble

private struct ScanResultBubble: View {
    let scan: ScannedReceipt
    let onAdd: () -> Void
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            VStack(alignment: .leading, spacing: 12) {
                // Receipt image thumbnail (Only if present)
                if !scan.imageUrl.isEmpty, let url = URL(string: scan.imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(maxWidth: .infinity, maxHeight: 140)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        case .failure:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 80)
                                .overlay {
                                    Image(systemName: "photo")
                                        .foregroundColor(.white.opacity(0.3))
                                }
                        default:
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 80)
                                .overlay { ProgressView().tint(.white) }
                        }
                    }
                } else if scan.imageUrl.isEmpty {
                    // Placeholder for text-based detection
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color.green.opacity(0.2)).frame(width: 40, height: 40)
                            Image(systemName: "sparkles")
                                .foregroundColor(.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("ai.transactionDetected", comment: "Transaction detected in text"))
                                .font(.system(size: 14, weight: .bold))
                            Text(NSLocalizedString("ai.transactionDetected.hint", comment: "Review and save below"))
                                .font(.system(size: 11))
                                .opacity(0.6)
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.bottom, 4)
                }

                // Header (Modified for elite look)
                if !scan.imageUrl.isEmpty {
                    Label(NSLocalizedString("scan.result.title", comment: ""),
                          systemImage: "doc.text.magnifyingglass")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color.green)
                }

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
            .padding(16)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )

            Spacer(minLength: 40)
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
    @Binding var replyingTo: AIChatMessage?
    @Environment(\.colorScheme) private var scheme
    private var isUser: Bool { message.role == .user }

    @State private var dragOffset: CGFloat = 0
    @State private var isReplyingTriggered = false

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isUser { Spacer(minLength: 40) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                if let reply = message.replyTo {
                    HStack(spacing: 8) {
                        Rectangle()
                            .fill(AppTheme.accentGradient)
                            .frame(width: 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(reply.role == .user ? NSLocalizedString("chat.you", comment: "") : NSLocalizedString("chat.assistant", comment: ""))
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.accentGradient)
                                .opacity(0.9)
                            Text(reply.text)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 4)
                }

                formattedText
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        ZStack {
                            UnevenRoundedRectangle(
                                topLeadingRadius: 24,
                                bottomLeadingRadius: isUser ? 24 : 4,
                                bottomTrailingRadius: isUser ? 4 : 24,
                                topTrailingRadius: 24,
                                style: .continuous
                            )
                            .fill(Color.white.opacity(isUser ? 0.2 : 0.12))
                            .background(
                                UnevenRoundedRectangle(
                                    topLeadingRadius: 24,
                                    bottomLeadingRadius: isUser ? 24 : 4,
                                    bottomTrailingRadius: isUser ? 4 : 24,
                                    topTrailingRadius: 24,
                                    style: .continuous
                                )
                                .fill(.ultraThinMaterial)
                            )
                        }
                    )
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 24,
                            bottomLeadingRadius: isUser ? 24 : 4,
                            bottomTrailingRadius: isUser ? 4 : 24,
                            topTrailingRadius: 24,
                            style: .continuous
                        )
                        .stroke(isUser ? Color.white.opacity(0.1) : Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
                    .contextMenu {
                        Button {
                            UIPasteboard.general.string = message.text
                            Haptic.light()
                        } label: {
                            Label(NSLocalizedString("common.copy", comment: ""), systemImage: "doc.on.doc")
                        }
                        
                        Button {
                            withAnimation(.spring()) { replyingTo = message }
                        } label: {
                            Label(NSLocalizedString("common.reply", comment: ""), systemImage: "arrowshape.turn.up.left")
                        }
                    }

                Text(message.timestamp, style: .time)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 4)
            }
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.width > 0 { // Swipe right
                            dragOffset = min(value.translation.width, 100)
                            if dragOffset > 70 && !isReplyingTriggered {
                                Haptic.light()
                                isReplyingTriggered = true
                            }
                        }
                    }
                    .onEnded { value in
                        if dragOffset > 70 {
                            withAnimation(.spring()) {
                                replyingTo = message
                            }
                        }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            dragOffset = 0
                            isReplyingTriggered = false
                        }
                    }
            )

            if !isUser { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var formattedText: some View {
        if isUser {
            Text(message.text)
                .font(.system(size: 15, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            MarkdownMessageView(text: message.text)
        }
    }
}

// MARK: - Markdown Message Renderer

private struct MarkdownMessageView: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(parsedLines.enumerated()), id: \.offset) { _, line in
                lineView(for: line)
            }
        }
    }

    @ViewBuilder
    private func lineView(for line: ParsedLine) -> some View {
        switch line {
        case .bullet(let content):
            HStack(alignment: .top, spacing: 7) {
                Text("•")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.55))
                    .frame(width: 10)
                    .padding(.top, 1)
                inlineText(content)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .spacer:
            Spacer().frame(height: 4)
        case .text(let content):
            inlineText(content)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func inlineText(_ content: String) -> some View {
        if let attr = try? AttributedString(
            markdown: content,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            Text(attr).font(.system(size: 15))
        } else {
            Text(content).font(.system(size: 15))
        }
    }

    private enum ParsedLine {
        case bullet(String)
        case text(String)
        case spacer
    }

    private var parsedLines: [ParsedLine] {
        text.components(separatedBy: "\n").map { line in
            if line.hasPrefix("- ") {
                return .bullet(String(line.dropFirst(2)))
            } else if line.hasPrefix("• ") {
                return .bullet(String(line.dropFirst(2)))
            } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
                return .spacer
            } else {
                return .text(line)
            }
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

// MARK: - ImageSourceSheet

struct ImageSourceSheet: View {
    var onCamera: () -> Void
    var onGallery: () -> Void
    @Environment(\.colorScheme) var scheme

    var body: some View {
        VStack(spacing: 24) {
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            Text(NSLocalizedString("scan.chooseSource", comment: ""))
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(spacing: 12) {
                sourceButton(
                    title: NSLocalizedString("scan.camera", comment: ""),
                    icon: "camera.fill",
                    action: onCamera
                )
                
                sourceButton(
                    title: NSLocalizedString("scan.photoLibrary", comment: ""),
                    icon: "photo.on.rectangle.angled",
                    action: onGallery
                )
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .background(
            ZStack {
                Color.black.opacity(0.6)
                Color.white.opacity(0.05)
            }
            .background(.ultraThinMaterial)
            .ignoresSafeArea()
        )
    }

    private func sourceButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            Haptic.selection()
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
                    .frame(width: 32)
                
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white.opacity(0.3))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.1))
                    .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
            )
        }
        .buttonStyle(.plain)
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
