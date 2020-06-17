/*:
# Welcome!
Welcome to my submission for the _WWDC 2020 Student Swift Challenge_! This submission is all about __CoreML__ and __Vision__, respectively machine learning in general. Furthermore, this playground is intended to demonstrate how uncomplicated and (kind of) easy it actually is to use artificial intelligence within iOS/iPadOS applications using Apple's _CoreML_ and _Vision_ API as many developers - in my opinion - still haven't taken a closer look at this topic (e.g., by thinking this topic was too complicated for them). But this is not the case (especially with the many benefits AI offers) as there are many pre-trained machine learning models available for free (moreover, it is also possible to convert Keras or Tensorflow models to CoreML). This is what I want to demonstrate in an interactive way by showing several possible ways of implementing an image classification tool using the _MobileNet_ image classification model available for free at Apple's website or on GitHub. _MobileNetv2_ is licensed under the conditions of the Apache License Version 2.0.

 # Table of Contents
 - [Intruduction](Introduction)
 - [Processing single photos](Static)
 - [Processing live camera video using Vision](Live)
 - [Exercise: live camera video using CoreML directly](Live-CoreML)
 - [Solutions](Solutions)
 - [Epilogue](Epilogue)
 - [Full Sources: Processing single photos*](FullSource-Static)
 - [Full Sources: Processing live camera video*](FullSource-Live)
 
 *: _To keep the code clear, parts of the source code are hidden. If you want to read through the full source code, refer to these pages. Otherwise, they have almost the same functionality as their clear counterparts._
 ## Tests
 I tested this playground with several _iPad Airs (1st, 2nd and 3rd generation, running either iOS 12.4.6 or iPadOS 13.4.5)_ as well as with Swift Playgrounds and Xcode on MacOS 10.15.4. As I do not have an iPad Pro, I could not test my code on these devices directly but - of course - it should work on these as well.
 ## Requirements
 This playground should run on devices with iOS 11 and above.
 ## Frameworks
 Within this playground, I used the following frameworks:
 - UIKit
 - CoreML
 - Vision
 - AVFoundation
 - CoreVideo
 - CoreGraphics
 - (PlaygroundSupport)
 
 [Next: Processing single photos](@next)
 */
