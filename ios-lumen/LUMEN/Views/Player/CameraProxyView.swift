//
//  CameraProxyView.swift
//  LUMEN
//
//  Live front-camera background for the Ritual Player "Mirror" mode.
//  Shows a real AVFoundation preview on device; a calm placeholder in the
//  cloud simulator where no camera exists.
//

import SwiftUI
import AVFoundation

struct CameraProxyView: View {
    @Environment(\.palette) private var palette

    private var hasCamera: Bool {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
    }

    var body: some View {
        if hasCamera {
            ActualCameraView()
        } else {
            ZStack {
                palette.surface2
                VStack(spacing: Space.m) {
                    Image(systemName: "camera.metering.center.weighted")
                        .font(.system(size: 40))
                        .foregroundStyle(palette.accent)
                    Text("Mirror")
                        .font(.serif(20, .medium))
                        .foregroundStyle(palette.textPrimary)
                    Text("Install this app on your device via the Rork App to use the camera.")
                        .font(.ui(14))
                        .foregroundStyle(palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.xl)
                }
            }
        }
    }
}

private struct ActualCameraView: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.configure()
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}
}

private final class PreviewView: UIView {
    private let session = AVCaptureSession()

    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    private var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }

    func configure() {
        previewLayer.videoGravity = .resizeAspectFill
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        previewLayer.session = session
        Task.detached { [session] in
            session.startRunning()
        }
    }
}
