// ============================================================
// ZFlow — Receipt Scanner (VisionKit + OpenAI Vision)
// Target: Zflow (main app)
// iOS 16+ — VNDocumentCameraViewController
// ============================================================

import SwiftUI
import VisionKit

// MARK: - Receipt Scanner Coordinator

@MainActor
class ReceiptScannerCoordinator: NSObject, VNDocumentCameraViewControllerDelegate {
    var onScanned: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?

    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                       didFinishWith scan: VNDocumentCameraScan) {
        guard scan.pageCount > 0 else { controller.dismiss(animated: true); return }
        let image = scan.imageOfPage(at: 0)
        controller.dismiss(animated: true) { [weak self] in
            self?.onScanned?(image)
        }
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true) { [weak self] in
            self?.onCancel?()
        }
    }

    func documentCameraViewController(_ controller: VNDocumentCameraViewController,
                                       didFailWithError error: Error) {
        print("❌ [ReceiptScanner] Error: \(error)")
        controller.dismiss(animated: true)
    }
}

// MARK: - SwiftUI Document Camera View

struct DocumentCameraView: UIViewControllerRepresentable {
    var onScanned: (UIImage) -> Void
    var onCancel: (() -> Void)?

    func makeCoordinator() -> ReceiptScannerCoordinator {
        let c = ReceiptScannerCoordinator()
        c.onScanned = onScanned
        c.onCancel  = onCancel
        return c
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let vc = VNDocumentCameraViewController()
        vc.delegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}
}

// MARK: - Receipt Scan Sheet

struct ReceiptScannerSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var transactionVM: TransactionViewModel
    @EnvironmentObject var authVM: AuthViewModel

    @State private var isAnalyzing  = false
    @State private var resultTitle  = ""
    @State private var resultAmount = ""
    @State private var resultDate   = ""
    @State private var resultCategory = ""
    @State private var showCamera   = false
    @State private var scannedImage: UIImage?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()

                VStack(spacing: 24) {
                    if isAnalyzing {
                        analysingView
                    } else if let image = scannedImage, !resultAmount.isEmpty {
                        resultView(image)
                    } else {
                        promptView
                    }
                }
                .padding(20)
            }
            .navigationTitle("Fatura Tara")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("İptal") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                DocumentCameraView { image in
                    scannedImage = image
                    Task { await analyzeReceipt(image) }
                } onCancel: {
                    showCamera = false
                }
                .ignoresSafeArea()
            }
        }
    }

    private var promptView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.viewfinder.fill")
                .font(.system(size: 72))
                .foregroundStyle(LinearGradient(
                    colors: [AppTheme.baseColor, AppTheme.accentSecondary],
                    startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Fişi veya faturayı kameraya tut, ZFlow tutarı ve kategoriyi otomatik tespit etsin.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundColor(.secondary)
                .padding(.horizontal)

            if let error = errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                showCamera = true
            } label: {
                Label("Fatura Tara", systemImage: "camera.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(LinearGradient(
                                colors: [AppTheme.baseColor, AppTheme.accentSecondary],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var analysingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.4)
            Text("Fatura analiz ediliyor...")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.secondary)
        }
    }

    private func resultView(_ image: UIImage) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(uiImage: image)
                .resizable().scaledToFit()
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))

            GlassCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    resultRow(icon: "text.quote", label: "Başlık", value: $resultTitle)
                    Divider().padding(.leading, 40)
                    resultRow(icon: "turkishlirasign.circle", label: "Tutar", value: $resultAmount)
                    Divider().padding(.leading, 40)
                    resultRow(icon: "calendar", label: "Tarih", value: $resultDate)
                    Divider().padding(.leading, 40)
                    resultRow(icon: "tag.fill", label: "Kategori", value: $resultCategory)
                }
                .padding(16)
            }

            Button {
                addTransactionFromReceipt()
            } label: {
                Label("İşlem Olarak Kaydet", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.green.gradient)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func resultRow(icon: String, label: String, value: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(AppTheme.baseColor)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .frame(width: 60, alignment: .leading)
            TextField(label, text: value)
                .font(.system(size: 14, weight: .semibold))
        }
    }

    // MARK: - Analysis (sends image to OpenAI Vision)

    private func analyzeReceipt(_ image: UIImage) async {
        isAnalyzing  = true
        errorMessage = nil

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            errorMessage = "Görüntü işlenemedi."
            isAnalyzing = false
            return
        }

        // POST to ZFlow Python backend which proxies to OpenAI Vision
        guard let url = URL(string: "\(AppConstants.serverURL)/api/scan-receipt") else {
            isAnalyzing = false; return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"receipt.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                resultTitle    = json["title"]    ?? ""
                resultAmount   = json["amount"]   ?? ""
                resultDate     = json["date"]     ?? ""
                resultCategory = json["category"] ?? ""
            }
        } catch {
            errorMessage = "Analiz sırasında hata oluştu: \(error.localizedDescription)"
        }
        isAnalyzing = false
    }

    private func addTransactionFromReceipt() {
        guard let uid = authVM.currentUserId,
              let amount = Double(resultAmount.replacingOccurrences(of: ",", with: ".")) else { return }

        let category = transactionVM.categories.first {
            $0.name.lowercased().contains(resultCategory.lowercased())
        }

        Task {
            await transactionVM.addTransaction(
                userId: uid,
                amount: amount,
                currency: .try_,
                type: .expense,
                categoryId: category?.id,
                note: resultTitle,
                date: ISO8601DateFormatter().date(from: resultDate) ?? Date()
            )
            dismiss()
        }
    }
}
