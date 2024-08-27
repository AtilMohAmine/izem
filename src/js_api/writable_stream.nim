import tables, sequtils, algorithm, strutils, json, asyncdispatch
import ../js_bindings, ../js_utils, ../js_constants, ../js_private_data

type
  WritableStream* = ref object
    locked*: bool
    underlyingSink*: JSObjectRef
    strategy*: JSObjectRef
    writer*: JSObjectRef
    state*: string # "writable", "closed", "erroring", or "errored"
    storedError*: JSValueRef
    closeRequest*: JSObjectRef
    inFlightWriteRequest*: JSObjectRef
    inFlightCloseRequest*: JSObjectRef
    inFlightCloseRequestResolve*: JSObjectRef
    inFlightCloseRequestReject*: JSObjectRef
    backpressure*: bool
    writeRequests*: seq[JSObjectRef]
    pendingRequests*: seq[JSObjectRef]

type
  WritableStreamDefaultWriter* = ref object
    stream*: JSObjectRef
    closed*: JSObjectRef  # Promise
    closedResolve*: JSObjectRef
    closedReject*: JSObjectRef
    ready*: JSObjectRef  # Promise
    readyResolve*: JSObjectRef
    readyReject*: JSObjectRef

var writableStreamClassRef: JSClassRef

proc callUnderlyingSinkMethod*(ctx: JSContextRef, stream: WritableStream, methodName: string, args: seq[JSValueRef], exception: ptr JSValueRef): Future[JSValueRef] {.async.} =
  let fn = JSObjectGetProperty(ctx, stream.underlyingSink, JSStringCreateWithUTF8CString(methodName), exception)
  await sleepAsync(0)
  if JSValueIsObject(ctx, fn) and JSObjectIsFunction(ctx, cast[JSObjectRef](fn)):
    result = JSObjectCallAsFunction(ctx, cast[JSObjectRef](fn), stream.underlyingSink, args.len.csize_t, addr args[0], exception)
  else:
    result = JSValueMakeUndefined(ctx)

proc createWritableStream(ctx: JSContextRef, underlyingSink: JSObjectRef, strategy: JSObjectRef): WritableStream =
  result = new(WritableStream)
  result.locked = false
  result.underlyingSink = underlyingSink
  result.strategy = strategy
  result.writer = NULL_JS_OBJECT
  result.state = "writable"
  result.storedError = JSValueMakeUndefined(ctx)
  result.inFlightWriteRequest = NULL_JS_OBJECT
  result.inFlightCloseRequestResolve = NULL_JS_OBJECT
  result.inFlightCloseRequestReject = NULL_JS_OBJECT
  result.inFlightCloseRequest = NULL_JS_OBJECT
  result.closeRequest = NULL_JS_OBJECT
  result.backpressure = false
  result.writeRequests = @[]
  result.pendingRequests = @[]

proc writableStreamConstructor(ctx: JSContextRef, constructor: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSObjectRef {.cdecl.} =
  var underlyingSink = NULL_JS_OBJECT
  var strategy = NULL_JS_OBJECT
  
  if argumentCount > 0:
    underlyingSink = JSValueToObject(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0], exception)
  if argumentCount > 1:
    strategy = JSValueToObject(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1], exception)

  let stream = createWritableStream(ctx, underlyingSink, strategy)
  GC_ref(stream)

  discard callUnderlyingSinkMethod(ctx, stream, "start", @[cast[JSValueRef](stream.writer)], exception)

  let result = JSObjectMake(ctx, writableStreamClassRef, nil)
  if result == NULL_JS_OBJECT:
    echo "Failed to create JSObject"
  else:
    setPrivateData(result, cast[pointer](stream))
  result

proc writableStreamAbort(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let stream = cast[WritableStream](getPrivateData(thisObject))
  if stream.isNil:
    setJSException(ctx, exception, "Invalid WritableStream")
    return JSValueMakeUndefined(ctx)

  var reason = JSValueMakeUndefined(ctx)
  if argumentCount > 0:
    reason = cast[ptr UncheckedArray[JSValueRef]](arguments)[0]

  if stream.state == "closed":
    var resolveFunc, rejectFunc: JSObjectRef
    result = cast[JSValueRef](JSObjectMakeDeferredPromise(ctx, addr resolveFunc, addr rejectFunc, exception))
    discard JSObjectCallAsFunction(ctx, resolveFunc, NULL_JS_OBJECT, 0, nil, exception)
    return result

  if stream.state == "errored":
    var resolveFunc, rejectFunc: JSObjectRef
    result = cast[JSValueRef](JSObjectMakeDeferredPromise(ctx, addr resolveFunc, addr rejectFunc, exception))
    discard JSObjectCallAsFunction(ctx, rejectFunc, cast[JSObjectRef](stream.storedError), 1, addr stream.storedError, exception)
    return result

  stream.state = "erroring"
  stream.storedError = reason

  # Cancel any pending write or close requests
  for request in stream.writeRequests:
    let rejectFunc = JSObjectGetProperty(ctx, request, JSStringCreateWithUTF8CString("reject"), exception)
    discard JSObjectCallAsFunction(ctx, cast[JSObjectRef](rejectFunc), NULL_JS_OBJECT, 1, addr reason, exception)
  stream.writeRequests.setLen(0)

  if stream.closeRequest != NULL_JS_OBJECT:
    let rejectFunc = JSObjectGetProperty(ctx, stream.closeRequest, JSStringCreateWithUTF8CString("reject"), exception)
    discard JSObjectCallAsFunction(ctx, cast[JSObjectRef](rejectFunc), NULL_JS_OBJECT, 1, addr reason, exception)
    stream.closeRequest = NULL_JS_OBJECT

  # Call abort on underlying sink if it exists
  discard callUnderlyingSinkMethod(ctx, stream, "abort", @[reason], exception)

  stream.state = "errored"

  var resolveFunc, rejectFunc: JSObjectRef
  result = cast[JSValueRef](JSObjectMakeDeferredPromise(ctx, addr resolveFunc, addr rejectFunc, exception))
  discard JSObjectCallAsFunction(ctx, resolveFunc, NULL_JS_OBJECT, 0, nil, exception)

proc writableStreamClose(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let stream = cast[WritableStream](getPrivateData(thisObject))
  if stream.isNil:
    setJSException(ctx, exception, "Invalid WritableStream")
    return JSValueMakeUndefined(ctx)

  let writer = cast[WritableStreamDefaultWriter](getPrivateData(stream.writer))
  if writer.isNil:
    setJSException(ctx, exception, "Invalid WritableStreamDefaultWriter")
    return JSValueMakeUndefined(ctx)

  if stream.state != "writable":
    var resolveFunc, rejectFunc: JSObjectRef
    result = cast[JSValueRef](JSObjectMakeDeferredPromise(ctx, addr resolveFunc, addr rejectFunc, exception))
    let error = nimStrToJSValue(ctx, "WritableStream is not in a writable state")
    discard JSObjectCallAsFunction(ctx, rejectFunc, cast[JSObjectRef](error), 1, addr error, exception)
    return result

  # Mark the stream as closing, preventing new write requests
  stream.state = "closing"

  result = cast[JSValueRef](JSObjectMakeDeferredPromise(ctx, addr stream.inFlightCloseRequestResolve, addr stream.inFlightCloseRequestReject, exception))
  stream.closeRequest = cast[JSObjectRef](result)

  # If there are no pending writes, call close on the underlying sink
  if stream.writeRequests.len == 0 and stream.inFlightWriteRequest == NULL_JS_OBJECT:
    discard callUnderlyingSinkMethod(ctx, stream, "close", @[cast[JSValueRef](stream.writer)], exception)
    stream.state = "closed"
    discard JSObjectCallAsFunction(ctx, stream.inFlightCloseRequestResolve, NULL_JS_OBJECT, 0, nil, exception)

    discard JSObjectCallAsFunction(ctx, writer.closedResolve, NULL_JS_OBJECT, 0, nil, exception)
  else:
    # Otherwise, the close request will be processed after all writes are complete
    stream.inFlightCloseRequest = cast[JSObjectRef](result)

proc writableStreamGetWriter(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let stream = cast[WritableStream](getPrivateData(thisObject))
  if stream.isNil:
    setJSException(ctx, exception, "Invalid WritableStream")
    return JSValueMakeUndefined(ctx)

  if stream.locked:
    setJSException(ctx, exception, "WritableStream is already locked to a writer")
    return JSValueMakeUndefined(ctx)

  # Create a new WritableStreamDefaultWriter
  let writerConstructor = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), JSStringCreateWithUTF8CString("WritableStreamDefaultWriter"), exception)
  let writerArgs = [cast[JSValueRef](thisObject)]
  let writer = JSObjectCallAsConstructor(ctx, cast[JSObjectRef](writerConstructor), 1, addr writerArgs[0], exception)

  if writer != NULL_JS_OBJECT:
    stream.locked = true
    stream.writer = writer

  cast[JSValueRef](writer)

proc writableStreamGetProperty(ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let stream = cast[WritableStream](getPrivateData(obj))
  let name = jsStringToNimStr(propertyName)
  case name
  of "locked": result = JSValueMakeBoolean(ctx, stream.locked.cint)

  of "getWriter": result = cast[JSValueRef](JSObjectMakeFunctionWithCallback(ctx, propertyName, writableStreamGetWriter))
  of "abort": result = cast[JSValueRef](JSObjectMakeFunctionWithCallback(ctx, propertyName, writableStreamAbort))
  of "close": result = cast[JSValueRef](JSObjectMakeFunctionWithCallback(ctx, propertyName, writableStreamClose))
  else: result = JSValueMakeUndefined(ctx)

proc writableStreamGetPropertyNames(ctx: JSContextRef, obj: JSObjectRef, propertyNames: JSPropertyNameAccumulatorRef) {.cdecl.} =
  let properties = ["locked", "abort", "close", "getWriter"]
  for prop in properties:
    JSPropertyNameAccumulatorAddName(propertyNames, JSStringCreateWithUTF8CString(prop.cstring))

proc createWritableStreamClass*(ctx: JSContextRef) =
  let classdef = JSClassDefinition(
    version: 0,
    attributes: kJSClassAttributeNone,
    className: "WritableStream",
    parentClass: nil,
    staticValues: nil,
    staticFunctions: nil,
    initialize: nil,
    finalize: proc (obj: JSObjectRef) {.cdecl.} =
      let stream = cast[WritableStream](getPrivateData(obj))
      if not stream.isNil:
        GC_unref(stream)
      removePrivateData(obj),
    hasProperty: nil,
    getProperty: writableStreamGetProperty,
    setProperty: nil,
    deleteProperty: nil,
    getPropertyNames: writableStreamGetPropertyNames,
    callAsFunction: nil,
    callAsConstructor: writableStreamConstructor,
    hasInstance: nil,
    convertToType: nil
  )

  writableStreamClassRef = JSClassCreate(addr classdef)
  
  let constructor = JSObjectMakeConstructor(ctx, writableStreamClassRef, writableStreamConstructor)
  setPrivateData(constructor, cast[pointer](writableStreamClassRef))

  let globalObject = JSContextGetGlobalObject(ctx)
  JSObjectSetProperty(ctx, globalObject, JSStringCreateWithUTF8CString("WritableStream"), cast[JSValueRef](constructor), kJSPropertyAttributeNone, nil)
