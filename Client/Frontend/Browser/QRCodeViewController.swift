// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/

import Foundation
import AVFoundation
import Shared
import Common

protocol QRCodeViewControllerDelegate: AnyObject {
    func didScanQRCodeWithURL(_ url: URL)
    func didScanQRCodeWithText(_ text: String)
}

class QRCodeViewController: UIViewController {
    private struct UX {
        static let navigationBarBackgroundColor = UIColor.black
        static let navigationBarTitleColor = UIColor.Photon.White100
        static let maskViewBackgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        static let isLightingNavigationItemColor = UIColor(red: 0.45, green: 0.67, blue: 0.84, alpha: 1)
        static let viewBackgroundDeniedColor = UIColor.black
        static let scanLineHeight: CGFloat = 6
    }

    var qrCodeDelegate: QRCodeViewControllerDelegate?

    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = AVCaptureSession.Preset.high
        return session
    }()

    private lazy var captureDevice: AVCaptureDevice? = {
        return AVCaptureDevice.default(for: AVMediaType.video)
    }()

    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?

    private let scanLine: UIImageView = .build { imageView in
        imageView.image = UIImage(named: ImageIdentifiers.qrCodeScanLine)
    }

    private let scanBorder: UIImageView = .build { imageView in
        imageView.image = UIImage(named: ImageIdentifiers.qrCodeScanBorder)
    }

    private lazy var instructionsLabel: UILabel = .build { label in
        label.text = .ScanQRCodeInstructionsLabel
        label.textColor = UIColor.Photon.White100
        label.textAlignment = .center
        label.numberOfLines = 0
    }

    private var maskView: UIView = .build { view in
        view.backgroundColor = UX.maskViewBackgroundColor
    }
    private var isAnimationing = false
    private var isLightOn = false
    private var shapeLayer = CAShapeLayer()

    private var scanLineTopConstraint: NSLayoutConstraint!
    private var scanBorderWidthConstraint: NSLayoutConstraint!

    private var scanBorderSize: CGFloat {
        let minSize = min(view.frame.width, view.frame.height)
        var scanBorderSize = minSize / 3 * 2

        if UIDevice.current.userInterfaceIdiom == .pad || UIDevice.current.orientation.isLandscape {
            scanBorderSize = minSize / 2
        }
        return scanBorderSize
    }

    private let logger: Logger

    init(logger: Logger = DefaultLogger.shared) {
        self.logger = logger
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let captureDevice = self.captureDevice else {
            dismiss(animated: false)
            return
        }

        self.navigationItem.title = .ScanQRCodeViewTitle

        // Setup the NavigationBar
        self.navigationController?.navigationBar.barTintColor = UX.navigationBarBackgroundColor
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UX.navigationBarTitleColor]

        // Setup the NavigationItem
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(named: ImageIdentifiers.qrCodeGoBack)?.imageFlippedForRightToLeftLayoutDirection(),
            style: .plain,
            target: self,
            action: #selector(goBack))
        self.navigationItem.leftBarButtonItem?.tintColor = UIColor.Photon.White100

        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(named: ImageIdentifiers.qrCodeLight),
            style: .plain,
            target: self,
            action: #selector(openLight))
        if captureDevice.hasTorch {
            self.navigationItem.rightBarButtonItem?.tintColor = UIColor.Photon.White100
        } else {
            self.navigationItem.rightBarButtonItem?.tintColor = UIColor.Photon.Grey50
            self.navigationItem.rightBarButtonItem?.isEnabled = false
        }

        let getAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: AVMediaType.video)
        if getAuthorizationStatus != .denied {
            setupCamera()
        } else {
            view.backgroundColor = UX.viewBackgroundDeniedColor
            self.navigationItem.rightBarButtonItem?.isEnabled = false

            let alert = UIAlertController(title: "", message: .ScanQRCodePermissionErrorMessage, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: .ScanQRCodeErrorOKButton,
                                          style: .default,
                                          handler: { (action) -> Void in
                self.dismiss(animated: true)
            }))
            self.present(alert, animated: true, completion: nil)
        }

        setupVideoPreviewLayer()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        setupConstraints()
        isAnimationing = true
        startScanLineAnimation()

        applyShapeLayer()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        self.captureSession.stopRunning()
        stopScanLineAnimation()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        applyShapeLayer()
    }

    private func applyShapeLayer() {
        view.layoutIfNeeded()
        shapeLayer.removeFromSuperlayer()
        let rectPath = UIBezierPath(rect: view.bounds)
        rectPath.append(UIBezierPath(rect: scanBorder.frame).reversing())
        shapeLayer.path = rectPath.cgPath
        maskView.layer.mask = shapeLayer
    }

    private func setupConstraints() {
        view.addSubview(maskView)
        view.addSubview(scanBorder)
        view.addSubview(scanLine)
        view.addSubview(instructionsLabel)

        scanLineTopConstraint = scanLine.topAnchor.constraint(equalTo: scanBorder.topAnchor,
                                                              constant: UX.scanLineHeight)
        scanBorderWidthConstraint = scanBorder.widthAnchor.constraint(equalToConstant: scanBorderSize)

        NSLayoutConstraint.activate([
            maskView.topAnchor.constraint(equalTo: view.topAnchor),
            maskView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            maskView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            maskView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scanBorder.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            scanBorder.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            scanBorderWidthConstraint,
            scanBorder.heightAnchor.constraint(equalTo: scanBorder.widthAnchor),

            scanLineTopConstraint,
            scanLine.leadingAnchor.constraint(equalTo: scanBorder.leadingAnchor),
            scanLine.widthAnchor.constraint(equalTo: scanBorder.widthAnchor),
            scanLine.heightAnchor.constraint(equalToConstant: UX.scanLineHeight),

            instructionsLabel.topAnchor.constraint(equalTo: scanBorder.bottomAnchor, constant: 30),
            instructionsLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            instructionsLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    private func updateContraintsAfterTransition() {
        scanBorderWidthConstraint.constant = scanBorderSize
    }

    private func setupVideoPreviewLayer() {
        guard let videoPreviewLayer = self.videoPreviewLayer else { return }
        videoPreviewLayer.frame = UIScreen.main.bounds
        switch UIDevice.current.orientation {
        case .portrait:
            videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        case .landscapeLeft:
            videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeRight
        case .landscapeRight:
            videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.landscapeLeft
        case .portraitUpsideDown:
            videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portraitUpsideDown
        default:
            videoPreviewLayer.connection?.videoOrientation = AVCaptureVideoOrientation.portrait
        }
    }

    @objc
    func startScanLineAnimation() {
        if !isAnimationing {
            return
        }
        view.layoutIfNeeded()
        view.setNeedsLayout()
        UIView.animate(withDuration: 2.4,
                       delay: 0,
                       options: [.repeat],
                       animations: {
            self.scanLineTopConstraint.constant = self.scanBorder.frame.size.height - UX.scanLineHeight
            self.view.layoutIfNeeded()
        }) { (value: Bool) in
            self.scanLineTopConstraint.constant = UX.scanLineHeight
            self.perform(#selector(self.startScanLineAnimation), with: nil, afterDelay: 0)
        }
    }

    func stopScanLineAnimation() {
        isAnimationing = false
    }

    @objc
    func goBack() {
        self.dismiss(animated: true, completion: nil)
    }

    @objc
    func openLight() {
        guard let captureDevice = self.captureDevice else { return }

        if isLightOn {
            do {
                try captureDevice.lockForConfiguration()
                captureDevice.torchMode = AVCaptureDevice.TorchMode.off
                captureDevice.unlockForConfiguration()
                navigationItem.rightBarButtonItem?.image = UIImage(named: ImageIdentifiers.qrCodeLight)
                navigationItem.rightBarButtonItem?.tintColor = UIColor.Photon.White100
            } catch {}
        } else {
            do {
                try captureDevice.lockForConfiguration()
                captureDevice.torchMode = AVCaptureDevice.TorchMode.on
                captureDevice.unlockForConfiguration()
                navigationItem.rightBarButtonItem?.image = UIImage(named: ImageIdentifiers.qrCodeLightTurnedOn)
                navigationItem.rightBarButtonItem?.tintColor = UX.isLightingNavigationItemColor
            } catch {}
        }
        isLightOn = !isLightOn
    }

    func setupCamera() {
        guard let captureDevice = self.captureDevice else {
            dismiss(animated: false)
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(input)
        } catch {}
        let output = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            output.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        }
        let videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoPreviewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(videoPreviewLayer)
        self.videoPreviewLayer = videoPreviewLayer
        DispatchQueue.global(qos: .background).async {
            self.captureSession.startRunning()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in
            self.updateContraintsAfterTransition()
            self.setupVideoPreviewLayer()
        }, completion: nil)
    }
}

extension QRCodeViewController: AVCaptureMetadataOutputObjectsDelegate {
    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        if metadataObjects.isEmpty {
            self.captureSession.stopRunning()
            let alert = AlertController(title: "", message: .ScanQRCodeInvalidDataErrorMessage, preferredStyle: .alert)
            alert.addAction(
                UIAlertAction(title: .ScanQRCodeErrorOKButton,
                              style: .default,
                              handler: { (UIAlertAction) in
                self.captureSession.startRunning()
            }),
                accessibilityIdentifier: AccessibilityIdentifiers.Settings.FirefoxAccount.qrScanFailedAlertOkButton)
            self.present(alert, animated: true, completion: nil)
        } else {
            self.captureSession.stopRunning()
            stopScanLineAnimation()
            self.dismiss(animated: true, completion: {
                guard let metaData = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                      let qrCodeDelegate = self.qrCodeDelegate,
                      let text = metaData.stringValue
                else {
                    self.logger.log("Unable to scan QR code",
                                    level: .debug,
                                    category: .unlabeled)
                    return
                }

                if let url = URIFixup.getURL(text) {
                    qrCodeDelegate.didScanQRCodeWithURL(url)
                } else {
                    qrCodeDelegate.didScanQRCodeWithText(text)
                }
            })
        }
    }
}

class QRCodeNavigationController: UINavigationController {
    override open var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}
