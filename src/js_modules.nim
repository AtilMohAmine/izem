import tables, os, js_bindings, js_utils, js_constants

var modules = initTable[string, JSObjectRef]()

proc requireCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    setJSException(ctx, exception, "require needs one argument")
    return JSValueMakeUndefined(ctx)

  let modulePath = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  
  if modules.hasKey(modulePath):
    return cast[JSValueRef](modules[modulePath])

  let fullPath = modulePath.absolutePath()
  if not fileExists(fullPath):
    setJSException(ctx, exception, "Module not found: " & modulePath)
    return JSValueMakeUndefined(ctx)

  let moduleCode = readFile(fullPath)
  
  # Create a new object to serve as the module's exports
  let exportsObj = JSObjectMake(ctx, nil, nil)

  # Wrap the module code in a function that takes 'exports' as an argument
  let wrappedCode = "(function(exports) { " & moduleCode & "\nreturn exports; })"
  
  var jsException: JSValueRef = NULL_JS_VALUE
  let jsScript = JSStringCreateWithUTF8CString(wrappedCode.cstring)
  let moduleFunc = JSEvaluateScript(ctx, jsScript, NULL_JS_VALUE, NULL_JS_STRING, 0, addr jsException)
  JSStringRelease(jsScript)

  if jsException != NULL_JS_VALUE:
    let errorMsg = jsValueToNimStr(ctx, jsException)
    setJSException(ctx, exception, "Error in module " & modulePath & ": " & errorMsg)
    return JSValueMakeUndefined(ctx)

  # Call the module function with the exports object
  let args = [cast[JSValueRef](exportsObj)]
  let moduleResult = JSObjectCallAsFunction(ctx, JSValueToObject(ctx, moduleFunc, nil), NULL_JS_OBJECT, 1, addr args[0], addr jsException)

  if jsException != NULL_JS_VALUE:
    let errorMsg = jsValueToNimStr(ctx, jsException)
    setJSException(ctx, exception, "Error executing module " & modulePath & ": " & errorMsg)
    return JSValueMakeUndefined(ctx)

  modules[modulePath] = JSValueToObject(ctx, moduleResult, nil)
  return moduleResult

proc addModuleSystem*(ctx: JSContextRef) =
  let globalObject = JSContextGetGlobalObject(ctx)
  
  let requireName = JSStringCreateWithUTF8CString("require")
  let requireFunc = JSObjectMakeFunctionWithCallback(ctx, requireName, requireCallback)
  JSObjectSetProperty(ctx, globalObject, requireName, cast[JSValueRef](requireFunc), kJSPropertyAttributeNone, nil)
  JSStringRelease(requireName)