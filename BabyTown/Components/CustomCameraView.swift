import SwiftUI
import AVFoundation

struct CustomCameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var canCapture: Bool = true
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> CustomCameraViewController {
        let controller = CustomCameraViewController()
        controller.canCapture = canCapture
        controller.onPhotoCaptured = { capturedImage in
            image = capturedImage
        }
        controller.onCancel = {
            dismiss()
        }
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CustomCameraViewController, context: Context) {
        uiViewController.canCapture = canCapture
    }
}

class CustomCameraViewController: UIViewController {
    
    var onPhotoCaptured: ((UIImage) -> Void)?
    var onCancel: (() -> Void)?
    var canCapture: Bool = true {
        didSet {
            updateCaptureButtonState()
        }
    }
    
    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    
    private let captureButton: UIButton = {
        let button = UIButton(type: .custom)
        
        // Create circular white outline
        button.backgroundColor = .clear
        button.layer.cornerRadius = 40  // Half of 80 for perfect circle
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.white.cgColor
        button.clipsToBounds = true
        button.translatesAutoresizingMaskIntoConstraints = false
        
        // Add cat image in the center
        if let catImage = UIImage(named: "First Page Cat") {
            let imageView = UIImageView(image: catImage)
            imageView.contentMode = .scaleAspectFit
            imageView.translatesAutoresizingMaskIntoConstraints = false
            button.addSubview(imageView)
            
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                imageView.widthAnchor.constraint(equalTo: button.widthAnchor, multiplier: 0.6),
                imageView.heightAnchor.constraint(equalTo: button.heightAnchor, multiplier: 0.6)
            ])
        }
        
        return button
    }()
    
    
    private let flashView: UIView = {
        let view = UIView()
        view.backgroundColor = .white
        view.alpha = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }
    
    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera) else {
            return
        }
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        
        photoOutput = output
        captureSession = session
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview
    }
    
    private func setupUI() {
        view.addSubview(captureButton)
        view.addSubview(flashView)
        
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80),
            
            flashView.topAnchor.constraint(equalTo: view.topAnchor),
            flashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flashView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            flashView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }
    
    @objc private func capturePhoto() {
        guard canCapture else { return }
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    
    private func updateCaptureButtonState() {
        captureButton.isEnabled = canCapture
        captureButton.alpha = canCapture ? 1.0 : 0.5
    }
    
    private func showFlashEffect() {
        flashView.alpha = 1.0
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.flashView.alpha = 0
        }
    }
}

extension CustomCameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            return
        }
        
        DispatchQueue.main.async {
            self.showFlashEffect()
        }
        
        onPhotoCaptured?(image)
    }
}
