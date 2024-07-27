import js_bindings, js_constants

# Function to convert Nim string to JSValueRef
proc nimStrToJSValue*(ctx: JSContextRef, s: string): JSValueRef =
  let jsStr = JSStringCreateWithUTF8CString(s)
  result = JSValueMakeString(ctx, jsStr)
  JSStringRelease(jsStr)

# Function to convert JSValueRef to Nim string
proc jsValueToNimStr*(ctx: JSContextRef, value: JSValueRef): string =
  var exception: JSValueRef = NULL_JS_VALUE
  let stringRef = JSValueToStringCopy(ctx, value, addr exception)

  if exception != NULL_JS_VALUE:
    result = ""

  var buffer: array[1024, char]
  let length = JSStringGetUTF8CString(stringRef, cast[cstring](buffer[0].addr), buffer.len.csize_t)

  if length > 0:
    let resultStr = cast[string](buffer[0 .. length - 2])  # Convert buffer to string
    result = resultStr
  else:
    result = ""

  JSStringRelease(stringRef)

# Function to convert Nim string to JSValueRef
proc nimStrToJSObject*(ctx: JSContextRef, json: string): JSValueRef =
  let jsStr = JSStringCreateWithUTF8CString(json.cstring)
  result = JSValueMakeFromJSONString(ctx, jsStr)
  JSStringRelease(jsStr)

proc setupGlobalFunctions*(ctx: JSContextRef; functions: seq[(string, JSObjectCallAsFunctionCallback)]) =
  let globalObject = JSContextGetGlobalObject(ctx)
  
  for (name, callback) in functions:
    let jsName = JSStringCreateWithUTF8CString(name.cstring)
    let jsFunction = JSObjectMakeFunctionWithCallback(ctx, jsName, callback)
    JSObjectSetProperty(ctx, globalObject, jsName, cast[JSValueRef](jsFunction), kJSPropertyAttributeNone, nil)
    JSStringRelease(jsName)

proc setupJSObjectFunctions*(ctx: JSContextRef, objName: string, functions: seq[(string, JSObjectCallAsFunctionCallback)]) =
  let globalObject = JSContextGetGlobalObject(ctx)
  let objNameStr = JSStringCreateWithUTF8CString(objName)
  let obj = JSObjectMake(ctx, nil, nil)
  JSObjectSetProperty(ctx, globalObject, objNameStr, cast[JSValueRef](obj), kJSPropertyAttributeNone, nil)
  JSStringRelease(objNameStr)

  for (name, callback) in functions:
    let funcName = JSStringCreateWithUTF8CString(name.cstring)
    let fn = JSObjectMakeFunctionWithCallback(ctx, funcName, callback)
    JSObjectSetProperty(ctx, obj, funcName, cast[JSValueRef](fn), kJSPropertyAttributeNone, nil)
    JSStringRelease(funcName)