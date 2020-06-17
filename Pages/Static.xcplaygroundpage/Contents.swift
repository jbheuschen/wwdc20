//#-hidden-code
//This code is hidden as it is simply not that relevant for showcasing CoreML.
import UIKit
import CoreML
import Vision
import Foundation
import PlaygroundSupport


extension UIStackView {
    func addBackgroundLayer(color: UIColor) {
        let v = UIView()
        v.backgroundColor = color
        v.autoresizingMask = [.flexibleHeight, .flexibleWidth]
        insertSubview(v, at: 0)
    }
}

typealias PredictionItem = (String, Double)

protocol ImageClassifier {
    
    func process(_ img: UIImage, callback: @escaping ([PredictionItem]?) -> Void)
    
}

class ResultShowcase : UIViewController {
    
    var image: UIImage?
    var predictions: [PredictionItem]?
    let imageView: UIImageView
    let root = UIStackView()
    let parsedPredictions = UILabel()
    
    init(predictions: [PredictionItem], image: UIImage) {
        self.image = image
        self.predictions = predictions
        self.imageView = UIImageView(image: image)
        if #available(iOS 13.0, *) {
            self.imageView.scalesLargeContentImage = true
        }
        self.imageView.contentMode = .scaleAspectFit
        
        self.parsedPredictions.numberOfLines = 0
        self.parsedPredictions.lineBreakMode = .byWordWrapping
        
        
        
        var labeling = ""
        var n = 1
        for p in predictions {
            labeling += p.0 + ": " + String(round((p.1 * 100) * 1000) / 1000) + "%\n"
            if(n > 5) {
                break
            }
            n += 1
        }
        self.parsedPredictions.text = labeling
        self.parsedPredictions.textAlignment = .center
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.image = nil
        self.predictions = nil
        self.imageView = UIImageView(image: nil)
        super.init(coder: coder)
    }
    
    override func loadView() {
        
        self.view = self.root
        
        switch traitCollection.userInterfaceStyle {
            case .light, .unspecified:
                self.parsedPredictions.textColor = .black
                self.root.addBackgroundLayer(color: .white)
                self.navigationController?.navigationBar.backgroundColor = .white
            case .dark:
                self.parsedPredictions.textColor = .white
                self.root.addBackgroundLayer(color: .black)
        }
    }
    
    override func viewDidLoad() {
        title = "Results"
        self.navigationController?.navigationBar.isTranslucent = false
        self.root.addBackgroundLayer(color: .white)
        self.root.addArrangedSubview(self.imageView)
        self.root.addArrangedSubview(self.parsedPredictions)
        self.root.axis = .vertical
        self.root.distribution = .equalCentering
        
        self.parsedPredictions.center = CGPoint(x: 0, y: 0)
        UIView.animate(withDuration: 0.75, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.parsedPredictions.center = CGPoint(x: 0, y: -50)
        })
    }
    
}
//#-end-hidden-code

/*:
 [Previous](@previous)
 ## UIImage extension
 First of all, we need to prepare for the actual magic. The _Mobile Net_ model we use expects images with a resolution of exactly 224 x 224 pixels as an input. Moreover, when using _Core ML_ directly (which I will explain more detailed later on) we need to provide the image as a _CVPixelBuffer_ object. In order to keep the following code clear, we will add some methods directly to the respective _UIKit_ classes.
 In this case, we need two methods:
 - The _convertToCVPixelBuffer_ method converts an _UIImage_ to a _CVPixelBuffer_ cropped to the given dimensions

 */

extension UIImage {
    
    func convertToCVPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        
        var pb: CVPixelBuffer?
        
        let pbAttributeDict = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
        kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue]
        
        let stat = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, pbAttributeDict as CFDictionary, &pb)
        
        if(stat != kCVReturnSuccess || pb == nil) {
            return nil //failed to create pixel buffer
        }
        
        CVPixelBufferLockBaseAddress(pb!, CVPixelBufferLockFlags(rawValue: 0))
        let data = CVPixelBufferGetBaseAddress(pb!)
        
        guard let context = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pb!), space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) else {
            return nil //Failed either
        }
        
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)
        
        UIGraphicsPushContext(context)
        self.draw(in: CGRect(x: 0, y: 0, width: width, height: height)) //Draw using pushed context
        UIGraphicsPopContext() //Pop context
        
        CVPixelBufferUnlockBaseAddress(pb!, CVPixelBufferLockFlags(rawValue: 0))
        
        return pb!
    }
//:  - The _scaleTo_ method, which will scale the _UIImage_'s shortest side to the given size preserving the image's aspect ratio.
    func scaleTo(_ size: CGFloat) -> UIImage {
        
        let ratio = self.size.width / self.size.height
        var newWidth: CGFloat, newHeight: CGFloat
        
        if(self.size.width > self.size.height) {
            newHeight = size
            newWidth = round(size * ratio)
        } else {
            newWidth = size
            newHeight = round(size * ratio)
        }
        
        let nS = CGSize(width: newWidth, height: newHeight)
        
        UIGraphicsBeginImageContextWithOptions(nS, false, 0.0)
        self.draw(in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        guard let scaled = UIGraphicsGetImageFromCurrentImageContext() else {
            fatalError("Could not scale image!")
        }
        UIGraphicsEndImageContext()
        return scaled
    }
    
}

/*:
  ## Image Processor classes
   Once these basics are done, we have to implement our image classifiers. This is where the actual magic (i.e., the interaction with the machine learning model) happens. As a foundation for this, I prepared the protocol _ImageClassifier_ which is implemented by our classifiers. Moreover, I declared the typealias _PredictionItem_ which refers to the tuple _(String, Double)_ where the _String_ is the label of the category and the _Double_ the probability (these parts of our code are in the hidden core prepended to the visible part of this playground.).
  To begin with, we implement the _CoreMLImageClassifier_. This implementation will use the _CoreML_ APIs directly, whereas the later following _VisionImageClassifier_ will use the simpler to use _Vision_ API.
 */

class CoreMLImageClassifier : ImageClassifier {
    
    /// First of all, we need an instance of our model.
    let model = MobileNetV2FP16()
    
/*:
This is where all the magic is going to happen. As arguments we expect the image itself as well as a callback closure that we will call once we have some kind of result.
 */
    func process(_ image: UIImage, callback: @escaping ([PredictionItem]?) -> Void) {
        let img = image.scaleTo(224) // First of all, we scale down the image to something around 224x224 pixels (keeping aspect ratio!).
        let buf = img.convertToCVPixelBuffer(width: 224, height: 224) // Second of all, we create the neccessary CVPixelBuffer as described above.        
        
        if buf != nil, let pred = try? model.prediction(image: buf!) { // After ensuring the buffer we created is not nil, we try to get a prediction from our model by passing the buffer to it.
        
            let cLP = pred.classLabelProbs // This gives us a dictionary of [String : Double] containing the categories as well as the respective probability
            
            let preds = cLP.sorted(by: { (first, second) -> Bool in first.value > second.value }) // Now we just have to sort the model's predictions by their probability which allows us to just use the topmost ones.
            
            callback(preds) // Once that is done, we just have to invoke our callback - done!
        }
    }
    
}

/*:
 Wow - that was a short implementation! But we can do this even easier using Apple's _Vision_ library! When using _Vision_, we do not even have to scale and crop the images ourselves as all this is done by _Vision_ for us. See below:
 */

class VisionImageClassifier : ImageClassifier {
    
    /// Of course, we need an instance of our model
    let model = MobileNetV2FP16()
    
    /// This is how many results we want to pass to our callback - doing this in this class is actually not neccessary.
    static let results = 3
    
    func process(_ img: UIImage, callback: @escaping ([PredictionItem]?) -> Void) {
        
        // First of all, we have to create a VNCoreMLModel for our model instance.
        guard let vM = try? VNCoreMLModel(for: model.model) else {
            fatalError("Could not instantiate VNCoreMLModel!")
        }
        
        // Second of all, we build a request object containing our handler for when we have a prediction.
        let req = VNCoreMLRequest(model: vM) { request, error in
            if let obsv = request.results as? [VNClassificationObservation] {
                callback(obsv.prefix(through: VisionImageClassifier.results).map({
                    ($0.identifier, Double($0.confidence))
                })) // Here we call our callback again
            }
        }
        
        req.imageCropAndScaleOption = .centerCrop // Here we set the image preprocessing option for our request to centerCrop
        
        let imageHandler = VNImageRequestHandler(cgImage: img.cgImage!) // Now we create a VNImageRequestHandler and attach our image to it
        try? imageHandler.perform([req]) // Lastly, we just have to perform our request using our image handler - done!
        
    }
    
}

/*:
  # The UI
  Theoretically, this was everything we need to use our model. But of course, a simple UI to take or choose an image would be helpful.
E.g., you can change the implementation that is used below to experience if there are any differences in the results.
 */

class ViewController : UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    let stackView = UIStackView()
    let takePhoto = UIButton(type: .system)
    let choosePhoto = UIButton(type: .system)
    var classifier: ImageClassifier? = nil
    
    override func loadView() {
        super.loadView()
        //#-hidden-code
        self.stackView.axis = .horizontal
        self.stackView.distribution = .fillEqually
        self.stackView.alignment = .center
        self.takePhoto.setTitle("Take photo", for: .normal)
        self.choosePhoto.setTitle("Choose photo", for: .normal)
        //#-end-hidden-code
        self.stackView.addArrangedSubview(self.takePhoto)
        self.stackView.addArrangedSubview(self.choosePhoto)
        
        
        self.view = stackView
        
/*:
## Excercise
What happens if you switch between CoreMLImageClassifier() and VisionImageClassifier()? Are there any differences in the results? If so, what might have caused them?
 */
        //#-editable-code
        self.classifier = VisionImageClassifier()
        //#-end-editable-code
               
        
        // Actions - method implementations are hidden as they only contain the code to present the UIImagePickerController.
        self.takePhoto.addTarget(self, action: #selector(take), for: .touchUpInside)
        self.choosePhoto.addTarget(self, action: #selector(choose), for: .touchUpInside)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Choose an image"
        self.navigationController?.navigationBar.isTranslucent = false
        //#-hidden-code
        switch traitCollection.userInterfaceStyle {
            case .light, .unspecified:
                self.stackView.addBackgroundLayer(color: .white)
                self.navigationController?.navigationBar.backgroundColor = .white
            case .dark:
                self.stackView.addBackgroundLayer(color: .black)
                self.navigationController?.navigationBar.backgroundColor = .black
        }
        self.edgesForExtendedLayout = .all
        
        self.choosePhoto.center = CGPoint(x: 0, y: 0)
        self.takePhoto.center = CGPoint(x: 0, y: 0)
        UIView.animate(withDuration: 0.75, delay: 0.0, options: [.curveEaseInOut], animations: {
            self.choosePhoto.center = CGPoint(x: -50, y: 0)
            self.takePhoto.center = CGPoint(x: 50, y: 0)
        })
        //#-end-hidden-code
    }
    
    //#-hidden-code
    @objc
    func take() {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc
    func choose() {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        picker.delegate = self
        present(picker, animated: true)
    }
    //#-end-hidden-code
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        
        /*
         The user has chosen an image, let's process it!
         */
        
        guard let img = info[.editedImage] as? UIImage else {
            fatalError("Could not load the image!")
        }
        
        self.classifier?.process(img, callback: {
            predictions in
            guard predictions != nil else {
                print("The model could not make a decision!")
                return
            }
            
            self.navigationController?.pushViewController(ResultShowcase(predictions: predictions!, image: img), animated: true)
        }) //Send the image to the chosen classifier
    }
    
}

/*:
 Now, where we've created our simple interface, let's display it.
 */

//#-hidden-code
if #available(iOS 12, *) {} else {
    fatalError("This playground is optimized for iPadOS 13! Though it might run on iOS 12 as well, lower versions than that will likely not work correctly.")
}
//#-end-hidden-code
PlaygroundPage.current.liveView = UINavigationController(rootViewController: ViewController())

/*:
 ## That's it!
 Now, exactly *362* lines later, we have a fully working Image Classification Tool using __CoreML__ and __Vision__! Easy, isn't it?
 Although you will probably already have used these libraries a lot, I hope that this will help to convince some developers to have a closer look at the opportunities of AI and maybe start using it more often.
 
 ## What about the models?
 _But wait, don't I have to create complicated wrapper classes for communication with my model?_ No! You can just drag your _.mlmodel_ file into your existing _Xcode_ project and _Xcode_ will do all the work for you (i.e., creating wrapper classes and compiling the model).
 
 [Next](@next)
 */
