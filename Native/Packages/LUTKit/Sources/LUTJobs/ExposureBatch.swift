import Foundation
import CryptoKit
import LUTCore
import LUTFormats

// Public aliases preserve the job API while project storage shares the same model.
public typealias ExposureBatchError = ExposureBatchFailure
public typealias ExposureBatchSettings = ExposureBatchSequence

public struct ExposureBatchItem:Sendable {
    public let index:Int,stop:Double,filename:String,url:URL,request:LUTGenerationRequest
}
public struct ExposureBatchRequest:Sendable {
    public let settings:ExposureBatchSettings
    public let format:FileLUTFormat
    public let threeDLFlavor:ThreeDLFlavor
    public let allowOverwrite:Bool
    public let items:[ExposureBatchItem]
    public let fingerprint:String
    public init(base:LUTGenerationRequest,settings:ExposureBatchSettings,directory:URL,basename:String,
                format:FileLUTFormat,allowOverwrite:Bool = false,threeDLFlavor:ThreeDLFlavor = .flame)throws {
        guard directory.isFileURL else { throw ExposureBatchError.invalidFilename }
        guard format == .threeDL || threeDLFlavor == .flame else { throw ThreeDLFailure(.unsupported) }
        let filenames = try settings.filenames(basename: basename, fileExtension: format.rawValue)
        var items:[ExposureBatchItem]=[]
        for (index,stop) in settings.stops.enumerated() {
            let filename = filenames[index]
            let plan=try TransformPlan(settings:base.plan.settings.withExposureStops(stop))
            let request=try LUTGenerationRequest(plan:plan,size:base.size,domain:base.domain,blockNodes:base.blockNodes,
                workerCount:base.workerCount,postLUT:base.postLUT,postLUTSettings:base.postLUTSettings,
                inputShaper:base.inputShaper,
                inputTransferInverse:base.inputTransferInverse,
                inputAffineInverse:base.inputAffineInverse)
            items.append(ExposureBatchItem(index:index,stop:stop,filename:filename,
                url:directory.standardizedFileURL.appendingPathComponent(filename),request:request))
        }
        self.settings=settings;self.format=format;self.threeDLFlavor=threeDLFlavor;self.allowOverwrite=allowOverwrite;self.items=items
        fingerprint=try Self.identity(base:base,settings:settings,directory:directory,basename:basename,format:format,overwrite:allowOverwrite,threeDLFlavor:threeDLFlavor)
    }
    private struct Identity:Codable {
        let algorithm:String,planVersion:String,settings:TransformSettings,size:Int,domain:LUTDomain,blockNodes:Int,workerCount:Int
        let batch:ExposureBatchSettings,directory:URL,basename:String,format:FileLUTFormat,overwrite:Bool,postSettings:UserLUTPostStageSettings?,inputTransferInverse:String?,inputAffineInverse:String?
    }
    private struct UserIdentity:Codable {
        let dimension:Int,size:Int,domain:LUTDomain,shaperSize:Int?,shaperDomain:LUTDomain?
    }
    private struct InputShaperIdentity:Codable {
        let algorithm:String,size:Int,domain:LUTDomain
    }
    private static func identity(base:LUTGenerationRequest,settings:ExposureBatchSettings,directory:URL,basename:String,format:FileLUTFormat,overwrite:Bool,threeDLFlavor:ThreeDLFlavor)throws->String {
        let encoder=JSONEncoder();encoder.outputFormatting=[.sortedKeys,.withoutEscapingSlashes]
        var hasher=SHA256()
        func update(_ data:Data) {
            var length=UInt64(data.count).littleEndian
            withUnsafeBytes(of:&length){hasher.update(bufferPointer:$0)};hasher.update(data:data)
        }
        update(try encoder.encode(Identity(algorithm:ExposureBatchSettings.algorithm,planVersion:base.plan.planVersion,settings:base.plan.settings,
            size:base.size,domain:base.domain,blockNodes:base.blockNodes,workerCount:base.workerCount,batch:settings,
            directory:directory.standardizedFileURL,basename:basename,format:format,overwrite:overwrite,
            postSettings:base.postLUTSettings,
            inputTransferInverse:base.inputTransferInverse?.interpolation.rawValue,
            inputAffineInverse:base.inputAffineInverse?.contentFingerprint)))
        if let lut=base.postLUT {
            update(try encoder.encode(UserIdentity(dimension:lut.dimension.rawValue,size:lut.size,domain:lut.domain,shaperSize:lut.shaper?.size,shaperDomain:lut.shaper?.domain)))
            for samples in [lut.samples,lut.shaper?.samples ?? []] {
                var count=UInt64(samples.count).littleEndian;withUnsafeBytes(of:&count){hasher.update(bufferPointer:$0)}
                for sample in samples {for c in 0..<3{var bits=sample[c].bitPattern.littleEndian;withUnsafeBytes(of:&bits){hasher.update(bufferPointer:$0)}}}
            }
        }else{update(Data())}
        // Preserve existing fingerprints when there is no input shaper. New
        // shaped requests bind the interpolation, domain and every Double bit
        // pattern so checkpoints cannot mix different generation inputs.
        if let shaper=base.inputShaper {
            update(try encoder.encode(InputShaperIdentity(algorithm:"input-shaper-trilinear.v1",
                size:shaper.size,domain:shaper.domain)))
            for sample in shaper.samples {
                for c in 0..<3 {
                    var bits=sample[c].bitPattern.littleEndian
                    withUnsafeBytes(of:&bits){hasher.update(bufferPointer:$0)}
                }
            }
        }
        // An interpolation name alone cannot identify an inverse transfer.
        // Keep prior un-inverted identities while rejecting unsafe old inverse
        // checkpoints that did not bind their effective samples and domain.
        if let inverse=base.inputTransferInverse {
            update(Data(inverse.contentFingerprint.utf8))
        }
        // Flame keeps the previously frozen default request fingerprint.
        if threeDLFlavor != .flame {
            update(Data((ThreeDLFlavor.batchAlgorithm + ":" + threeDLFlavor.rawValue).utf8))
        }
        return hasher.finalize().map{String(format:"%02x",$0)}.joined()
    }
}
public protocol ExposureBatchExporter:Sendable {
    func generate(_ request:LUTGenerationRequest,to output:URL,allowOverwrite:Bool)async throws->Int
    func generate(_ request:LUTGenerationRequest,to output:URL,allowOverwrite:Bool,
                  threeDLFlavor:ThreeDLFlavor)async throws->Int
}
public enum ExposureBatchExportError:Error,Equatable,Sendable {
    case unsupportedThreeDLFlavor
}
public extension ExposureBatchExporter {
    /// Existing adapters retain the default grammar but cannot silently drop a
    /// newly requested non-default grammar.
    func generate(_ request:LUTGenerationRequest,to output:URL,allowOverwrite:Bool,
                  threeDLFlavor:ThreeDLFlavor)async throws->Int {
        guard threeDLFlavor == .flame else { throw ExposureBatchExportError.unsupportedThreeDLFlavor }
        return try await generate(request,to:output,allowOverwrite:allowOverwrite)
    }
}
public enum ExposureBatchItemState:String,Codable,Sendable {case pending,running,completed,cancelled,failed}
public struct ExposureBatchItemReport:Equatable,Codable,Sendable {
    public let index:Int,stop:Double,filename:String
    public let state:ExposureBatchItemState
    public let writtenNodes:Int?,fileFingerprint:String?,failureDescription:String?
}
public struct ExposureBatchReport:Equatable,Codable,Sendable {
    public let schemaVersion:Int,algorithm:String,requestFingerprint:String
    public let state:JobState
    public let items:[ExposureBatchItemReport]
}

/// Files commit independently through the existing bounded writer. A failure
/// or cancellation leaves prior committed outputs available for verified retry.
public actor ExposureBatchCoordinator {
    public private(set) var state:JobState = .queued
    public private(set) var report:ExposureBatchReport?
    public init(){}
    public func generate(_ request: ExposureBatchRequest, exporter: any ExposureBatchExporter,
                         checkpoint: ExposureBatchCheckpointStore, resuming: Bool = false) async throws -> ExposureBatchReport {
        guard state == .queued else { throw ExposureBatchError.alreadyStarted }
        state = .running
        do {
            let end = try await checkpoint.generate(request, exporter: exporter, resuming: resuming)
            report = end; state = end.state
            return end
        } catch {
            state = error is CancellationError ? .cancelled : .failed
            throw error
        }
    }
    public func generate(_ request:ExposureBatchRequest,exporter:any ExposureBatchExporter,
                         resumeFrom:ExposureBatchReport? = nil)async throws->ExposureBatchReport {
        guard state == .queued else{throw ExposureBatchError.alreadyStarted}
        var results=request.items.map{ExposureBatchItemReport(index:$0.index,stop:$0.stop,filename:$0.filename,state:.pending,writtenNodes:nil,fileFingerprint:nil,failureDescription:nil)}
        if let previous=resumeFrom {
            guard previous.schemaVersion==1,previous.algorithm==ExposureBatchSettings.algorithm,
                  previous.requestFingerprint==request.fingerprint,previous.items.count==results.count else{throw ExposureBatchError.checkpointMismatch}
            for i in results.indices {
                let old=previous.items[i],item=request.items[i]
                guard old.index==i,old.stop.bitPattern==item.stop.bitPattern,old.filename==item.filename else{throw ExposureBatchError.checkpointMismatch}
                if old.state == .completed {
                    guard old.writtenNodes==Self.expectedNodes(item,format:request.format),old.fileFingerprint != nil else{throw ExposureBatchError.checkpointMismatch}
                    guard (try? LocalFileCommit.fingerprint(item.url))==old.fileFingerprint else{throw ExposureBatchError.completedOutputChanged(i)}
                    results[i]=old
                }
            }
        }
        func snapshot(_ status:JobState)->ExposureBatchReport {
            ExposureBatchReport(schemaVersion:1,algorithm:ExposureBatchSettings.algorithm,requestFingerprint:request.fingerprint,state:status,items:results)
        }
        state = .running;report=snapshot(state)
        for i in results.indices where results[i].state != .completed {
            let item=request.items[i]
            do {
                try Task.checkCancellation()
                results[i]=ExposureBatchItemReport(index:i,stop:item.stop,filename:item.filename,state:.running,writtenNodes:nil,fileFingerprint:nil,failureDescription:nil)
                report=snapshot(state)
                let nodes=try await exporter.generate(item.request,to:item.url,allowOverwrite:request.allowOverwrite,
                    threeDLFlavor:request.threeDLFlavor)
                guard nodes==Self.expectedNodes(item,format:request.format) else{throw JobFailure.rowCountMismatch}
                // Do not check cancellation after publication: commit success is
                // recorded before cancellation can stop the following file.
                let identity=try LocalFileCommit.fingerprint(item.url)
                results[i]=ExposureBatchItemReport(index:i,stop:item.stop,filename:item.filename,state:.completed,writtenNodes:nodes,fileFingerprint:identity,failureDescription:nil)
                report=snapshot(state)
            }catch {
                let cancelled=error is CancellationError
                results[i]=ExposureBatchItemReport(index:i,stop:item.stop,filename:item.filename,state:cancelled ? .cancelled : .failed,
                    writtenNodes:nil,fileFingerprint:nil,failureDescription:String(describing:error))
                state=cancelled ? .cancelled : .failed;let end=snapshot(state);report=end;return end
            }
        }
        state = .completed;let end=snapshot(state);report=end;return end
    }
    static func expectedNodes(_ item:ExposureBatchItem,format:FileLUTFormat)->Int {
        switch format {
        case .spi1d:1024
        case .ilut:ILUTParser.size
        case .olut:OLUTParser.size
        case .lut:4096
        default:item.request.size*item.request.size*item.request.size
        }
    }
}
