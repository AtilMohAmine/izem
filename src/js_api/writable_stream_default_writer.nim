import tables, sequtils, algorithm, strutils, json, asyncdispatch
import ../js_bindings, ../js_utils, ../js_constants, ../js_private_data, writable_stream

var writableStreamDefaultWriterClassRef: JSClassRef

proc writableStreamDefaultWriterConstructor(ctx: JSContextRef, constructor: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSObjectRef {.cdecl.} =
  if argumentCount < 1:
    setJSException(ctx, exception, "WritableStreamDefaultWriter constructor requires a WritableStream argument")
    return NULL_JS_OBJECT

  let streamObj = JSValueToObject(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0], exception)
  if streamObj == NULL_JS_OBJECT:
    return NULL_JS_OBJECT

  var writer = new(WritableStreamDefaultWriter)
  GC_ref(writer)
  writer.stream = streamObj

  writer.closed = JSObjectMakeDeferredPromise(ctx, addr writer.closedResolve, addr writer.closedReject, exception)

  writer.ready = JSObjectMakeDeferredPromise(ctx, addr writer.readyResolve, addr writer.readyReject, exception)

  let result = JSObjectMake(ctx, writableStreamDefaultWriterClassRef, nil)
  if result == NULL_JS_OBJECT:
    echo "Failed to create JSObject"
  else:
    setPrivateData(result, cast[pointer](writer))
  result

proc writableStreamDefaultWriterClose(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let writer = cast[WritableStreamDefaultWriter](getPrivateData(thisObject))
  if writer.isNil:
    setJSException(ctx, exception, "Invalid WritableStreamDefaultWriter")
    return JSValueMakeUndefined(ctx)

  # Call the close method on the underlying stream
  let closeMethod = JSObjectGetProperty(ctx, writer.stream, JSStringCreateWithUTF8CString("close"), exception)
  if JSValueIsObject(ctx, closeMethod) and JSObjectIsFunction(ctx, cast[JSObjectRef](closeMethod)):
    return JSObjectCallAsFunction(ctx, cast[JSObjectRef](closeMethod), writer.stream, 0, nil, exception)
  else:
    setJSException(ctx, exception, "WritableStream does not have an close method")
    return JSValueMakeUndefined(ctx)

proc writableStreamDefaultWriterAbort(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let writer = cast[WritableStreamDefaultWriter](getPrivateData(thisObject))
  if writer.isNil:
    setJSException(ctx, exception, "Invalid WritableStreamDefaultWriter")
    return JSValueMakeUndefined(ctx)

  var reason: JSValueRef
  if argumentCount > 0:
    reason = cast[ptr UncheckedArray[JSValueRef]](arguments)[0]
  else:
    reason = JSValueMakeUndefined(ctx)

  # Call the abort method on the underlying stream
  let abortMethod = JSObjectGetProperty(ctx, writer.stream, JSStringCreateWithUTF8CString("abort"), exception)
  if JSValueIsObject(ctx, abortMethod) and JSObjectIsFunction(ctx, cast[JSObjectRef](abortMethod)):
    return JSObjectCallAsFunction(ctx, cast[JSObjectRef](abortMethod), writer.stream, 1, addr reason, exception)
  else:
    setJSException(ctx, exception, "WritableStream does not have an abort method")
    return JSValueMakeUndefined(ctx)

proc writableStreamDefaultWriterReleaseLock(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let writer = cast[WritableStreamDefaultWriter](getPrivateData(thisObject))
  if writer.isNil:
    setJSException(ctx, exception, "Invalid WritableStreamDefaultWriter")
    return JSValueMakeUndefined(ctx)

  let stream = cast[WritableStream](getPrivateData(writer.stream))
  if stream.isNil:
    setJSException(ctx, exception, "Invalid WritableStream")
    return JSValueMakeUndefined(ctx)

  if stream.writer != thisObject:
    setJSException(ctx, exception, "This writer is not associated with the stream")
    return JSValueMakeUndefined(ctx)

  if stream.inFlightWriteRequest != NULL_JS_OBJECT or stream.inFlightCloseRequest != NULL_JS_OBJECT:
    setJSException(ctx, exception, "Cannot release lock with pending write or close")
    return JSValueMakeUndefined(ctx)

  # Release the lock
  stream.locked = false
  stream.writer = NULL_JS_OBJECT

  # Reset writer properties
  writer.stream = NULL_JS_OBJECT
  
  JSValueMakeUndefined(ctx)

proc writableStreamDefaultWriterGetDesiredSize(ctx: JSContextRef, writer: WritableStreamDefaultWriter, exception: ptr JSValueRef): float =
  let stream = cast[WritableStream](getPrivateData(writer.stream))
  if stream.isNil:
    setJSException(ctx, exception, "Invalid WritableStream")
    return 0

  if stream.state == "errored":
    return -1
  elif stream.state == "closed":
    return 0
  else:
    # Calculate the desired size based on the high water mark and the total size of the buffered data
    var highWaterMark: float
    if stream.strategy == NULL_JS_OBJECT:
      highWaterMark = 1
    else:
      let highWaterMarkFunc = JSObjectGetProperty(ctx, stream.strategy, JSStringCreateWithUTF8CString("highWaterMark"), exception)
      if JSValueIsNumber(ctx, highWaterMarkFunc):
        highWaterMark = JSValueToNumber(ctx, highWaterMarkFunc, exception)
      else:
        highWaterMark = 1

    var totalSize: float = 0
    for request in stream.writeRequests:
      let chunkSize = JSObjectGetProperty(ctx, request, JSStringCreateWithUTF8CString("size"), exception)
      if JSValueIsNumber(ctx, chunkSize):
        totalSize += JSValueToNumber(ctx, chunkSize, exception)

    let desiredSize = highWaterMark - totalSize
    return desiredSize

proc processNextWrite(ctx: JSContextRef, stream: WritableStream, exception: ptr JSValueRef) {.async.} =
  
  if stream.writeRequests.len > 0 and stream.inFlightWriteRequest == NULL_JS_OBJECT:
    # Check the desired size and apply backpressure if necessary
    let writer = cast[WritableStreamDefaultWriter](getPrivateData(stream.writer))
    var desiredSize = writableStreamDefaultWriterGetDesiredSize(ctx, writer, exception)
    if desiredSize <= 0:
      stream.backpressure = true

    let nextWrite = stream.writeRequests[0]
    stream.writeRequests.delete(0)
    stream.inFlightWriteRequest = nextWrite
  
    let chunk = JSObjectGetProperty(ctx, nextWrite, JSStringCreateWithUTF8CString("chunk"), exception)

    discard await callUnderlyingSinkMethod(ctx, stream, "write", @[chunk, cast[JSValueRef](stream.writer)], exception)
    
    stream.inFlightWriteRequest = NULL_JS_OBJECT
    let resolveFunc = JSObjectGetProperty(ctx, nextWrite, JSStringCreateWithUTF8CString("resolve"), exception)
    discard JSObjectCallAsFunction(ctx, cast[JSObjectRef](resolveFunc), NULL_JS_OBJECT, 0, nil, exception)
    
    # Check the desired size and update backpressure
    desiredSize = writableStreamDefaultWriterGetDesiredSize(ctx, writer, exception)
    if desiredSize > 0 and stream.backpressure:
      stream.backpressure = false
      discard JSObjectCallAsFunction(ctx, cast[JSObjectRef](writer.readyResolve), NULL_JS_OBJECT, 0, nil, exception)
    
    if not stream.backpressure and stream.pendingRequests.len > 0:
      stream.writeRequests.add(stream.pendingRequests[0])
      stream.pendingRequests.delete(0)

    if stream.writeRequests.len == 0 and stream.inFlightCloseRequest != NULL_JS_OBJECT:
      # All writes are complete, so process the close request
      discard callUnderlyingSinkMethod(ctx, stream, "close", @[cast[JSValueRef](stream.writer)], exception)
      stream.state = "closed"
      
      # Resolve the stored close promise
      discard JSObjectCallAsFunction(ctx, stream.inFlightCloseRequestResolve, NULL_JS_OBJECT, 0, nil, exception)

      discard JSObjectCallAsFunction(ctx, writer.closedResolve, NULL_JS_OBJECT, 0, nil, exception)

      # Clear the close request
      stream.inFlightCloseRequest = NULL_JS_OBJECT

    discard processNextWrite(ctx, stream, exception)
  
proc writableStreamDefaultWriterWrite(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let writer = cast[WritableStreamDefaultWriter](getPrivateData(thisObject))
  if writer.isNil:
    setJSException(ctx, exception, "Invalid WritableStreamDefaultWriter")
    return JSValueMakeUndefined(ctx)

  let stream = cast[WritableStream](getPrivateData(writer.stream))
  if stream.isNil:
    setJSException(ctx, exception, "Invalid WritableStream")
    return JSValueMakeUndefined(ctx)

  if stream.state != "writable":
    setJSException(ctx, exception, "WritableStream is not in a writable state")
    return JSValueMakeUndefined(ctx)

  var chunk = JSValueMakeUndefined(ctx)
  if argumentCount > 0:
    chunk = cast[ptr UncheckedArray[JSValueRef]](arguments)[0]

  var resolveFunc, rejectFunc: JSObjectRef
  result = cast[JSValueRef](JSObjectMakeDeferredPromise(ctx, addr resolveFunc, addr rejectFunc, exception))

  # Calculate the chunk size using the queuing strategy
  var chunkSize: float
  if stream.strategy == NULL_JS_OBJECT:
    chunkSize = 1
  else:
    let sizeFunc = JSObjectGetProperty(ctx, stream.strategy, JSStringCreateWithUTF8CString("size"), exception)
    if JSValueIsObject(ctx, sizeFunc) and JSObjectIsFunction(ctx, cast[JSObjectRef](sizeFunc)):
      let sizeResult = JSObjectCallAsFunction(ctx, cast[JSObjectRef](sizeFunc), stream.strategy, 1, addr chunk, exception)
      if JSValueIsNumber(ctx, sizeResult):
        chunkSize = JSValueToNumber(ctx, sizeResult, exception)
      else:
        chunkSize = 1
    else:
      chunkSize = 1

  # Create a write request object
  let writeRequest = JSObjectMake(ctx, NULL_JS_CLASS, nil)
  JSObjectSetProperty(ctx, writeRequest, JSStringCreateWithUTF8CString("chunk"), chunk, kJSPropertyAttributeNone, exception)
  JSObjectSetProperty(ctx, writeRequest, JSStringCreateWithUTF8CString("size"), JSValueMakeNumber(ctx, chunkSize), kJSPropertyAttributeNone, exception)
  JSObjectSetProperty(ctx, writeRequest, JSStringCreateWithUTF8CString("resolve"), cast[JSValueRef](resolveFunc), kJSPropertyAttributeNone, exception)
  JSObjectSetProperty(ctx, writeRequest, JSStringCreateWithUTF8CString("reject"), cast[JSValueRef](rejectFunc), kJSPropertyAttributeNone, exception)

  if not stream.backpressure:
    # Add write request to the queue
    if stream.pendingRequests.len > 0:
      stream.writeRequests.add(stream.pendingRequests[0])
      stream.pendingRequests.delete(0)
      let desiredSize = writableStreamDefaultWriterGetDesiredSize(ctx, writer, exception)
      stream.backpressure = desiredSize <= 0
      if not stream.backpressure:
        stream.writeRequests.add(writeRequest)
      else:
        stream.pendingRequests.add(writeRequest)
    else:
      stream.writeRequests.add(writeRequest)
    let desiredSize = writableStreamDefaultWriterGetDesiredSize(ctx, writer, exception)
    stream.backpressure = desiredSize <= 0

    asyncCheck processNextWrite(ctx, stream, exception)

  else:
    stream.pendingRequests.add(writeRequest)
  return result

proc writableStreamDefaultWriterGetProperty(ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let writer = cast[WritableStreamDefaultWriter](getPrivateData(obj))

  let name = jsStringToNimStr(propertyName)
  case name
  of "closed": result = cast[JSValueRef](writer.closed)
  of "desiredSize": result = JSValueMakeNumber(ctx, writableStreamDefaultWriterGetDesiredSize(ctx, writer, exception))
  of "ready": result = cast[JSValueRef](writer.ready)
 
  of "write": result = cast[JSValueRef](JSObjectMakeFunctionWithCallback(ctx, propertyName, writableStreamDefaultWriterWrite))
  of "abort": result = cast[JSValueRef](JSObjectMakeFunctionWithCallback(ctx, propertyName, writableStreamDefaultWriterAbort))
  of "close": result = cast[JSValueRef](JSObjectMakeFunctionWithCallback(ctx, propertyName, writableStreamDefaultWriterClose))
  of "releaseLock": result = cast[JSValueRef](JSObjectMakeFunctionWithCallback(ctx, propertyName, writableStreamDefaultWriterReleaseLock))

  else: result = JSValueMakeUndefined(ctx)

proc writableStreamDefaultWriterGetPropertyNames(ctx: JSContextRef, obj: JSObjectRef, propertyNames: JSPropertyNameAccumulatorRef) {.cdecl.} =
  let properties = ["closed", "desiredSize", "ready", "abort", "close", "releaseLock", "write"]
  for prop in properties:
    JSPropertyNameAccumulatorAddName(propertyNames, JSStringCreateWithUTF8CString(prop.cstring))

proc createWritableStreamDefaultWriterClass*(ctx: JSContextRef) =
  let classdef = JSClassDefinition(
    version: 0,
    attributes: kJSClassAttributeNone,
    className: "WritableStreamDefaultWriter",
    parentClass: nil,
    staticValues: nil,
    staticFunctions: nil,
    initialize: nil,
    finalize: proc (obj: JSObjectRef) {.cdecl.} =
      let writer = cast[WritableStreamDefaultWriter](getPrivateData(obj))
      if not writer.isNil:
        GC_unref(writer)
      removePrivateData(obj),
    hasProperty: nil,
    getProperty: writableStreamDefaultWriterGetProperty,
    setProperty: nil,
    deleteProperty: nil,
    getPropertyNames: writableStreamDefaultWriterGetPropertyNames,
    callAsFunction: nil,
    callAsConstructor: writableStreamDefaultWriterConstructor,
    hasInstance: nil,
    convertToType: nil
  )

  writableStreamDefaultWriterClassRef = JSClassCreate(addr classdef)
  
  let constructor = JSObjectMakeConstructor(ctx, writableStreamDefaultWriterClassRef, writableStreamDefaultWriterConstructor)
  setPrivateData(constructor, cast[pointer](writableStreamDefaultWriterClassRef))

  let globalObject = JSContextGetGlobalObject(ctx)
  JSObjectSetProperty(ctx, globalObject, JSStringCreateWithUTF8CString("WritableStreamDefaultWriter"), cast[JSValueRef](constructor), kJSPropertyAttributeNone, nil)
