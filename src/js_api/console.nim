import ../js_bindings, ../js_constants, ../js_utils

proc printJSValue(ctx: JSContextRef, value: JSValueRef) =
  if JSValueIsNull(ctx, value):
    echo "null"
    return
  elif JSValueIsUndefined(ctx, value):
    echo "undefined"
    return
  elif JSValueIsBoolean(ctx, value):
    echo if JSValueToBoolean(ctx, value): "true" else: "false"
    return
  elif JSValueIsNumber(ctx, value):
    echo JSValueToNumber(ctx, value, nil)
    return
  else:
    echo jsValueToNimStr(ctx, value)
    return

proc consoleLogCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  for i in 0..<argumentCount:
    let arg = cast[ptr UncheckedArray[JSValueRef]](arguments)[i]
    printJSValue(ctx, arg)
  return NULL_JS_VALUE

proc createConsoleObject*(ctx: JSContextRef) =
  setupJSObjectFunctions(ctx, "console", @[
    ("log", consoleLogCallback)
  ])