#=

Thin-veener over the VISA shared library.
See VPP-4.3.2 document for details.

=#


############################ Types #############################################

#Vi datatypes
#Cribbed from VPP-4.3.2 section 3.1 table and/or visa.h
#It's most likely we don't actually need all of these but they're easy to
#generate with some metaprogramming

for typePair = [("UInt32", Uint32),
				("Int32", Int32),
				("UInt64", Uint64),
				("Int64", Int64),
				("UInt16", Uint16),
				("Int16", Int16),
				("UInt8", Uint8),
				("Int8", Int8),
				("Addr", Void),
				("Char", Int8),
				("Byte", Uint8),
				("Boolean", Uint16),
				("Real32", Float32),
				("Real64", Float64),
				("Status", Int32),
				("Version", Uint32),
				("Object", Uint32),
				("Session", Uint32)
				]

	viTypeName = symbol("Vi"*typePair[1])
	viConsructorName = symbol("vi"*typePair[1])
	viPTypeName = symbol("ViP"*typePair[1])
	viATypeName = symbol("ViA"*typePair[1])
	@eval begin
		typealias $viTypeName $typePair[2]
		$viConsructorName(x) = convert($viTypeName, x)
		typealias $viPTypeName Ptr{$viTypeName}
		typealias $viATypeName Array{$viTypeName, 1}
	end
end

for typePair = [("Buf", "PByte"),
				("String", "PChar"),
				("Rsrc", "String")
				]
	viTypeName = symbol("Vi"*typePair[1])
	viPTypeName = symbol("ViP"*typePair[1])
	viATypeName = symbol("ViA"*typePair[1])

	mappedViType = symbol("Vi"*typePair[2])

	@eval begin
		typealias $viTypeName $mappedViType
		typealias $viPTypeName $mappedViType
		typealias $viATypeName Array{$viTypeName, 1}
	end
end

typealias ViEvent ViObject
typealias ViPEvent Ptr{ViEvent}
typealias ViFindList ViObject
typealias ViPFindList Ptr{ViFindList}
typealias ViString ViPChar
typealias ViRsrc ViString
typealias ViBuf ViPByte;
typealias ViAccessMode ViUInt32
typealias ViAttr ViUInt32


########################## Constants ###########################################

# Completion and Error Codes ----------------------------------------------*/
include("codes.jl")

#Atributes and other definitions
include("constants.jl")


######################### Functions ############################################

#Helper macro to make VISA call and check the status for an error
macro check_status(viCall)
	return quote
		status = $viCall
		if status < VI_SUCCESS
			errMsg = codes[status]
			error("VISA C call failed with status $(errMsg[1]): $(errMsg[2])")
		end
		status
	end
end



#- Resource Manager Functions and Operations -------------------------------#
function viOpenDefaultRM()
	rm = ViSession[0]
	@check_status ccall((:viOpenDefaultRM, "visa64"), ViStatus, (ViPSession,), pointer(rm))
	rm[1]
end

function viFindRsrc(sesn::ViSession, expr::String)
	returnCount = ViUInt32[0]
	findList = ViFindList[0]
	desc = Array(ViChar, VI_FIND_BUFLEN)
	@check_status ccall((:viFindRsrc, "visa64"), ViStatus,
						(ViSession, ViString, ViPFindList, ViPUInt32, ViPChar),
						sesn, expr, findList, returnCount, desc)

	#Create the array of instrument strings and push them on
	instrStrs = ASCIIString[bytestring(convert(Ptr{Uint8}, pointer(desc)))]
	while (returnCount[1] > 1)
		@check_status ccall((:viFindNext, "visa64"), ViStatus,
						(ViFindList, ViPChar), findList[1], desc)
		returnCount[1] -= 1
		push!(instrStrs, bytestring(convert(Ptr{Uint8}, pointer(desc))))
	end

	instrStrs
end



# ViStatus _VI_FUNC  viParseRsrc     (ViSession rmSesn, ViRsrc rsrcName,
#                                     ViPUInt16 intfType, ViPUInt16 intfNum);
# ViStatus _VI_FUNC  viParseRsrcEx   (ViSession rmSesn, ViRsrc rsrcName, ViPUInt16 intfType,
#                                     ViPUInt16 intfNum, ViChar _VI_FAR rsrcClass[],
#                                     ViChar _VI_FAR expandedUnaliasedName[],
#                                     ViChar _VI_FAR aliasIfExists[]);


function viOpen(sesn::ViSession, name::ASCIIString; mode::ViAccessMode=VI_NO_LOCK, timeout::ViUInt32=VI_TMO_IMMEDIATE)
	#Pointer for the instrument handle
	instrHandle = ViSession[0]
	@check_status ccall((:viOpen, "visa64"), ViStatus,
						(ViSession, ViRsrc, ViAccessMode, ViUInt32, ViPSession),
						sesn, name, mode, timeout, instrHandle)
	instrHandle[1]
end

function viClose(viObj::ViObject)
	@check_status ccall((:viClose, "visa64"), ViStatus, (ViObject,), viObj)
end




# #- Resource Template Operations --------------------------------------------*/

function viSetAttribute(viObj::ViObject, attrName::ViAttr, attrValue::ViAttrState)
	@check_status ccall((:viSetAttribute, "visa64"), ViStatus,
						(ViObject, ViAttr, ViAttrState),
						viObj, attrName, attrValue)
end

function viGetAttribute(viObj::ViObject, attrName::ViAttr)
	value = ViAttrState[0]
	@check_status ccall((:viGetAttribute, "visa64"), ViStatus,
						(ViObject, ViAttr, Ptr{Void}),
						viObj, attrName, value)
	value[0]
end

# ViStatus _VI_FUNC  viStatusDesc    (ViObject vi, ViStatus status, ViChar _VI_FAR desc[]);
# ViStatus _VI_FUNC  viTerminate     (ViObject vi, ViUInt16 degree, ViJobId jobId);

# ViStatus _VI_FUNC  viLock          (ViSession vi, ViAccessMode lockType, ViUInt32 timeout,
#                                     ViKeyId requestedKey, ViChar _VI_FAR accessKey[]);
# ViStatus _VI_FUNC  viUnlock        (ViSession vi);
# ViStatus _VI_FUNC  viEnableEvent   (ViSession vi, ViEventType eventType, ViUInt16 mechanism,
#                                     ViEventFilter context);
# ViStatus _VI_FUNC  viDisableEvent  (ViSession vi, ViEventType eventType, ViUInt16 mechanism);
# ViStatus _VI_FUNC  viDiscardEvents (ViSession vi, ViEventType eventType, ViUInt16 mechanism);
# ViStatus _VI_FUNC  viWaitOnEvent   (ViSession vi, ViEventType inEventType, ViUInt32 timeout,
#                                     ViPEventType outEventType, ViPEvent outContext);
# ViStatus _VI_FUNC  viInstallHandler(ViSession vi, ViEventType eventType, ViHndlr handler,
#                                     ViAddr userHandle);
# ViStatus _VI_FUNC  viUninstallHandler(ViSession vi, ViEventType eventType, ViHndlr handler,
#                                       ViAddr userHandle);



#- Basic I/O Operations ----------------------------------------------------#

function viWrite(instrHandle::ViSession, data::Union(ASCIIString, Vector{Uint8}))
	bytesWritten = ViUInt32[0]
	@check_status ccall((:viWrite, "visa64"), ViStatus,
						(ViSession, ViBuf, ViUInt32, ViPUInt32),
						instrHandle, data, length(data), bytesWritten)
	bytesWritten[1]
end

function viRead(instrHandle::ViSession; bufSize::Uint32=0x00000400)
	bytesRead = ViUInt32[0]
	buffer = Array(Uint8, bufSize)
	@check_status ccall((:viRead, "visa64"), ViStatus,
						(ViSession, ViBuf, ViUInt32, ViPUInt32),
						instrHandle, buffer, bufSize, bytesRead)
	buffer[1:bytesRead[1]]
end


# ViStatus _VI_FUNC  viReadAsync     (ViSession vi, ViPBuf buf, ViUInt32 cnt, ViPJobId  jobId);
# ViStatus _VI_FUNC  viReadToFile    (ViSession vi, ViConstString filename, ViUInt32 cnt,
#                                     ViPUInt32 retCnt);
# ViStatus _VI_FUNC  viWriteAsync    (ViSession vi, ViBuf  buf, ViUInt32 cnt, ViPJobId  jobId);
# ViStatus _VI_FUNC  viWriteFromFile (ViSession vi, ViConstString filename, ViUInt32 cnt,
#                                     ViPUInt32 retCnt);
# ViStatus _VI_FUNC  viAssertTrigger (ViSession vi, ViUInt16 protocol);
# ViStatus _VI_FUNC  viReadSTB       (ViSession vi, ViPUInt16 status);
# ViStatus _VI_FUNC  viClear         (ViSession vi);
