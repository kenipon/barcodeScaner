/*
 * Copyright 2012 ZXing authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit
import ZXingObjC

class ViewController: UIViewController {
    
    // MARK: Properties
    
    @IBOutlet weak var scanView: UIView?
    @IBOutlet weak var readerLineView: UIView!
    @IBOutlet weak var resultLabel: UILabel?
    
    fileprivate var capture: ZXCapture?
    
    fileprivate var isScanning: Bool?
    fileprivate var isFirstApplyOrientation: Bool?
    fileprivate var captureSizeTransform: CGAffineTransform?
    
    
    // MARK: Life Circles
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        if isFirstApplyOrientation == true { return }
        isFirstApplyOrientation = true
        applyOrientation()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        coordinator.animate(alongsideTransition: { (context) in
            // do nothing
        }) { [weak self] (context) in
            guard let weakSelf = self else { return }
            weakSelf.applyOrientation()
        }
    }
}

// MARK: Helpers
extension ViewController {
    func setup() {
        isScanning = false
        isFirstApplyOrientation = false
        
        capture = ZXCapture()
        guard let _capture = capture else { return }
        _capture.camera = _capture.back()
        _capture.focusMode =  .continuousAutoFocus
        _capture.delegate = self
        
        // 画面全体の作成
        self.view.layer.addSublayer(_capture.layer)
        guard let _coverLayer = makeCoverLayer() else {return}
        self.view.layer.addSublayer(_coverLayer)

        // scanViewの作成
        guard let _scanView = scanView, let _resultLabel = resultLabel else { return }
        //_scanView.layer.cornerRadius = 20
        
        // 画面の前後設定
        self.view.bringSubview(toFront: _scanView)
        self.view.bringSubview(toFront: _resultLabel)
        self.view.bringSubview(toFront: readerLineView)
    }
    
    func applyOrientation() {
        let orientation = UIApplication.shared.statusBarOrientation
        var captureRotation: Double
        var scanRectRotation: Double
        
        switch orientation {
            case .portrait:
                captureRotation = 0
                scanRectRotation = 90
                break
            
            case .landscapeLeft:
                captureRotation = 90
                scanRectRotation = 180
                break
            
            case .landscapeRight:
                captureRotation = 270
                scanRectRotation = 0
                break
            
            case .portraitUpsideDown:
                captureRotation = 180
                scanRectRotation = 270
                break
            
            default:
                captureRotation = 0
                scanRectRotation = 90
                break
        }
        
        applyRectOfInterest(orientation: orientation)
        
        let angleRadius = captureRotation / 180.0 * Double.pi
        let captureTranform = CGAffineTransform(rotationAngle: CGFloat(angleRadius))
        
        capture?.transform = captureTranform
        capture?.rotation = CGFloat(scanRectRotation)
        capture?.layer.frame = view.frame
    }
    
    /// スキャン領域の作成
    func applyRectOfInterest(orientation: UIInterfaceOrientation) {
        guard var transformedVideoRect = scanView?.frame,
            let cameraSessionPreset = capture?.sessionPreset
            else { return }
        
        var scaleVideoX, scaleVideoY: CGFloat
        var videoHeight, videoWidth: CGFloat
        
        // Currently support only for 1920x1080 || 1280x720
        if cameraSessionPreset == AVCaptureSession.Preset.hd1920x1080.rawValue {
            videoHeight = 1080.0
            videoWidth = 1920.0
        } else {
            videoHeight = 720.0
            videoWidth = 1280.0
        }
        
        if orientation == UIInterfaceOrientation.portrait {
            scaleVideoX = self.view.frame.width / videoHeight
            scaleVideoY = self.view.frame.height / videoWidth
            
            // Convert CGPoint under portrait mode to map with orientation of image
            // because the image will be cropped before rotate
            // reference: https://github.com/TheLevelUp/ZXingObjC/issues/222
            let realX = transformedVideoRect.origin.y;
            let realY = self.view.frame.size.width - transformedVideoRect.size.width - transformedVideoRect.origin.x;
            let realWidth = transformedVideoRect.size.height;
            let realHeight = transformedVideoRect.size.width;
            transformedVideoRect = CGRect(x: realX, y: realY, width: realWidth, height: realHeight);
        
        } else {
            scaleVideoX = self.view.frame.width / videoWidth
            scaleVideoY = self.view.frame.height / videoHeight
        }
        
        captureSizeTransform = CGAffineTransform(scaleX: 1.0/scaleVideoX, y: 1.0/scaleVideoY)

        // scanRectの値を変更することで読み込み領域を変更できたが、x,yが逆転していたため、txに高さを設定
        // captureSizeTransform = CGAffineTransform(a: 1.0/scaleVideoX, b: 0, c: 0, d: 1.0/scaleVideoY, tx: 300, ty: 0)
        guard let _captureSizeTransform = captureSizeTransform else { return }
        let transformRect = transformedVideoRect.applying(_captureSizeTransform)
        capture?.scanRect = transformRect
        NSLog("scanRect: \(String(describing: capture?.scanRect.debugDescription))")
    }
    
    /// バーコードフォーマットの設定
    func barcodeFormatToString(format: ZXBarcodeFormat) -> String {
        switch (format) {
            case kBarcodeFormatAztec:
                return "Aztec"
            
            case kBarcodeFormatCodabar:
                return "CODABAR"
            
            case kBarcodeFormatCode39:
                return "Code 39"
            
            case kBarcodeFormatCode93:
                return "Code 93"
            
            case kBarcodeFormatCode128:
                return "Code 128"
            
            case kBarcodeFormatDataMatrix:
                return "Data Matrix"
            
            case kBarcodeFormatEan8:
                return "EAN-8"
            
            case kBarcodeFormatEan13:
                return "EAN-13"
            
            case kBarcodeFormatITF:
                return "ITF"
            
            case kBarcodeFormatPDF417:
                return "PDF417"
            
            case kBarcodeFormatQRCode:
                return "QR Code"
            
            case kBarcodeFormatRSS14:
                return "RSS 14"
            
            case kBarcodeFormatRSSExpanded:
                return "RSS Expanded"
            
            case kBarcodeFormatUPCA:
                return "UPCA"
            
            case kBarcodeFormatUPCE:
                return "UPCE"
            
            case kBarcodeFormatUPCEANExtension:
                return "UPC/EAN extension"
            
            default:
                return "Unknown"
            }
    }
    
    
    /// スキャン領域以外の黒い半透明カバーの作成
    func makeCoverLayer() -> CALayer? {
        // レイヤ作成
        let targetLayer = CALayer()
        targetLayer.frame = self.view.frame
        targetLayer.backgroundColor = UIColor.black.cgColor
        targetLayer.opacity = 0.5
        
        // マスクレイヤ(作成したい形状)の作成
        let maskLayer = CAShapeLayer()
        maskLayer.bounds = targetLayer.bounds
        // 外側の四角とくり抜く四角の形状を作成
        let outerRectPath = UIBezierPath(rect: self.view.frame)
        guard let _scanView = scanView else {return nil}
        let innerRectPath = UIBezierPath(roundedRect: _scanView.frame, cornerRadius: 20)
        outerRectPath.append(innerRectPath)
        // ２つの形状を合体
        maskLayer.path = outerRectPath.cgPath
        maskLayer.position = CGPoint(x: targetLayer.bounds.width / 2.0,
                                     y: targetLayer.bounds.height / 2.0)
        // くり抜く設定
        maskLayer.fillRule = kCAFillRuleEvenOdd
        
        // レイヤを作成した形状に合わせる
        targetLayer.mask = maskLayer
        
        return targetLayer
    }
    
    func changeViewByStatus() {
        guard let _isScanning = isScanning else { return }
        if(_isScanning){
            resultLabel?.text = ""
            readerLineView.isHidden = false
            self.view.bringSubview(toFront: readerLineView)
            // 点滅開始
            UIView.animate(withDuration: 0.2,
                           delay: 0.0,
                           options: .repeat,
                           animations: { self.readerLineView.alpha = 0 },
                           completion: nil)
        } else {
            readerLineView.isHidden = true
            self.view.bringSubview(toFront: resultLabel!)
        }
    }
}

// MARK: ZXCaptureDelegate
extension ViewController: ZXCaptureDelegate {
    func captureCameraIsReady(_ capture: ZXCapture!) {
        isScanning = true
        changeViewByStatus()
    }
    
    func captureResult(_ capture: ZXCapture!, result: ZXResult!) {
        guard let _result = result, isScanning == true else { return }

        capture?.stop()
        isScanning = false
        changeViewByStatus()
        
        let text = _result.text ?? "Unknow"
        let format = barcodeFormatToString(format: _result.barcodeFormat)
        
        let displayStr = "Scanned !\nFormat: \(format)\nContents: \(text)"
        resultLabel?.text = displayStr
        
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let weakSelf = self else { return }
            weakSelf.isScanning = true
            weakSelf.capture?.start()
            self?.changeViewByStatus()
        }
    }
}
