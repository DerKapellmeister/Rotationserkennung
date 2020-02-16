//
//  ViewController.swift
//  smartCam
//
//  Created by Jonas on 02.07.19.
//  Copyright © 2019 Jonas. All rights reserved.
//

import UIKit
import AVFoundation
import Contacts
import ContactsUI
import Photos
import VisionKit


class ViewController: UIViewController {

    @IBOutlet var imageView: TouchImageView!
    @IBOutlet var textView: UITextView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var testButton: UIButton!
    @IBOutlet var progressBar: UIProgressView!
    
    var captureSession: AVCaptureSession!
    var videoPreviewLayer: AVCaptureVideoPreviewLayer!
    var stillImageOutput: AVCapturePhotoOutput!
    
    var imagePicker = UIImagePickerController()
    let rectLayer = CAShapeLayer()
    
    let timer = BTimer()
    var skewDetector: SkewDetector!
    var image: CGImage!
        
    override func viewDidLoad() {
        super.viewDidLoad()
        let tapRecognizerImageView = UITapGestureRecognizer(target: self, action: #selector(snapImage))
        imageView.isUserInteractionEnabled = true
        imageView.addGestureRecognizer(tapRecognizerImageView)
        imageView.layer.cornerRadius = 13
        imageView.layer.borderColor = UIColor.systemGray.cgColor
        
        skewDetector = SkewDetector(doneHandler: skewCallback(image:))
                
        FileManager.default.clearTmpDirectory()
        
    }
    override func viewWillAppear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    override func viewWillDisappear(_ animated: Bool) {
        navigationController?.setNavigationBarHidden(false, animated: animated)
    }
    override func viewDidAppear(_ animated: Bool) {
        
        super.viewDidAppear(animated)
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(
            for: AVMediaType.video
        ) else {
            return
        }
        
        guard let input = try? AVCaptureDeviceInput(
            device: backCamera
        ) else {
            return
        }
        
        stillImageOutput = AVCapturePhotoOutput()
        
        if captureSession.canAddInput(input) && captureSession.canAddOutput(stillImageOutput) {
            captureSession.addInput(input)
            captureSession.addOutput(stillImageOutput)
            setupLivePreview()
            imageView.layer.addSublayer(rectLayer)
        }

    }
        
    func setupLivePreview() {
        
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        
        videoPreviewLayer.videoGravity = .resizeAspectFill
        videoPreviewLayer.connection?.videoOrientation = .portrait
        imageView.layer.addSublayer(videoPreviewLayer)
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
            DispatchQueue.main.async {
                self.videoPreviewLayer.frame = self.imageView.bounds
            }
        }
    }
    func openGallery(){
        imagePicker.sourceType = UIImagePickerController.SourceType.photoLibrary
        imagePicker.allowsEditing = false
        imagePicker.delegate = self
        imagePicker.setNavigationBarHidden(true, animated: false)
        self.present(imagePicker, animated: true, completion: nil)
    }
    func skewCallback(image: UIImage?) {
        
        DispatchQueue.main.async {
            self.activityIndicator.stopAnimating()
            
            let screenSize: CGRect = UIScreen.main.bounds
            
            let imageView = UIImageView(frame: screenSize)
            imageView.image = image
            imageView.contentMode = .scaleAspectFit
            imageView.backgroundColor = UIColor.systemBackground

            
            let viewController = UIViewController()
            viewController.loadView()
            viewController.view.addSubview(imageView)
            
            
            self.navigationController?.pushViewController(viewController, animated: true)

        }
                
    }
    
    @objc func snapImage(){
        if(captureSession.isRunning){

            //activityIndicator.startAnimating()
            let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
            stillImageOutput.capturePhoto(with: settings, delegate: self)
        }else{
            captureSession.startRunning()
        }
    }
    
    @IBAction func btnTouchUp(_ sender: UIButton) {
        let photos = PHPhotoLibrary.authorizationStatus()
        if photos == .notDetermined {
            PHPhotoLibrary.requestAuthorization({status in
                if status == .authorized{
                    self.openGallery()
                }
            })
        }else {
            openGallery()
        }
    }
    
    
}

extension ViewController: CNContactViewControllerDelegate {
    func contactViewController(_ vc: CNContactViewController, didCompleteWith contact: CNContact?) {
        self.dismiss(animated: true, completion: {})
    }
}
extension ViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            DispatchQueue.global().async {
                self.skewDetector.detectSkew(img: image.rotate(radians: 0)!)
            }
        }
        
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.isNavigationBarHidden = false
        self.dismiss(animated: true, completion: nil)
    }
    
}
extension ViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        guard let imageData = photo.fileDataRepresentation()
            else { return }
        
        captureSession.stopRunning()

        guard let imageOriginal = UIImage(data: imageData) else {
            return
        }
        
        guard let image = imageOriginal.rotate(radians: 0) else {
            return
        }
        
        self.skewDetector.detectSkew(img: image)
        
        return

    }
}
extension UIImage {
    
    func rotate(radians: Float) -> UIImage? {
        
        let imageRect = CGRect(origin: CGPoint.zero, size: self.size)
        let radians = CGFloat(radians)
        var newSize = imageRect.applying(CGAffineTransform(rotationAngle: radians)).size
        
        newSize.width = floor(newSize.width)
        newSize.height = floor(newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        let context = UIGraphicsGetCurrentContext()!
        context.translateBy(x: newSize.width/2, y: newSize.height/2)
        context.rotate(by: CGFloat(radians))
        self.draw(in: CGRect(x: -self.size.width/2, y: -self.size.height/2, width: self.size.width, height: self.size.height))

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage
    }

}

extension FileManager {
    func clearTmpDirectory() {
        do {
            let tmpDirURL = FileManager.default.temporaryDirectory
            let tmpDirectory = try contentsOfDirectory(atPath: tmpDirURL.path)
            try tmpDirectory.forEach { file in
                let fileUrl = tmpDirURL.appendingPathComponent(file)
                print(fileUrl.path)
                try removeItem(atPath: fileUrl.path)
            }
        } catch {
            print("Error cleaning tmp directory")
        }
    }
}
