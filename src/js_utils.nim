import js_bindings, js_constants

proc jsStringToNimStr*(jsString: JSStringRef): string =
  let length = JSStringGetMaximumUTF8CStringSize(jsString)
  var buffer = newString(length)
  discard JSStringGetUTF8CString(jsString, buffer.cstring, length)
  result = buffer

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
    return ""

  let length = JSStringGetLength(stringRef)
  if length == 0:
    JSStringRelease(stringRef)
    return ""

  var buffer = newString(length.int * 4)
  let actualLength = JSStringGetUTF8CString(stringRef, buffer.cstring, (length.int * 4 + 1).csize_t)

  JSStringRelease(stringRef)

  if actualLength > 0:
    result = buffer[0 ..< (actualLength - 1).int]  # Exclude null terminator
  else:
    result = ""

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

proc setJSException*(ctx: JSContextRef, exception: ptr JSValueRef, message: string) =
  echo message
  if exception != nil:
    let jsString = JSStringCreateWithUTF8CString(message)
    exception[] = JSValueMakeString(ctx, jsString)
    JSStringRelease(jsString)