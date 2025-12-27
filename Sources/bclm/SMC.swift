//
// SMC.swift
// Battery Charge Level Max (BCLM) - Apple Silicon
//
// Based on SMCKit by beltex (MIT License)
// Adapted for Apple Silicon by tarunkumarmahato
//

import IOKit
import Foundation

// MARK: - Type Aliases

/// 32-byte SMC data buffer
public typealias SMCBytes = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                             UInt8, UInt8, UInt8, UInt8)

// MARK: - Standard Library Extensions

extension UInt32 {
    init(fromBytes bytes: (UInt8, UInt8, UInt8, UInt8)) {
        let byte0 = UInt32(bytes.0) << 24
        let byte1 = UInt32(bytes.1) << 16
        let byte2 = UInt32(bytes.2) << 8
        let byte3 = UInt32(bytes.3)
        self = byte0 | byte1 | byte2 | byte3
    }
}

public extension FourCharCode {
    init(fromString str: String) {
        precondition(str.count == 4)
        self = str.utf8.reduce(0) { sum, character in
            return sum << 8 | UInt32(character)
        }
    }
    
    init(fromStaticString str: StaticString) {
        precondition(str.utf8CodeUnitCount == 4)
        self = str.withUTF8Buffer { buffer in
            let byte0 = UInt32(buffer[0]) << 24
            let byte1 = UInt32(buffer[1]) << 16
            let byte2 = UInt32(buffer[2]) << 8
            let byte3 = UInt32(buffer[3])
            return byte0 | byte1 | byte2 | byte3
        }
    }
    
    func toString() -> String {
        return String(describing: UnicodeScalar(self >> 24 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 16 & 0xff)!) +
               String(describing: UnicodeScalar(self >> 8  & 0xff)!) +
               String(describing: UnicodeScalar(self       & 0xff)!)
    }
}

// MARK: - SMC Param Struct (defined by AppleSMC.kext)

/// Struct for communicating with the AppleSMC driver
/// Size must be exactly 80 bytes
public struct SMCParamStruct {
    
    /// I/O Kit function selector
    public enum Selector: UInt8 {
        case kSMCHandleYPCEvent  = 2
        case kSMCReadKey         = 5
        case kSMCWriteKey        = 6
        case kSMCGetKeyFromIndex = 8
        case kSMCGetKeyInfo      = 9
    }
    
    /// Return codes
    public enum Result: UInt8 {
        case kSMCSuccess     = 0
        case kSMCError       = 1
        case kSMCKeyNotFound = 132
    }
    
    public struct SMCVersion {
        var major: CUnsignedChar = 0
        var minor: CUnsignedChar = 0
        var build: CUnsignedChar = 0
        var reserved: CUnsignedChar = 0
        var release: CUnsignedShort = 0
    }
    
    public struct SMCPLimitData {
        var version: UInt16 = 0
        var length: UInt16 = 0
        var cpuPLimit: UInt32 = 0
        var gpuPLimit: UInt32 = 0
        var memPLimit: UInt32 = 0
    }
    
    public struct SMCKeyInfoData {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }
    
    var key: UInt32 = 0
    var vers = SMCVersion()
    var pLimitData = SMCPLimitData()
    var keyInfo = SMCKeyInfoData()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                           UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                           UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                           UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                           UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0), UInt8(0),
                           UInt8(0), UInt8(0))
}

// MARK: - SMC Data Types

public struct DataTypes {
    public static let Flag =
                 DataType(type: FourCharCode(fromStaticString: "flag"), size: 1)
    public static let UInt8 =
                 DataType(type: FourCharCode(fromStaticString: "ui8 "), size: 1)
    public static let UInt32 =
                 DataType(type: FourCharCode(fromStaticString: "ui32"), size: 4)
}

public struct SMCKey {
    let code: FourCharCode
    let info: DataType
}

public struct DataType: Equatable {
    let type: FourCharCode
    let size: UInt32
}

// MARK: - SMCKit

/// Apple System Management Controller (SMC) client
public struct SMCKit {
    
    public enum SMCError: Error, CustomStringConvertible {
        case driverNotFound
        case failedToOpen
        case keyNotFound(code: String)
        case notPrivileged
        case unknown(kIOReturn: kern_return_t, SMCResult: UInt8)
        
        public var description: String {
            switch self {
            case .driverNotFound:
                return "AppleSMC driver not found"
            case .failedToOpen:
                return "Failed to open connection to AppleSMC driver"
            case .keyNotFound(let code):
                return "SMC key '\(code)' not found"
            case .notPrivileged:
                return "Requires root privileges (run with sudo)"
            case .unknown(let kIOReturn, let SMCResult):
                return "Unknown error: kIOReturn=\(kIOReturn), SMCResult=\(SMCResult)"
            }
        }
    }
    
    /// Connection to the SMC driver
    fileprivate static var connection: io_connect_t = 0
    
    /// Open connection to the SMC driver
    public static func open() throws {
        // Use the appropriate port constant based on macOS version
        let mainPort: mach_port_t
        if #available(macOS 12.0, *) {
            mainPort = kIOMainPortDefault
        } else {
            mainPort = 0 // kIOMasterPortDefault value
        }
        
        let service = IOServiceGetMatchingService(mainPort,
                                                  IOServiceMatching("AppleSMC"))
        
        if service == 0 { throw SMCError.driverNotFound }
        
        let result = IOServiceOpen(service, mach_task_self_, 0,
                                   &SMCKit.connection)
        IOObjectRelease(service)
        
        if result != kIOReturnSuccess { throw SMCError.failedToOpen }
    }
    
    /// Close connection to the SMC driver
    @discardableResult
    public static func close() -> Bool {
        let result = IOServiceClose(SMCKit.connection)
        return result == kIOReturnSuccess
    }
    
    /// Get information about a key
    public static func keyInformation(_ key: FourCharCode) throws -> DataType {
        var inputStruct = SMCParamStruct()
        
        inputStruct.key = key
        inputStruct.data8 = SMCParamStruct.Selector.kSMCGetKeyInfo.rawValue
        
        let outputStruct = try callDriver(&inputStruct)
        
        return DataType(type: outputStruct.keyInfo.dataType,
                        size: outputStruct.keyInfo.dataSize)
    }
    
    public static func getKey(_ code: String, type: DataType) -> SMCKey {
        return SMCKey(code: FourCharCode(fromString: code), info: type)
    }
    
    /// Read data of a key
    public static func readData(_ key: SMCKey) throws -> SMCBytes {
        var inputStruct = SMCParamStruct()
        
        inputStruct.key = key.code
        inputStruct.keyInfo.dataSize = UInt32(key.info.size)
        inputStruct.data8 = SMCParamStruct.Selector.kSMCReadKey.rawValue
        
        let outputStruct = try callDriver(&inputStruct)
        
        return outputStruct.bytes
    }
    
    /// Write data for a key
    public static func writeData(_ key: SMCKey, data: SMCBytes) throws {
        var inputStruct = SMCParamStruct()
        
        inputStruct.key = key.code
        inputStruct.bytes = data
        inputStruct.keyInfo.dataSize = UInt32(key.info.size)
        inputStruct.data8 = SMCParamStruct.Selector.kSMCWriteKey.rawValue
        
        _ = try callDriver(&inputStruct)
    }
    
    /// Make an actual call to the SMC driver
    public static func callDriver(_ inputStruct: inout SMCParamStruct,
                        selector: SMCParamStruct.Selector = .kSMCHandleYPCEvent)
                                                      throws -> SMCParamStruct {
        assert(MemoryLayout<SMCParamStruct>.stride == 80, "SMCParamStruct size is != 80")
        
        var outputStruct = SMCParamStruct()
        let inputStructSize = MemoryLayout<SMCParamStruct>.stride
        var outputStructSize = MemoryLayout<SMCParamStruct>.stride
        
        let result = IOConnectCallStructMethod(SMCKit.connection,
                                               UInt32(selector.rawValue),
                                               &inputStruct,
                                               inputStructSize,
                                               &outputStruct,
                                               &outputStructSize)
        
        switch result {
        case kIOReturnSuccess:
            if outputStruct.result == SMCParamStruct.Result.kSMCSuccess.rawValue {
                return outputStruct
            } else if outputStruct.result == SMCParamStruct.Result.kSMCKeyNotFound.rawValue {
                throw SMCError.keyNotFound(code: inputStruct.key.toString())
            }
            throw SMCError.unknown(kIOReturn: result, SMCResult: outputStruct.result)
        case kIOReturnNotPrivileged:
            throw SMCError.notPrivileged
        default:
            throw SMCError.unknown(kIOReturn: result, SMCResult: outputStruct.result)
        }
    }
}

// Removed duplicate toString extension - already defined in FourCharCode extension above
