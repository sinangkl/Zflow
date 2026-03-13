import SwiftUI
import CoreImage.CIFilterBuiltins

struct FamilyInviteQRView: View {
    @Environment(\.dismiss) var dismiss
    
    let inviteURL: String
    let themeColorHex: String
    let familyName: String
    
    @State private var qrImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                MeshGradientBackground().ignoresSafeArea()
                
                VStack(spacing: 30) {
                    
                    Text("Aile Grubuna Davet Et")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(ZColor.label)
                    
                    Text("Aile bütçenize katılacak kişinin telefon kamerasından bu QR kodu okutması yeterlidir.")
                        .font(.system(size: 15))
                        .foregroundColor(ZColor.labelSec)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    
                    // QR Code Card
                    ZStack {
                        RoundedRectangle(cornerRadius: 32, style: .continuous)
                            .fill(.white)
                            .shadow(color: Color(hex: themeColorHex).opacity(0.3), radius: 20, y: 10)
                        
                        VStack(spacing: 20) {
                            if let qrImage = qrImage {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 200, height: 200)
                                    .padding(16)
                            } else {
                                ProgressView()
                                    .frame(width: 200, height: 200)
                            }
                            
                            HStack(spacing: 8) {
                                Image(systemName: "house.fill")
                                    .foregroundColor(Color(hex: themeColorHex))
                                Text(familyName)
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.bottom, 8)
                        }
                        .padding(24)
                    }
                    .frame(width: 280, height: 320)
                    .padding(.top, 20)
                    
                    Spacer()
                    
                    Button {
                        Haptic.selection()
                        dismiss()
                    } label: {
                        Text("Kapat")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16).fill(Color(hex: themeColorHex)))
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 20)
                }
                .padding(.top, 40)
            }
            .onAppear(perform: generateQRCode)
            .navigationBarHidden(true)
        }
    }
    
    private func generateQRCode() {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        
        filter.message = Data(inviteURL.utf8)
        filter.correctionLevel = "M" // Medium error correction
        
        if let outputImage = filter.outputImage {
            // Apply a color tint based on the theme color
            let colorFilter = CIFilter.falseColor()
            colorFilter.inputImage = outputImage
            
            // Background color (white)
            colorFilter.color1 = CIColor(color: UIColor.white)
            // Foreground color (Theme Color)
            let uiThemeColor = UIColor(Color(hex: themeColorHex))
            colorFilter.color0 = CIColor(color: uiThemeColor)
            
            if let tintedImage = colorFilter.outputImage,
               let cgImage = context.createCGImage(tintedImage, from: tintedImage.extent) {
                // Return a high-resolution image
                self.qrImage = UIImage(cgImage: cgImage)
            } else if let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
                // Fallback to black & white
                self.qrImage = UIImage(cgImage: cgImage)
            }
        }
    }
}
