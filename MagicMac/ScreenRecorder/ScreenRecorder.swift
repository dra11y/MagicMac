//
//  ScreenRecorder.swift
//  MagicMac
//
//  Created by Tom Grushka on 4/19/24.
//

import AVFoundation
import CoreGraphics
import ScreenCaptureKit
import VideoToolbox

var screenRecorder: ScreenRecorder?

struct ScreenRecorder {
    public let url: URL
    
    private let videoSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.VideoSampleBufferQueue")
    private let audioSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.AudioSampleBufferQueue")
    private let assetWriter: AVAssetWriter
    private let videoInput: AVAssetWriterInput
    private let audioInput: AVAssetWriterInput
    private let streamOutput: StreamOutput
    private var stream: SCStream
    
    static func toggle() async throws {
        do {
            if let sr = screenRecorder {
                try await sr.stop()
                print("Recording ended, opening video")
                NSWorkspace.shared.open(sr.url)
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
            let cropRect = CGRect(x: 100, y: 100, width: 760, height: 200)
            screenRecorder = try await ScreenRecorder(url: url, displayID: CGMainDisplayID(), cropRect: cropRect, mode: .h264_sRGB)

            print("Starting screen recording of main display")
            try await screenRecorder!.start()
        } catch {
            print("Error during recording:", error)
        }
    }
    
    private init(url: URL, displayID: CGDirectDisplayID, cropRect: CGRect?, mode: RecordMode) async throws {
        self.url = url
        self.assetWriter = try AVAssetWriter(url: url, fileType: .mp4)

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
        if let videoProfileLevel = mode.videoProfileLevel {
            var compressionProperties: [String: Any] = videoSettings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
            compressionProperties[AVVideoProfileLevelKey] = videoProfileLevel
            videoSettings[AVVideoCompressionPropertiesKey] = compressionProperties as NSDictionary
        }

        // Create AVAssetWriter input for video, based on the output settings from the Assistant
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        print("videoSettings: \(videoSettings)")
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

        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        print("audioSettings: \(audioSettings)")
        audioInput.expectsMediaDataInRealTime = true

        streamOutput = StreamOutput(videoInput: videoInput, audioInput: audioInput)

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
        stream = SCStream(filter: filter, configuration: configuration, delegate: streamOutput)
        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
        try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
    }

    func start() async throws {
        // Start capturing, wait for stream to start
        try await stream.startCapture()

        // Start the AVAssetWriter session at source time .zero, sample buffers will need to be re-timed
        assetWriter.startSession(atSourceTime: .zero)
        streamOutput.sessionStarted = true
    }

    func stop() async throws {
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
        await assetWriter.finishWriting()
    }

    private class StreamOutput: NSObject, SCStreamOutput, SCStreamDelegate{
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
                    print("AVAssetWriterInput isn't ready, dropping frame")
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
                    print("Couldn't copy CMSampleBuffer, dropping frame")
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
                        print("Couldn't copy CMSampleBuffer, dropping frame")
                    }
                    
                } else {
                    print("TG: Audio Buffer NOT READY")
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
