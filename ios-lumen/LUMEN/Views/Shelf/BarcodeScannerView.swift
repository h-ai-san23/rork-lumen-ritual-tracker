//
//  BarcodeScannerView.swift
//  LUMEN
//
//  Scans a product barcode on device. In the cloud simulator (no camera) it
//  shows a calm placeholder with a manual-entry fallback.
//

import SwiftUI
import AVFoundation

struct BarcodeScannerView: View {
    @Environment(\.palette) private var palette
    @Environment(\.dismiss) private var dismiss
    var onScanned: (String) -> Void

    @State private var manualCode = ""

    private var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                LumenBackground()
                if hasCamera {
                    scanner
                } else {
                    placeholder
                }
            }
            .navigationTitle("Scan Barcode")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(palette.textSecondary)
                }
            }
        }
        .tint(palette.accent)
    }

    private func handleScan(_ code: String) {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onScanned(code)
        dismiss()
    }

    private var scanner: some View {
        ZStack {
            ScannerRepresentable(onScanned: handleScan)
                .ignoresSafeArea()
            reticle
            instruction
        }
    }

    private var reticle: some View {
        RoundedRectangle(cornerRadius: Radius.card)
            .strokeBorder(palette.gold, lineWidth: 2)
            .frame(width: 260, height: 150)
            .shadow(color: palette.goldDark.opacity(0.4), radius: 12)
    }

    private var instruction: some View {
        VStack {
            Spacer()
            Text("Center the barcode in the frame")
                .font(.ui(14, .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, Space.l)
                .padding(.vertical, Space.s)
                .background(Capsule().fill(Color.black.opacity(0.5)))
                .padding(.bottom, Space.xxl)
        }
    }

    private var placeholder: some View {
        VStack(spacing: Space.l) {
            Image(systemName: "barcode.viewfinder")
                .font(.system(size: 48)).foregroundStyle(palette.accent)
            Text("Scanning needs a camera")
                .font(.serif(22, .medium)).foregroundStyle(palette.textPrimary)
            Text("Install LUMEN on your device via the Rork App to scan barcodes, or enter the number below.")
                .font(.ui(14)).foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.xl)

            HStack(spacing: Space.s) {
                TextField("Barcode number", text: $manualCode)
                    .keyboardType(.numberPad)
                    .font(.ui(16)).foregroundStyle(palette.textPrimary)
                    .padding(Space.m)
                    .background(palette.surface1)
                    .clipShape(.rect(cornerRadius: Radius.button))
                    .overlay(RoundedRectangle(cornerRadius: Radius.button).strokeBorder(palette.hairline, lineWidth: 1))
            }
            .padding(.horizontal, Space.xl)

            GoldButton(title: "Use this code") {
                let trimmed = manualCode.trimmingCharacters(in: .whitespaces)
                guard !trimmed.isEmpty else { return }
                onScanned(trimmed)
                dismiss()
            }
            .frame(maxWidth: 240)
            .opacity(manualCode.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(Space.l)
    }
}

private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onScanned: onScanned) }

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: ScannerController, context: Context) {}

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onScanned: (String) -> Void
        private var didScan = false

        init(onScanned: @escaping (String) -> Void) { self.onScanned = onScanned }

        nonisolated func metadataOutput(_ output: AVCaptureMetadataOutput,
                                        didOutput metadataObjects: [AVMetadataObject],
                                        from connection: AVCaptureConnection) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            Task { @MainActor in
                guard !self.didScan else { return }
                self.didScan = true
                self.onScanned(value)
            }
        }
    }
}

private final class ScannerController: UIViewController {
    weak var delegate: AVCaptureMetadataOutputObjectsDelegate?
    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?

    override func viewDidLoad() {
        super.viewDidLoad()
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(delegate, queue: .main)
        output.metadataObjectTypes = [.ean8, .ean13, .upce, .code128, .code39, .qr]

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        previewLayer = layer

        Task.detached { [session] in session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
}
