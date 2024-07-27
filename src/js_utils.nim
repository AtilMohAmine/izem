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
