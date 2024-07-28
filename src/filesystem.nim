import os, js_bindings, js_utils

proc readFileCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    setJSException(ctx, exception, "readFile requires a file path argument")
    return JSValueMakeUndefined(ctx)
  
  let filePath = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  try:
    let content = readFile(filePath)
    return JSValueMakeString(ctx, JSStringCreateWithUTF8CString(content.cstring))
  except IOError:
    setJSException(ctx, exception, "Error reading file: " & getCurrentExceptionMsg())
    return JSValueMakeUndefined(ctx)

proc writeFileCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 2:
    setJSException(ctx, exception, "writeFile requires a file path and content arguments")
    return JSValueMakeboolean(ctx, false.cint)
  
  let filePath = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  let content = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
  try:
    writeFile(filePath, content)
    return JSValueMakeBoolean(ctx, true.cint)
  except IOError:
    setJSException(ctx, exception, "Error writing file: " & getCurrentExceptionMsg())
    return JSValueMakeBoolean(ctx, false.cint)

proc fileExistsCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    setJSException(ctx, exception, "fileExists requires a file path argument")
    return JSValueMakeBoolean(ctx, false.cint)
  
  let filePath = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  return JSValueMakeBoolean(ctx, fileExists(filePath).cint)

proc addFileSystemFunctions*(ctx: JSContextRef) =
  setupJSObjectFunctions(ctx, "fs", @[
    ("readFile", readFileCallback),
    ("writeFile", writeFileCallback),
    ("fileExists", fileExistsCallback)
  ])