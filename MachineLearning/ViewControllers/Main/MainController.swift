//
//  ViewController.swift
//  MachineLearning
//
//  Created by Eric Ziegler on 1/5/22.
//

import UIKit
import AVFoundation
import Vision

class MainController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {

    // MARK: - Properties

    static private let storyboardId = "MainControllerId"

    @IBOutlet weak var previewView: UIView! // container for the camera
    @IBOutlet weak var blurView: UIVisualEffectView! // background for the results label
    @IBOutlet weak var resultsLabel: TopAlignedLabel! // displays the classification text

    private let captureSession = AVCaptureSession() // video capture session
    private let captureQueue = DispatchQueue(label: "captureQueue") // queue for processing video frames
    private var previewLayer: AVCaptureVideoPreviewLayer! // preview layer
    private var visionRequests = [VNRequest]() // vision request
    private var curClassifications = "" // text populated as classifications occur

    // MARK: - Init

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCaptureSession()
        setupVisionModel()
        setupUpdateTimer()
    }

    private func setupUI() {
        blurView.layer.cornerRadius = 12
    }
    
    // because updates happen very fast, it makes the results harder to read.
    // update on a timer to prevent the results label from constantly updating faster than is human-readable
    private func setupUpdateTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { timer in
            // display the results in the label
            DispatchQueue.main.async {
                self.resultsLabel.text = self.curClassifications
            }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = self.previewView.bounds;
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    private func setupCaptureSession() {
        // search for available capture devices
        let availableDevices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: AVMediaType.video, position: .back).devices

        // get capture device, add device input to capture session
        do {
            if let captureDevice = availableDevices.first {
                captureSession.addInput(try AVCaptureDeviceInput(device: captureDevice))
            }
        } catch {
            print(error.localizedDescription)
        }

        // setup output, set delegate, and add output to our capture session
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: captureQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        captureSession.addOutput(videoOutput)

        // add the preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewView.layer.addSublayer(previewLayer)

        // make sure we are in portrait mode
        let conn = videoOutput.connection(with: .video)
        conn?.videoOrientation = .portrait

        // Start the session
        DispatchQueue.global(qos: .default).async {
            self.captureSession.startRunning()
        }
    }

    private func setupVisionModel() {
        // create the vision model
        let resnetModel = try! Resnet50(configuration: MLModelConfiguration.init())
        guard let visionModel = try? VNCoreMLModel(for: resnetModel.model) else { return }

        // set up the request using our vision model
        let classificationRequest = VNCoreMLRequest(model: visionModel, completionHandler: handleClassifications)
        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop
        visionRequests = [classificationRequest]
    }

    // MARK: - VisionModel Handling

    func handleClassifications(request: VNRequest, error: Error?) {
        // check for errors
        if let error = error {
            print("Error: \(error.localizedDescription)")
            return
        }

        // check that we have any results
        guard let observations = request.results else {
            print("No results")
            return
        }

        // set a regonition threshold so that a result will only be displayed if its confidence is at least 25%
        let recognitionThreshold: Float = 0.25
        // grab the top 4 results and their confidence levels
        // format the string so each result is on its line
        curClassifications = observations[0...4] // top 4 results
            .compactMap({ $0 as? VNClassificationObservation })
            .compactMap({$0.confidence > recognitionThreshold ? $0 : nil})
            .map({ "\($0.identifier) \(($0.confidence * 100.0).rounded())%" })
            .joined(separator: "\n")

        // classifications will be updated via a timer
    }

    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // get the sample buffer
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // vision processing needs to know about the camera. grab camera data from the buffer
        var requestOptions:[VNImageOption: Any] = [:]
        if let cameraIntrinsicData = CMGetAttachment(sampleBuffer, key: kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, attachmentModeOut: nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicData]
        }

        // create the request handler and perform the vision request
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: requestOptions)
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
    }

}

