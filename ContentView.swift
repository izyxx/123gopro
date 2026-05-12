import SwiftUI
import PhotosUI
import AVFoundation
import CoreImage
import UserNotifications

struct ContentView: View {
    @State private var selectedItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var showModeSelection = false
    @State private var inputURL: URL?
    @State private var statusText = "Ready"
    @State private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    
    // Твой ник в приложении
    let developerTag = "by kitanaizyxx"
    let modes = ["Linear", "Wide", "SuperView", "HyperView"]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Фоновое свечение для стиля
            Circle().fill(Color.blue.opacity(0.1)).blur(radius: 100).offset(y: -200)
            
            VStack(spacing: 30) {
                VStack(spacing: 5) {
                    Text("123GOPRO STRETCH")
                        .font(.system(size: 28, weight: .black, design: .monospaced))
                        .foregroundColor(.blue)
                    Text(developerTag)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                }
                
                if !isProcessing {
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        VStack(spacing: 20) {
                            Image(systemName: "video.badge.plus.fill")
                                .font(.system(size: 60))
                            Text("ВЫБРАТЬ ВИДЕО 4:3").bold()
                        }
                        .frame(width: 280, height: 280)
                        .background(RoundedRectangle(cornerRadius: 30).fill(Color.white.opacity(0.05)))
                        .overlay(RoundedRectangle(cornerRadius: 30).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                        .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 20) {
                        ProgressView().tint(.blue).scaleEffect(2)
                        Text(statusText).foregroundColor(.white).font(.caption)
                        Text("Обработка идет в фоне").font(.caption2).foregroundColor(.blue).opacity(0.7)
                    }
                }
                
                Spacer().frame(height: 50)
            }
        }
        .onAppear {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
        .sheet(isPresented: $showModeSelection) {
            VStack(spacing: 15) {
                Text("ВЫБЕРИ РЕЖИМ").font(.headline).padding(.top)
                Text(developerTag).font(.caption2).foregroundColor(.gray)
                
                ForEach(modes, id: \.self) { mode in
                    Button(action: { 
                        showModeSelection = false
                        runProcessing(mode: mode) 
                    }) {
                        Text(mode).bold().frame(maxWidth: .infinity).padding().background(Color.blue).foregroundColor(.white).cornerRadius(12)
                    }.padding(.horizontal)
                }
                Spacer()
            }
            .presentationDetents([.medium])
        }
        .onChange(of: selectedItem) { _ in
            handleSelection()
        }
    }
    
    func handleSelection() {
        Task {
            if let data = try? await selectedItem?.loadTransferable(type: Data.self) {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("input.mp4")
                try? data.write(to: url)
                inputURL = url
                showModeSelection = true
            }
        }
    }
    
    func runProcessing(mode: String) {
        guard let url = inputURL else { return }
        isProcessing = true
        statusText = "Рендеринг \(mode)..."
        
        backgroundTaskId = UIApplication.shared.beginBackgroundTask {
            UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
            self.backgroundTaskId = .invalid
        }

        let asset = AVAsset(url: url)
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("result_\(mode).mp4")
        try? FileManager.default.removeItem(at: outputURL)
        
        let k: Float = (mode == "SuperView") ? 0.19 : (mode == "HyperView" ? 0.44 : 0.0)
        
        let warpKernel = CIWarpKernel(source: """
        kernel vec2 stretch(float width, float k) {
            vec2 p = destCoord();
            float x = p.x / width;
            float normX = x * 2.0 - 1.0;
            float distortedX = normX + sin(normX * 3.141592) * k;
            return vec2((distortedX + 1.0) / 2.0 * width, p.y);
        }
        """)!

        let composition = AVMutableVideoComposition(asset: asset) { request in
            let source = request.sourceImage
            let w = source.extent.width
            let h = source.extent.height
            let targetW = h * (16/9)
            
            if mode == "Linear" {
                let corrected = source.applyingFilter("CIBumpDistortion", parameters: [
                    kCIInputCenterKey: CIVector(x: w/2, y: h/2),
                    kCIInputRadiusKey: w * 0.9,
                    kCIInputScaleKey: -0.2
                ])
                request.finish(with: corrected.cropped(to: CGRect(x: 0, y: (h - (w*9/16))/2, width: w, height: w*9/16)), context: nil)
            } else if mode == "Wide" {
                request.finish(with: source.cropped(to: CGRect(x: 0, y: (h - (w*9/16))/2, width: w, height: w*9/16)), context: nil)
            } else {
                let output = warpKernel.apply(extent: CGRect(x: 0, y: 0, width: targetW, height: h),
                                             arguments: [Float(targetW), k], image: source)
                request.finish(with: output!, context: nil)
            }
        }

        let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetHighestQuality)!
        exporter.videoComposition = composition
        exporter.outputURL = outputURL
        exporter.outputFileType = .mp4
        
        exporter.exportAsynchronously {
            if exporter.status == .completed {
                PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL)
                } completionHandler: { _, _ in
                    let content = UNMutableNotificationContent()
                    content.title = "123GOPRO \(self.developerTag)"
                    content.body = "Твой \(mode) готов и сохранен!"
                    content.sound = .default
                    let req = UNNotificationRequest(identifier: "done", content: content, trigger: nil)
                    UNUserNotificationCenter.current().add(req)
                    
                    UIApplication.shared.endBackgroundTask(self.backgroundTaskId)
                    self.backgroundTaskId = .invalid
                    
                    DispatchQueue.main.async {
                        self.isProcessing = false
                    }
                }
            }
        }
    }
}
