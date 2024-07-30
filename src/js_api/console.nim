import tables, times, strutils
import ../js_bindings, ../js_utils, ../js_constants

var groupLevel = 0
var timers = initTable[string, float]()
var counters = initTable[string, int]()

proc indent(): string =
  return "  ".repeat(groupLevel)

proc printJSValue(ctx: JSContextRef, value: JSValueRef): string =
  if JSValueIsNull(ctx, value):
    return "null"  
  elif JSValueIsUndefined(ctx, value):
    return "undefined"
  elif JSValueIsBoolean(ctx, value):
    return if JSValueToBoolean(ctx, value): "true" else: "false"
  elif JSValueIsNumber(ctx, value):
    return $JSValueToNumber(ctx, value, nil)  
  elif JSValueIsObject(ctx, value):
    let obj = JSValueToObject(ctx, value, nil)
    if JSObjectIsFunction(ctx, obj):
      return "[Function]"
    elif JSValueIsArray(ctx, value):
      return "[Array]"
    else:
      var result = "{ "
      let keys = JSObjectCopyPropertyNames(ctx, obj)
      let length = JSPropertyNameArrayGetCount(keys)
      for i in 0..<length:
        let propNameRef = JSPropertyNameArrayGetNameAtIndex(keys, i)
        let propName = jsStringToNimStr(propNameRef)
        let propValue = JSObjectGetProperty(ctx, obj, propNameRef, nil)
        result.add(propName & ": " & printJSValue(ctx, propValue) & ", ")
        JSStringRelease(propNameRef)
      if length > 0:
        result.setLen(result.len - 2)
      result.add(" }")
      JSPropertyNameArrayRelease(keys)
      return result
  else:
    return jsValueToNimStr(ctx, value)
    
proc consoleLogBase(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  var formattedArgs: seq[string] = @[]
  for i in 0..<argumentCount:
    let arg = cast[ptr UncheckedArray[JSValueRef]](arguments)[i]
    formattedArgs.add(printJSValue(ctx, arg))
  
  echo formattedArgs.join(" ")
  return JSValueMakeUndefined(ctx)

proc consoleLogCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  stdout.write indent()
  return consoleLogBase(ctx, function, thisObject, argumentCount, arguments, exception)

proc consoleInfoCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  stdout.write indent() & "Info: "
  return consoleLogBase(ctx, function, thisObject, argumentCount, arguments, exception)

proc consoleWarnCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  stdout.write "Warning: "
  return consoleLogBase(ctx, function, thisObject, argumentCount, arguments, exception)

proc consoleErrorCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  stderr.write "Error: "
  return consoleLogBase(ctx, function, thisObject, argumentCount, arguments, exception)

proc consoleDebugCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  stderr.write "Debug: "
  return consoleLogBase(ctx, function, thisObject, argumentCount, arguments, exception)

proc consoleAssertCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount > 0:
    let condition = JSValueToBoolean(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
    if not condition:
      stderr.write "Assertion failed: "
      discard consoleErrorCallback(ctx, function, thisObject, argumentCount - 1, cast[ptr JSValueRef](cast[int](arguments) + sizeof(JSValueRef)), exception)
  return JSValueMakeUndefined(ctx)

proc consoleTraceCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  echo indent() & "Stack Trace:"
  let bodyStr = JSStringCreateWithUTF8CString("return new Error().stack")

  let stackFunc = JSObjectMakeFunction(ctx, NULL_JS_STRING, 0, nil, bodyStr, NULL_JS_STRING, 0, nil)
  JSStringRelease(bodyStr)
  let stack = JSObjectCallAsFunction(ctx, stackFunc, NULL_JS_OBJECT, 0, nil, nil)
  
  if stack != NULL_JS_VALUE:
    let stackStr = jsValueToNimStr(ctx, stack)
    echo indent() & stackStr.replace("\n", "\n" & indent())
  else:
    echo indent() & "Unable to retrieve stack trace"

  return JSValueMakeUndefined(ctx)

proc consoleTableCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount == 0:
    echo indent() & "Table: No data"
    return JSValueMakeUndefined(ctx)

  let data = cast[ptr UncheckedArray[JSValueRef]](arguments)[0]
  if not JSValueIsObject(ctx, data):
    echo indent() & "Table: Invalid data (not an object)"
    return JSValueMakeUndefined(ctx)

  var properties: seq[string]

  # Handle properties argument if provided
  if argumentCount > 1:
    let propsArg = cast[ptr UncheckedArray[JSValueRef]](arguments)[1]
    if JSValueIsArray(ctx, propsArg):
      let length = JSValueToNumber(ctx, JSObjectGetProperty(ctx, JSValueToObject(ctx, propsArg, nil), JSStringCreateWithUTF8CString("length"), nil), nil).int
      for i in 0..<length:
        let prop = JSObjectGetPropertyAtIndex(ctx, JSValueToObject(ctx, propsArg, nil), i.cuint, nil)
        properties.add(jsValueToNimStr(ctx, prop))
  
  if properties.len == 0:
    if JSValueIsArray(ctx, data):
      let length = JSValueToNumber(ctx, JSObjectGetProperty(ctx, JSValueToObject(ctx, data, nil), JSStringCreateWithUTF8CString("length"), nil), nil).int
      if length > 0:
        let firstItem = JSObjectGetPropertyAtIndex(ctx, JSValueToObject(ctx, data, nil), 0.cuint, nil)
        let keys = JSObjectCopyPropertyNames(ctx, JSValueToObject(ctx, firstItem, nil))
        let propCount = JSPropertyNameArrayGetCount(keys).int
        for i in 0..<propCount:
          let propertyNameRef = JSPropertyNameArrayGetNameAtIndex(keys, i.cuint)
          let propertyName = jsStringToNimStr(propertyNameRef)
          properties.add(propertyName)
          JSStringRelease(propertyNameRef)
        JSPropertyNameArrayRelease(keys)
    else:
      let keys = JSObjectCopyPropertyNames(ctx, JSValueToObject(ctx, data, nil))
      let length = JSPropertyNameArrayGetCount(keys).int
      for i in 0..<length:
        let propertyNameRef = JSPropertyNameArrayGetNameAtIndex(keys, i.cuint)
        let propertyName = jsStringToNimStr(propertyNameRef)
        properties.add(propertyName)
        JSStringRelease(propertyNameRef)
      JSPropertyNameArrayRelease(keys)

  echo indent() & "Table:"
  echo indent() & properties.join(" | ")
  echo indent() & "-".repeat(properties.join(" | ").len)

  if JSValueIsArray(ctx, data):
    let length = JSValueToNumber(ctx, JSObjectGetProperty(ctx, JSValueToObject(ctx, data, nil), JSStringCreateWithUTF8CString("length"), nil), nil).int
    for i in 0..<length:
      let item = JSObjectGetPropertyAtIndex(ctx, JSValueToObject(ctx, data, nil), i.cuint, nil)
      var row: seq[string]
      for prop in properties:
        let propName = JSStringCreateWithUTF8CString(prop.cstring)
        let value = JSObjectGetProperty(ctx, JSValueToObject(ctx, item, nil), propName, nil)
        row.add(printJSValue(ctx, value))
        JSStringRelease(propName)
      echo indent() & row.join(" | ")
  else:
    var row: seq[string]
    for prop in properties:
      let propName = JSStringCreateWithUTF8CString(prop.cstring)
      let value = JSObjectGetProperty(ctx, JSValueToObject(ctx, data, nil), propName, nil)
      row.add(printJSValue(ctx, value))
      JSStringRelease(propName)
    echo indent() & row.join(" | ")

  return JSValueMakeUndefined(ctx)

proc consoleDirCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount == 0:
    echo indent() & "Dir: No object"
    return JSValueMakeUndefined(ctx)

  let obj = cast[ptr UncheckedArray[JSValueRef]](arguments)[0]
  if not JSValueIsObject(ctx, obj):
    echo indent() & "Dir: Not an object"
    return JSValueMakeUndefined(ctx)

  echo indent() & "Object properties:"
  let keys = JSObjectCopyPropertyNames(ctx, JSValueToObject(ctx, obj, nil))
  let length = JSPropertyNameArrayGetCount(keys).int
  for i in 0..<length:
    let propNameRef = JSPropertyNameArrayGetNameAtIndex(keys, i.cuint)
    let propName = jsStringToNimStr(propNameRef)
    let value = JSObjectGetProperty(ctx, JSValueToObject(ctx, obj, nil), propNameRef, nil)
    echo indent() & "  " & propName & ": " & printJSValue(ctx, value)
    JSStringRelease(propNameRef)

  JSPropertyNameArrayRelease(keys)
  return JSValueMakeUndefined(ctx)

proc consoleDirxmlCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  # For simplicity, we'll make dirxml behave the same as dir in this text-based environment
  return consoleDirCallback(ctx, function, thisObject, argumentCount, arguments, exception)

proc consoleClearCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  # Clear the console (implementation depends on your terminal)
  echo "\x1Bc"
  return JSValueMakeUndefined(ctx)

proc consoleCountCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let label = if argumentCount > 0: jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0]) else: "default"
  {.gcsafe.}:
    counters[label] = counters.getOrDefault(label, 0) + 1
    echo indent() & label & ": " & $counters[label]
  return JSValueMakeUndefined(ctx)

proc consoleCountResetCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let label = if argumentCount > 0: jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0]) else: "default"
  {.gcsafe.}:
    counters[label] = 0
    echo indent() & label & ": " & "0"
  return JSValueMakeUndefined(ctx)

proc consoleGroupCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  discard consoleLogBase(ctx, function, thisObject, argumentCount, arguments, exception)
  groupLevel += 1
  return JSValueMakeUndefined(ctx)

proc consoleGroupCollapsedCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  # In a text-based console, groupCollapsed behaves the same as group
  return consoleGroupCallback(ctx, function, thisObject, argumentCount, arguments, exception)

proc consoleGroupEndCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if groupLevel > 0:
    groupLevel -= 1
  return JSValueMakeUndefined(ctx)

proc consoleTimeCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let label = if argumentCount > 0: jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0]) else: "default"
  {.gcsafe.}:
    timers[label] = epochTime()
  return JSValueMakeUndefined(ctx)

proc consoleTimeLogCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let label = if argumentCount > 0: jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0]) else: "default"
  {.gcsafe.}:
    if label in timers:
      let duration = epochTime() - timers[label]
      echo indent() & label & ": " & $duration & "ms"
      if argumentCount > 1:
        discard consoleLogBase(ctx, function, thisObject, argumentCount - 1, cast[ptr JSValueRef](cast[int](arguments) + sizeof(JSValueRef)), exception)
    else:
      echo indent() & "Timer '" & label & "' does not exist"
  return JSValueMakeUndefined(ctx)

proc consoleTimeEndCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let label = if argumentCount > 0: jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0]) else: "default"
  {.gcsafe.}:
    if label in timers:
      let duration = epochTime() - timers[label]
      echo indent() & label & ": " & $duration & "ms"
      timers.del(label)
    else:
      echo indent() & "Timer '" & label & "' does not exist"
  return JSValueMakeUndefined(ctx)

proc createConsoleObject*(ctx: JSContextRef) =
  setupJSObjectFunctions(ctx, "console", @[
    ("log", consoleLogCallback),
    ("info", consoleInfoCallback),
    ("warn", consoleWarnCallback),
    ("error", consoleErrorCallback),
    ("debug", consoleDebugCallback),
    ("trace", consoleTraceCallback),
    ("assert", consoleAssertCallback),
    ("clear", consoleClearCallback),
    ("count", consoleCountCallback),
    ("countReset", consoleCountResetCallback),
    ("group", consoleGroupCallback),
    ("groupCollapsed", consoleGroupCollapsedCallback),
    ("groupEnd", consoleGroupEndCallback),
    ("time", consoleTimeCallback),
    ("timeLog", consoleTimeLogCallback),
    ("timeEnd", consoleTimeEndCallback),
    ("table", consoleTableCallback),
    ("dir", consoleDirCallback),
    ("dirxml", consoleDirxmlCallback)
  ])