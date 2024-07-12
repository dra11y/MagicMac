//
//  ScreenRecorder.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/19/24.
//

import Accelerate
import AVFoundation
import CoreGraphics
import OSLog
import ScreenCaptureKit
import VideoToolbox

fileprivate let logger = Logger(subsystem: "MagicMac", category: "ScreenRecorder")

// Recording to disk using ScreenCaptureKit
// NO AUDIO recording - "interesting edge cases" and example:
// https://nonstrict.eu/blog/2023/recording-to-disk-with-screencapturekit/
// https://github.com/nonstrict-hq/ScreenCaptureKit-Recording-example

// Azayaka
// AUDIO RECORDING example
// https://github.com/Mnpn/Azayaka/blob/main/Azayaka/Processing.swift

let cropRect = CGRect(
    x: 150,
    y: 40,
    width: 1300,
    height: 400
)

var screenRecorder: ScreenRecorder?

class ScreenRecorder {
    private let videoSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.VideoSampleBufferQueue")
    private let audioSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.AudioSampleBufferQueue")

    public var url: URL?
    
    private var assetWriter: AVAssetWriter?
    
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var micInput: AVAssetWriterInput?
    private var streamOutput: StreamOutput?
    private lazy var audioEngine = AVAudioEngine()
    private var stream: SCStream?
    private var recordMic: Bool = true
    
    private var initialized: Bool = false
    
    public init() { }
    
    static func toggle(partial: Bool) async throws {
        do {
            if let sr = screenRecorder {
                try await sr.stop()
                logger.info("Recording ended, opening video")
                if let url = sr.url {
                    NSWorkspace.shared.open(url)
                }
                screenRecorder = nil
                return
            }

//            // Check for screen recording permission, make sure your terminal has screen recording permission
//            guard CGPreflightScreenCaptureAccess() else {
//                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
//                throw RecordingError("No screen capture permission")
//            }

            lazy var userDesktop = (NSSearchPathForDirectoriesInDomains(.desktopDirectory, .userDomainMask, true) as [String]).first!
            // the `com.apple.screencapture` domain has the user set path for where they want to store screenshots or videos
            let saveDirectory = UserDefaults(suiteName: "com.apple.screencapture")?.string(forKey: "location") ?? userDesktop

            let url = URL(filePath: saveDirectory).appending(path: "recording \(Date()).mp4")
            let sr = ScreenRecorder()
            try await sr.initialize(url: url, displayID: CGMainDisplayID(), cropRect: partial ? cropRect : nil, mode: .h264_sRGB)
            screenRecorder = sr

            logger.info("Starting screen recording of main display")
            try await screenRecorder!.start()
        } catch {
            logger.info("Error during recording: \(error)")
        }
    }
    
    private func initialize(url: URL, displayID: CGDirectDisplayID, cropRect: CGRect?, mode: RecordMode) async throws {
        if initialized {
            throw RecordingError("ScreenRecorder instance already initialized!")
        }
        initialized = true
        
        self.url = url
        
        let assetWriter = try AVAssetWriter(url: url, fileType: .mp4)
        self.assetWriter = assetWriter
        
        // MARK: AVAssetWriter setup

        // Get size and pixel scale factor for display
        // Used to compute the highest possible quality
        let displaySize = CGDisplayBounds(displayID).size

        // The number of physical pixels that represent a logic point on screen, currently 2 for MacBook Pro retina displays
        let displayScaleFactor: Int = 1
//        if let mode = CGDisplayCopyDisplayMode(displayID) {
//            displayScaleFactor = mode.pixelWidth / mode.width
//        } else {
//            displayScaleFactor = 1
//        }

        // AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
        // Downsize to fit a larger display back into in 4K
        let videoSize = downsizedVideoSize(source: cropRect?.size ?? displaySize, scaleFactor: displayScaleFactor, mode: mode)

        // Use the preset as large as possible, size will be reduced to screen size by computed videoSize
        guard let assistant = AVOutputSettingsAssistant(preset: mode.preset) else {
            throw RecordingError("Can't create AVOutputSettingsAssistant")
        }
        assistant.sourceVideoFormat = try CMVideoFormatDescription(videoCodecType: mode.videoCodecType, width: videoSize.width, height: videoSize.height)

        guard var videoSettings = assistant.videoSettings else {
            throw RecordingError("AVOutputSettingsAssistant has no videoSettings")
        }
        guard var audioSettings = assistant.audioSettings else {
            throw RecordingError("AVOutputSettingsAssistant has no audioSettings")
        }
        
        // Configure video color properties and compression properties based on RecordMode
        // See AVVideoSettings.h and VTCompressionProperties.h
        videoSettings[AVVideoColorPropertiesKey] = mode.videoColorProperties
        videoSettings[AVVideoCompressionPropertiesKey] = [
            AVVideoAverageBitRateKey: 100000,
            AVVideoMaxKeyFrameIntervalKey: 30
        ]
        if let videoProfileLevel = mode.videoProfileLevel {
            var compressionProperties: [String: Any] = videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
            compressionProperties[AVVideoProfileLevelKey] = videoProfileLevel
            videoSettings[AVVideoCompressionPropertiesKey] = compressionProperties as NSDictionary
        }

        // Create AVAssetWriter input for video, based on the output settings from the Assistant
        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        self.videoInput = videoInput
        logger.info("videoSettings: \(videoSettings)")
        videoInput.expectsMediaDataInRealTime = true
        
        audioSettings[AVSampleRateKey] = 48000
        audioSettings[AVNumberOfChannelsKey] = 2
//        audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC_HE
        audioSettings[AVFormatIDKey] = kAudioFormatMPEG4AAC
        
//        let audioSettings: [String: Any] = [
//            AVSampleRateKey: 48000,
//            AVNumberOfChannelsKey: 2,
//            AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
//            AVEncoderBitRateKey: 128000,
//        ]

        let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        self.audioInput = audioInput
        logger.info("audioSettings: \(audioSettings)")
        audioInput.expectsMediaDataInRealTime = true

        let streamOutput = StreamOutput(videoInput: videoInput, audioInput: audioInput)
        self.streamOutput = streamOutput

        // Adding videoInput to assetWriter
        guard assetWriter.canAdd(videoInput) else {
            throw RecordingError("Can't add videoInput to asset writer")
        }
        assetWriter.add(videoInput)

        // Adding audioInput to assetWriter
        guard assetWriter.canAdd(audioInput) else {
            throw RecordingError("Can't add audioInput to asset writer")
        }
        assetWriter.add(audioInput)

        if recordMic {
            let micInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            self.micInput = micInput

            guard assetWriter.canAdd(micInput) else {
                throw RecordingError("Can't add micInput to asset writer")
            }
            assetWriter.add(micInput)
            
            let input = audioEngine.inputNode
            input.installTap(onBus: 0, bufferSize: 1024, format: input.inputFormat(forBus: 0)) { (buffer, time) in
                return;
                if micInput.isReadyForMoreMediaData && streamOutput.sessionStarted {
                    let sampleBuffer = buffer.asSampleBuffer!
                    micInput.append(sampleBuffer)
                    let arraySize = Int(buffer.frameLength)
                    var channelSamples: [[DSPComplex]] = []
                    let channelCount = Int(buffer.format.channelCount)

                    for i in 0..<channelCount {

                        channelSamples.append([])
                        let firstSample = buffer.format.isInterleaved ? i : i*arraySize

                        for j in stride(from: firstSample, to: arraySize, by: buffer.stride*2) {

                            let channels = UnsafeBufferPointer(start: buffer.floatChannelData, count: Int(buffer.format.channelCount))
                            let floats = UnsafeBufferPointer(start: channels[0], count: Int(buffer.frameLength))
                            channelSamples[i].append(DSPComplex(real: floats[j], imag: floats[j+buffer.stride]))

                        }
                    }

                    var spectrum = [Float]()

                    for i in 0..<arraySize/2 {

                        let imag = channelSamples[0][i].imag
                        let real = channelSamples[0][i].real
                        let magnitude = sqrt(pow(real,2)+pow(imag,2))

                        spectrum.append(magnitude)
                    }
                    
                    logger.info("spectrum: \(spectrum.reduce(0, +) / Float(spectrum.count))")

                }
            }
            try! audioEngine.start()
        }

        guard assetWriter.startWriting() else {
            if let error = assetWriter.error {
                throw error
            }
            throw RecordingError("Couldn't start writing to AVAssetWriter")
        }

        // MARK: SCStream setup

        // Create a filter for the specified display
        let sharableContent = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
        guard let display = sharableContent.displays.first(where: { $0.displayID == displayID }) else {
            throw RecordingError("Can't find display with ID \(displayID) in sharable content")
        }
//        logger.info(sharableContent.applications.map { $0.applicationName })
        // DOES NOT GRAB VOICEOVER SOUND OR VIDEO!:
//        guard
//            let chrome = sharableContent.applications.first(where: { $0.applicationName == "Google Chrome" })
//        else {
//            throw RecordingError("Google Chrome is not running.")
//        }
//        let filter = SCContentFilter(display: display, including: [chrome], exceptingWindows: [])
        let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])

        let configuration = SCStreamConfiguration()

        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
        // the memory footprint of WindowServer.
        configuration.queueDepth = 6 // 4 minimum, or it becomes very stuttery
        configuration.capturesAudio = true
        configuration.excludesCurrentProcessAudio = false
        configuration.showsCursor = true
        configuration.sampleRate = audioSettings[AVSampleRateKey] as! Int
        configuration.channelCount = audioSettings[AVNumberOfChannelsKey] as! Int
        
        // Make sure to take displayScaleFactor into account
        // otherwise, image is scaled up and gets blurry
        if let cropRect = cropRect {
            // ScreenCaptureKit uses top-left of screen as origin
            configuration.sourceRect = cropRect
            configuration.width = Int(cropRect.width) * displayScaleFactor
            configuration.height = Int(cropRect.height) * displayScaleFactor
        } else {
            configuration.width = Int(displaySize.width) * displayScaleFactor
            configuration.height = Int(displaySize.height) * displayScaleFactor
        }

        // Set pixel format an color space, see CVPixelBuffer.h
        switch mode {
        case .h264_sRGB:
            configuration.pixelFormat = kCVPixelFormatType_32BGRA // 'BGRA'
            configuration.colorSpaceName = CGColorSpace.sRGB
        case .hevc_displayP3:
            configuration.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
            configuration.colorSpaceName = CGColorSpace.displayP3
        }

        // Create SCStream and add local StreamOutput object to receive samples
        let stream = SCStream(filter: filter, configuration: configuration, delegate: streamOutput)
        self.stream = stream
        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
        try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
    }

    func start() async throws {
        guard 
            let stream = stream,
            let assetWriter = assetWriter,
            let streamOutput = streamOutput
        else {
            throw RecordingError("No stream!")
        }
        
        // Start capturing, wait for stream to start
        try await stream.startCapture()

        // Start the AVAssetWriter session at source time .zero, sample buffers will need to be re-timed
        assetWriter.startSession(atSourceTime: .zero)
        streamOutput.sessionStarted = true
    }

    func stop() async throws {
        guard
            let stream = stream,
            let assetWriter = assetWriter,
            let streamOutput = streamOutput,
            let videoInput = videoInput,
            let audioInput = audioInput
        else {
            throw RecordingError("No stream!")
        }

        // Stop capturing, wait for stream to stop
        try await stream.stopCapture()

        // Repeat the last frame and add it at the current time
        // In case no changes happend on screen, and the last frame is from long ago
        // This ensures the recording is of the expected length
        if let originalBuffer = streamOutput.lastVideoBuffer {
            let additionalTime = CMTime(seconds: ProcessInfo.processInfo.systemUptime, preferredTimescale: 100) - streamOutput.firstVideoSampleTime
            let timing = CMSampleTimingInfo(duration: originalBuffer.duration, presentationTimeStamp: additionalTime, decodeTimeStamp: originalBuffer.decodeTimeStamp)
            let additionalSampleBuffer = try CMSampleBuffer(copying: originalBuffer, withNewTiming: [timing])
            videoInput.append(additionalSampleBuffer)
            streamOutput.lastVideoBuffer = additionalSampleBuffer
        }

        // Stop the AVAssetWriter session at time of the repeated frame
        assetWriter.endSession(atSourceTime: streamOutput.lastVideoBuffer?.presentationTimeStamp ?? .zero)

        // Finish writing
        videoInput.markAsFinished()
        audioInput.markAsFinished()
        if recordMic {
            if let micInput = micInput {
                micInput.markAsFinished()
            }
            audioEngine.inputNode.removeTap(onBus: 0)
            audioEngine.stop()
        }
        await assetWriter.finishWriting()
    }

    private class StreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
        let videoInput: AVAssetWriterInput
        let audioInput: AVAssetWriterInput
        var sessionStarted = false
        var firstVideoSampleTime: CMTime = .zero
        var firstAudioSampleTime: CMTime = .zero
        var lastVideoBuffer: CMSampleBuffer?

        init(videoInput: AVAssetWriterInput, audioInput: AVAssetWriterInput) {
            self.videoInput = videoInput
            self.audioInput = audioInput
        }

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            
            // Return early if session hasn't started yet
            guard sessionStarted else { return }

            // Return early if the sample buffer is invalid
            guard sampleBuffer.isValid else { return }

            switch type {
            case .screen:
                // Retrieve the array of metadata attachments from the sample buffer
                guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
                      let attachments = attachmentsArray.first
                else { return }

                // Validate the status of the frame. If it isn't `.complete`, return
                guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
                      let status = SCFrameStatus(rawValue: statusRawValue),
                      status == .complete
                else { return }
                
                guard videoInput.isReadyForMoreMediaData else {
                    logger.info("AVAssetWriterInput isn't ready, dropping frame")
                    return
                }
                
                // Save the timestamp of the current sample, all future samples will be offset by this
                if firstVideoSampleTime == .zero {
                    firstVideoSampleTime = sampleBuffer.presentationTimeStamp
                }

                // Offset the time of the sample buffer, relative to the first sample
                let lastSampleTime = sampleBuffer.presentationTimeStamp - firstVideoSampleTime

                // Always save the last sample buffer.
                // This is used to "fill up" empty space at the end of the recording.
                //
                // Note that this permanently captures one of the sample buffers
                // from the ScreenCaptureKit queue.
                // Make sure reserve enough in SCStreamConfiguration.queueDepth
                lastVideoBuffer = sampleBuffer

                // Create a new CMSampleBuffer by copying the original, and applying the new presentationTimeStamp
                let timing = CMSampleTimingInfo(duration: sampleBuffer.duration, presentationTimeStamp: lastSampleTime, decodeTimeStamp: sampleBuffer.decodeTimeStamp)
                if let retimedSampleBuffer = try? CMSampleBuffer(copying: sampleBuffer, withNewTiming: [timing]) {
                    videoInput.append(retimedSampleBuffer)
                } else {
                    logger.info("Couldn't copy CMSampleBuffer, dropping frame")
                }

            case .audio:
                if audioInput.isReadyForMoreMediaData {
                    
                    // Save the timestamp of the current sample, all future samples will be offset by this
                    if firstAudioSampleTime == .zero {
                        firstAudioSampleTime = sampleBuffer.presentationTimeStamp
                    }

                    // Offset the time of the sample buffer, relative to the first sample
                    let lastSampleTime = sampleBuffer.presentationTimeStamp - firstAudioSampleTime

                    // Create a new CMSampleBuffer by copying the original, and applying the new presentationTimeStamp
                    let timing = CMSampleTimingInfo(duration: sampleBuffer.duration, presentationTimeStamp: lastSampleTime, decodeTimeStamp: sampleBuffer.decodeTimeStamp)
                    if let retimedSampleBuffer = try? CMSampleBuffer(copying: sampleBuffer, withNewTiming: [timing]) {
                        audioInput.append(retimedSampleBuffer)
                    } else {
                        logger.info("Couldn't copy CMSampleBuffer, dropping frame")
                    }
                    
                } else {
                    logger.info("TG: Audio Buffer NOT READY")
                }
                break

            @unknown default:
                break
            }
        }
    }
}

// AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
private func downsizedVideoSize(source: CGSize, scaleFactor: Int, mode: RecordMode) -> (width: Int, height: Int) {
    let maxSize = mode.maxSize

    let w = source.width * Double(scaleFactor)
    let h = source.height * Double(scaleFactor)
    let r = max(w / maxSize.width, h / maxSize.height)

    return r > 1
        ? (width: Int(w / r), height: Int(h / r))
        : (width: Int(w), height: Int(h))
}

struct RecordingError: Error, CustomDebugStringConvertible {
    var debugDescription: String
    init(_ debugDescription: String) { self.debugDescription = debugDescription }
}


// Based on https://gist.github.com/aibo-cora/c57d1a4125e145e586ecb61ebecff47c
extension AVAudioPCMBuffer {
    var asSampleBuffer: CMSampleBuffer? {
        let asbd = self.format.streamDescription
        var sampleBuffer: CMSampleBuffer? = nil
        var format: CMFormatDescription? = nil

        guard CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &format
        ) == noErr else { return nil }

        var timing = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: Int32(asbd.pointee.mSampleRate)),
            presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
            decodeTimeStamp: .invalid
        )

        guard CMSampleBufferCreate(
            allocator: kCFAllocatorDefault,
            dataBuffer: nil,
            dataReady: false,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: format,
            sampleCount: CMItemCount(self.frameLength),
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 0,
            sampleSizeArray: nil,
            sampleBufferOut: &sampleBuffer
        ) == noErr else { return nil }

        guard CMSampleBufferSetDataBufferFromAudioBufferList(
            sampleBuffer!,
            blockBufferAllocator: kCFAllocatorDefault,
            blockBufferMemoryAllocator: kCFAllocatorDefault,
            flags: 0,
            bufferList: self.mutableAudioBufferList
        ) == noErr else { return nil }

        return sampleBuffer
    }
}
