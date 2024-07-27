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
  let globalObject = JSContextGetGlobalObject(ctx)
  
  let fsName = JSStringCreateWithUTF8CString("fs")
  let fsObject = JSObjectMake(ctx, nil, nil)
  JSObjectSetProperty(ctx, globalObject, fsName, cast[JSValueRef](fsObject), kJSPropertyAttributeNone, nil)
  JSStringRelease(fsName)

  let readFileName = JSStringCreateWithUTF8CString("readFile")
  let readFileFunc = JSObjectMakeFunctionWithCallback(ctx, readFileName, readFileCallback)
  JSObjectSetProperty(ctx, fsObject, readFileName, cast[JSValueRef](readFileFunc), kJSPropertyAttributeNone, nil)
  JSStringRelease(readFileName)

  let writeFileName = JSStringCreateWithUTF8CString("writeFile")
  let writeFileFunc = JSObjectMakeFunctionWithCallback(ctx, writeFileName, writeFileCallback)
  JSObjectSetProperty(ctx, fsObject, writeFileName, cast[JSValueRef](writeFileFunc), kJSPropertyAttributeNone, nil)
  JSStringRelease(writeFileName)

  let fileExistsName = JSStringCreateWithUTF8CString("fileExists")
  let fileExistsFunc = JSObjectMakeFunctionWithCallback(ctx, fileExistsName, fileExistsCallback)
  JSObjectSetProperty(ctx, fsObject, fileExistsName, cast[JSValueRef](fileExistsFunc), kJSPropertyAttributeNone, nil)
  JSStringRelease(fileExistsName)