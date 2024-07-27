import tables, asyncdispatch, ../js_bindings, ../js_constants

type
  TimerID* = int
  TimerCallback* = proc()
  Timer* = object
    callback*: TimerCallback
    interval*: int
    repeat*: bool

var
  timers = initTable[TimerID, Timer]()
  nextTimerID = 1  # TODO: make it dynamique depends on available timers

proc getTimersCount*(): int =
  return timers.len

proc stopTimer(id: TimerID) =
  if timers.hasKey(id):
    timers.del(id)

proc startTimer(id: TimerID, delay: int) =
  asyncCheck (proc() {.async.} =
    await sleepAsync(delay)
    if timers.hasKey(id):
      timers[id].callback()
      stopTimer(id)
  )()

proc startRepeatingTimer(id: TimerID, interval: int) =
  asyncCheck (proc() {.async.} =
    while timers.hasKey(id):
      await sleepAsync(interval)
      if timers.hasKey(id):
        timers[id].callback()
  )()

proc setTimeoutCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 2:
    return JSValueMakeNumber(ctx, 0)
  
  let callback = JSValueToObject(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0], nil)
  let delay = JSValueToNumber(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1], nil).int

  let timerID = nextTimerID
  inc nextTimerID

  timers[timerID] = Timer(callback: proc() =
    var exceptionPtr: JSValueRef = NULL_JS_VALUE
    discard JSObjectCallAsFunction(ctx, callback, NULL_JS_OBJECT, 0, nil, addr exceptionPtr)
    if exceptionPtr != NULL_JS_VALUE:
      # Handle exception
      echo "Exception occurred in setTimeout callback"
  , interval: delay, repeat: false)

  startTimer(timerID, delay)

  return JSValueMakeNumber(ctx, timerID.cdouble)

proc setIntervalCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 2:
    return JSValueMakeNumber(ctx, 0)
  
  let callback = JSValueToObject(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0], nil)
  let interval = JSValueToNumber(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1], nil).int

  let timerID = nextTimerID
  inc nextTimerID

  timers[timerID] = Timer(callback: proc() =
    var exceptionPtr: JSValueRef = NULL_JS_VALUE
    discard JSObjectCallAsFunction(ctx, callback, NULL_JS_OBJECT, 0, nil, addr exceptionPtr)
    if exceptionPtr != NULL_JS_VALUE:
      # Handle exception
      echo "Exception occurred in setInterval callback"
  , interval: interval, repeat: true)

  startRepeatingTimer(timerID, interval)

  return JSValueMakeNumber(ctx, timerID.cdouble)

proc clearTimerCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    return JSValueMakeUndefined(ctx)
  
  let timerID = JSValueToNumber(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0], nil).int
  
  stopTimer(timerID)

  return JSValueMakeUndefined(ctx)

proc addTimerFunctions*(ctx: JSContextRef) =
  let globalObject = JSContextGetGlobalObject(ctx)
  
  let setTimeoutName = JSStringCreateWithUTF8CString("setTimeout")
  let setTimeoutFunc = JSObjectMakeFunctionWithCallback(ctx, setTimeoutName, setTimeoutCallback)
  JSObjectSetProperty(ctx, globalObject, setTimeoutName, cast[JSValueRef](setTimeoutFunc), kJSPropertyAttributeNone, nil)
  JSStringRelease(setTimeoutName)

  let clearTimeoutName = JSStringCreateWithUTF8CString("clearTimeout")
  let clearTimeoutFunc = JSObjectMakeFunctionWithCallback(ctx, clearTimeoutName, clearTimerCallback)
  JSObjectSetProperty(ctx, globalObject, clearTimeoutName, cast[JSValueRef](clearTimeoutFunc), kJSPropertyAttributeNone, nil)
  JSStringRelease(clearTimeoutName)

  let setIntervalName = JSStringCreateWithUTF8CString("setInterval")
  let setIntervalFunc = JSObjectMakeFunctionWithCallback(ctx, setIntervalName, setIntervalCallback)
  JSObjectSetProperty(ctx, globalObject, setIntervalName, cast[JSValueRef](setIntervalFunc), kJSPropertyAttributeNone, nil)
  JSStringRelease(setIntervalName)

  let clearIntervalName = JSStringCreateWithUTF8CString("clearInterval")
  let clearIntervalFunc = JSObjectMakeFunctionWithCallback(ctx, clearIntervalName, clearTimerCallback)
  JSObjectSetProperty(ctx, globalObject, clearIntervalName, cast[JSValueRef](clearIntervalFunc), kJSPropertyAttributeNone, nil)
  JSStringRelease(clearIntervalName)