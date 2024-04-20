////
////  Screenshot.swift
////  MagicMac
////
////  Created by Tom Grushka on 4/19/24.
////
//
//// https://github.com/nonstrict-hq/ScreenCaptureKit-Recording-example/blob/main/Sources/sckrecording/main.swift
//
// import Cocoa
// import AVFoundation
// import CoreGraphics
// import ScreenCaptureKit
// import VideoToolbox
//
// let audioSampleRate = 48000
// let audioChannelCount = 2
//
// enum RecordMode {
//    case h264_sRGB
//    case hevc_displayP3
// }
//
// class ScreenRecorderManager {
//    private var screenRecorder: ScreenRecorder?
//
//    func recordScreen() async {
//
//
//        // Create a screen recording
//        do {
//            if let screenRecorder = screenRecorder {
//                try await screenRecorder.stop()
//
//                print("Recording ended, opening video")
//                NSWorkspace.shared.open(screenRecorder.url)
//
//                self.screenRecorder = nil
//
//                return
//            }
//
//            // Check for screen recording permission, make sure your terminal has screen recording permission
//            guard CGPreflightScreenCaptureAccess() else {
//                throw RecordingError("No screen capture permission")
//            }
//
//            let url = URL(filePath: "/Users/Tom/Desktop/recording-\(Date()).mp4")
//            let cropRect = CGRect(x: 100, y: 100, width: 700, height: 300)
//            screenRecorder = try await ScreenRecorder(url: url, displayID: CGMainDisplayID(), cropRect: cropRect, mode: .h264_sRGB)
//
//            print("Starting screen recording of main display")
//            try await screenRecorder?.start()
//        } catch {
//            print("Error during recording:", error)
//        }
//    }
// }
//
// struct ScreenRecorder {
//    public let url: URL
//
//    private let videoSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.VideoSampleBufferQueue")
//    private let audioSampleBufferQueue = DispatchQueue(label: "ScreenRecorder.AudioSampleBufferQueue")
//
//    private let assetWriter: AVAssetWriter
//    private let videoInput: AVAssetWriterInput
//    private let audioInput: AVAssetWriterInput
//    private let streamOutput: StreamOutput
//    private var stream: SCStream
//
//    init(url: URL, displayID: CGDirectDisplayID, cropRect: CGRect?, mode: RecordMode) async throws {
//        self.url = url
//
//        // Create AVAssetWriter for an MP4 movie file
//        self.assetWriter = try AVAssetWriter(url: url, fileType: .mp4)
//
//        // MARK: AVAssetWriter setup
//
//        // Get size and pixel scale factor for display
//        // Used to compute the highest possible qualitiy
//        let displaySize = CGDisplayBounds(displayID).size
//
//        // The number of physical pixels that represent a logic point on screen, currently 2 for MacBook Pro retina displays
//        let displayScaleFactor: Int = 1
////        if let mode = CGDisplayCopyDisplayMode(displayID) {
////            displayScaleFactor = mode.pixelWidth / mode.width
////        } else {
////            displayScaleFactor = 1
////        }
//
//        // AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
//        // Downsize to fit a larger display back into in 4K
//        let videoSize = downsizedVideoSize(source: cropRect?.size ?? displaySize, scaleFactor: displayScaleFactor, mode: mode)
//
//        // Use the preset as large as possible, size will be reduced to screen size by computed videoSize
//        guard let settingsAssistant = AVOutputSettingsAssistant(preset: mode.preset) else {
//            throw RecordingError("Can't create AVOutputSettingsAssistant")
//        }
//        settingsAssistant.sourceVideoFormat = try CMVideoFormatDescription(videoCodecType: mode.videoCodecType, width: videoSize.width, height: videoSize.height)
//
//        guard var videoOutputSettings = settingsAssistant.videoSettings else {
//            throw RecordingError("AVOutputSettingsAssistant has no videoSettings")
//        }
//        videoOutputSettings[AVVideoWidthKey] = videoSize.width
//        videoOutputSettings[AVVideoHeightKey] = videoSize.height
//
//        // Configure video color properties and compression properties based on RecordMode
//        // See AVVideoSettings.h and VTCompressionProperties.h
//        videoOutputSettings[AVVideoColorPropertiesKey] = mode.videoColorProperties
//        if let videoProfileLevel = mode.videoProfileLevel {
//            var compressionProperties: [String: Any] = videoOutputSettings[AVVideoCompressionPropertiesKey] as? [String: Any] ?? [:]
//            compressionProperties[AVVideoProfileLevelKey] = videoProfileLevel
//            videoOutputSettings[AVVideoCompressionPropertiesKey] = compressionProperties as NSDictionary
//        }
//
//        // Create AVAssetWriter input for video, based on the output settings from the Assistant
//        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoOutputSettings)
//        videoInput.expectsMediaDataInRealTime = true
//
//        // Adding videoInput to assetWriter
//        guard assetWriter.canAdd(videoInput) else {
//            throw RecordingError("Can't add videoInput to asset writer")
//        }
//        assetWriter.add(videoInput)
//
//        // Create AVAssetWriter input for audio
//        let audioOutputSettings: [String: Any] = [
////            AVFormatIDKey: kAudioFormatMPEG4AAC_HE,
//            AVFormatIDKey: kAudioFormatMPEG4AAC,
//            AVNumberOfChannelsKey: audioChannelCount,
//            AVSampleRateKey: audioSampleRate
//        ]
//        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioOutputSettings)
//        audioInput.expectsMediaDataInRealTime = true
//
//        // Add Mic Input:
//        // https://github.com/Mnpn/MagicMac/blob/main/MagicMac/Processing.swift
//
//        // Add audio input to the asset writer
//        if assetWriter.canAdd(audioInput) {
//            assetWriter.add(audioInput)
//        }
//
//        guard assetWriter.startWriting() else {
//            if let error = assetWriter.error {
//                throw error
//            }
//            throw RecordingError("Couldn't start writing to AVAssetWriter")
//        }
//
//        // MARK: SCStream setup
//
//        // Create a filter for the specified display
//        let sharableContent = try await SCShareableContent.current
//
//        print(sharableContent.applications.map { $0.applicationName })
//
//        guard let display = sharableContent.displays.first(where: { $0.displayID == displayID }) else {
//            throw RecordingError("Can't find display with ID \(displayID) in sharable content")
//        }
//
//        guard let voiceOver = sharableContent.applications.first(where: { $0.applicationName == "VoiceOver" })
//        else {
//            throw RecordingError("Can't VoiceOver application!")
//        }
//
//        let filter = SCContentFilter(display: display, including: [voiceOver], exceptingWindows: [])
//
//        let config = SCStreamConfiguration()
//
//        // Increase the depth of the frame queue to ensure high fps at the expense of increasing
//        // the memory footprint of WindowServer.
//        config.queueDepth = 6 // 4 minimum, or it becomes very stuttery
//        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
//
//        // Make sure to take displayScaleFactor into account
//        // otherwise, image is scaled up and gets blurry
//        if let cropRect = cropRect {
//            // ScreenCaptureKit uses top-left of screen as origin
//            config.sourceRect = cropRect
//            config.width = Int(cropRect.width) * displayScaleFactor
//            config.height = Int(cropRect.height) * displayScaleFactor
//        } else {
//            config.width = Int(displaySize.width) * displayScaleFactor
//            config.height = Int(displaySize.height) * displayScaleFactor
//        }
//
//        // Set pixel format an color space, see CVPixelBuffer.h
//        switch mode {
//        case .h264_sRGB:
//            config.pixelFormat = kCVPixelFormatType_32BGRA // 'BGRA'
//            config.colorSpaceName = CGColorSpace.sRGB
//        case .hevc_displayP3:
//            config.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
//            config.colorSpaceName = CGColorSpace.displayP3
////        case .hevc_displayP3_HDR:
////            configuration.pixelFormat = kCVPixelFormatType_ARGB2101010LEPacked // 'l10r'
////            configuration.colorSpaceName = CGColorSpace.displayP3
//        }
//
//        config.capturesAudio = true
//        config.showsCursor = true
//        config.sampleRate = audioSampleRate
//        config.channelCount = audioChannelCount
//
//        streamOutput = StreamOutput(videoInput: videoInput, audioInput: audioInput)
//
//        // Create SCStream and add local StreamOutput object to receive samples
//        stream = SCStream(filter: filter, configuration: config, delegate: streamOutput)
//        try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: videoSampleBufferQueue)
//        try stream.addStreamOutput(streamOutput, type: .audio, sampleHandlerQueue: audioSampleBufferQueue)
//    }
//
//    func start() async throws {
//        // Start capturing, wait for stream to start
//        try await stream.startCapture()
//
//        // Start the AVAssetWriter session at source time .zero, sample buffers will need to be re-timed
//        assetWriter.startSession(atSourceTime: .zero)
//        streamOutput.sessionStarted = true
//    }
//
//    func stop() async throws {
//        // Stop capturing, wait for stream to stop
//        try await stream.stopCapture()
//
//        // Repeat the last frame and add it at the current time
//        // In case no changes happend on screen, and the last frame is from long ago
//        // This ensures the recording is of the expected length
//        if let originalBuffer = streamOutput.lastSampleBuffer {
//            let additionalTime = CMTime(seconds: ProcessInfo.processInfo.systemUptime, preferredTimescale: 100) - streamOutput.firstSampleTime
//            let timing = CMSampleTimingInfo(duration: originalBuffer.duration, presentationTimeStamp: additionalTime, decodeTimeStamp: originalBuffer.decodeTimeStamp)
//            let additionalSampleBuffer = try CMSampleBuffer(copying: originalBuffer, withNewTiming: [timing])
//            videoInput.append(additionalSampleBuffer)
//            streamOutput.lastSampleBuffer = additionalSampleBuffer
//        }
//
//        // Stop the AVAssetWriter session at time of the repeated frame
//        assetWriter.endSession(atSourceTime: streamOutput.lastSampleBuffer?.presentationTimeStamp ?? .zero)
//
//        // Finish writing
//        videoInput.markAsFinished()
//        audioInput.markAsFinished()
//        await assetWriter.finishWriting()
//    }
//
//    private class StreamOutput: NSObject, SCStreamOutput, SCStreamDelegate {
//        let videoInput: AVAssetWriterInput
//        let audioInput: AVAssetWriterInput
//        var sessionStarted = false
//        var firstSampleTime: CMTime = .zero
//        var lastSampleBuffer: CMSampleBuffer?
//
//        init(videoInput: AVAssetWriterInput, audioInput: AVAssetWriterInput) {
//            self.videoInput = videoInput
//            self.audioInput = audioInput
//        }
//
//        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
//
//            // Return early if session hasn't started yet
//            guard sessionStarted else { return }
//
//            // Return early if the sample buffer is invalid
//            guard sampleBuffer.isValid else { return }
//
//            // Retrieve the array of metadata attachments from the sample buffer
//            guard let attachmentsArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
//                  let attachments = attachmentsArray.first
//            else { return }
//
//            // Validate the status of the frame. If it isn't `.complete`, return
//            guard let statusRawValue = attachments[SCStreamFrameInfo.status] as? Int,
//                  let status = SCFrameStatus(rawValue: statusRawValue),
//                  .complete == status
//            else { return }
//
//            switch type {
//            case .screen:
//                if !videoInput.isReadyForMoreMediaData {
//                    print("AVAssetWriterInput isn't ready, dropping frame")
//                    break
//                }
//                // Save the timestamp of the current sample, all future samples will be offset by this
//                if firstSampleTime == .zero {
//                    firstSampleTime = sampleBuffer.presentationTimeStamp
//                }
//
//                // Offset the time of the sample buffer, relative to the first sample
//                let lastSampleTime = sampleBuffer.presentationTimeStamp - firstSampleTime
//
//                // Always save the last sample buffer.
//                // This is used to "fill up" empty space at the end of the recording.
//                //
//                // Note that this permanently captures one of the sample buffers
//                // from the ScreenCaptureKit queue.
//                // Make sure reserve enough in SCStreamConfiguration.queueDepth
//                lastSampleBuffer = sampleBuffer
//
//                // Create a new CMSampleBuffer by copying the original, and applying the new presentationTimeStamp
//                let timing = CMSampleTimingInfo(duration: sampleBuffer.duration, presentationTimeStamp: lastSampleTime, decodeTimeStamp: sampleBuffer.decodeTimeStamp)
//                if let retimedSampleBuffer = try? CMSampleBuffer(copying: sampleBuffer, withNewTiming: [timing]) {
//                    videoInput.append(retimedSampleBuffer)
//                } else {
//                    print("Couldn't copy CMSampleBuffer, dropping frame")
//                }
//
//            case .audio:
//                print("HANDLE AUDIO SAMPLE")
//                if audioInput.isReadyForMoreMediaData {
//                    audioInput.append(sampleBuffer)
//                }
//                break
//
//            @unknown default:
//                break
//            }
//        }
//    }
// }
//
//
//// AVAssetWriterInput supports maximum resolution of 4096x2304 for H.264
// private func downsizedVideoSize(source: CGSize, scaleFactor: Int, mode: RecordMode) -> (width: Int, height: Int) {
//    let maxSize = mode.maxSize
//
//    let w = source.width * Double(scaleFactor)
//    let h = source.height * Double(scaleFactor)
//    let r = max(w / maxSize.width, h / maxSize.height)
//
//    return r > 1
//        ? (width: Int(w / r), height: Int(h / r))
//        : (width: Int(w), height: Int(h))
// }
//
// struct RecordingError: Error, CustomDebugStringConvertible {
//    var debugDescription: String
//    init(_ debugDescription: String) { self.debugDescription = debugDescription }
// }
//
//// Extension properties for values that differ per record mode
// extension RecordMode {
//    var preset: AVOutputSettingsPreset {
//        switch self {
//        case .h264_sRGB: return .preset3840x2160
//        case .hevc_displayP3: return .hevc1920x1080
//        }
//    }
//
//    var maxSize: CGSize {
//        switch self {
//        case .h264_sRGB: return CGSize(width: 4096, height: 2304)
////        case .hevc_displayP3: return CGSize(width: 7680, height: 4320)
//        case .hevc_displayP3: return CGSize(width: 1920, height: 1080)
////        case .hevc_displayP3_HDR: return CGSize(width: 7680, height: 4320)
//        }
//    }
//
//    var videoCodecType: CMFormatDescription.MediaSubType {
//        switch self {
//        case .h264_sRGB: return .h264
//        case .hevc_displayP3: return .hevc
////        case .hevc_displayP3_HDR: return .hevc
//        }
//    }
//
//    var videoColorProperties: NSDictionary {
//        switch self {
//        case .h264_sRGB:
//            return [
//                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
//                AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
//                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
//            ]
//        case .hevc_displayP3:
//            return [
//                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
//                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
//                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
//            ]
////        case .hevc_displayP3_HDR:
////            return [
////                AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_2100_HLG,
////                AVVideoColorPrimariesKey: AVVideoColorPrimaries_P3_D65,
////                AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_2020,
////            ]
//        }
//    }
//
//    var videoProfileLevel: CFString? {
//        switch self {
//        case .h264_sRGB:
//            return nil
//        case .hevc_displayP3:
//            return nil
////        case .hevc_displayP3_HDR:
////            return kVTProfileLevel_HEVC_Main10_AutoLevel
//        }
//    }
// }
//
// struct Screenshot {
//    static func getDevices() {
//        let session = AVCaptureDevice.DiscoverySession.init(deviceTypes: [.microphone, .external], mediaType: .audio, position: .unspecified)
//        for device in session.devices {
//            print("device=\(device.localizedName), id=\(device.uniqueID)")
//        }
//    }
// }
