import os, js_bindings, js_utils

proc readFileCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    return JSValueMakeUndefined(ctx)
  
  let filePath = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  try:
    let content = readFile(filePath)
    return JSValueMakeString(ctx, JSStringCreateWithUTF8CString(content.cstring))
  except IOError:
    let errorMsg = "Error reading file: " & getCurrentExceptionMsg()
    echo errorMsg
    #exception[] = JSValueMakeString(ctx, JSStringCreateWithUTF8CString(errorMsg.cstring))
    return JSValueMakeUndefined(ctx)

proc writeFileCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 2:
    return JSValueMakeboolean(ctx, false.cint)
  
  let filePath = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  let content = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
  try:
    writeFile(filePath, content)
    return JSValueMakeBoolean(ctx, true.cint)
  except IOError:
    let errorMsg = "Error writing file: " & getCurrentExceptionMsg()
    echo errorMsg
    #exception[] = JSValueMakeString(ctx, JSStringCreateWithUTF8CString(errorMsg.cstring))
    return JSValueMakeBoolean(ctx, false.cint)

proc fileExistsCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    return JSValueMakeBoolean(ctx, false.cint)
  
  let filePath = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  return JSValueMakeBoolean(ctx, fileExists(filePath).cint)

proc addFileSystemFunctions*(ctx: JSContextRef) =
  setupJSObjectFunctions(ctx, "fs", @[
    ("readFile", readFileCallback),
    ("writeFile", writeFileCallback),
    ("fileExists", fileExistsCallback)
  ])