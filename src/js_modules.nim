import tables, os
import js_bindings, js_utils, js_constants, babel_utils

var modules = initTable[string, JSObjectRef]()

proc loadModule(ctx: JSContextRef, modulePath: string, exception: ptr JSValueRef): JSObjectRef =
  let fullPath = modulePath.absolutePath()
  if not fileExists(fullPath):
    setJSException(ctx, exception, "Module not found: " & modulePath)
    return NULL_JS_OBJECT

  let moduleCode = readFile(fullPath)
  let transpiledCode = transpileModule(ctx, moduleCode, fullPath)

  # Create a new object to serve as the module's exports
  let exportsObj = JSObjectMake(ctx, NULL_JS_CLASS, nil)
  let moduleObj = JSObjectMake(ctx, NULL_JS_CLASS, nil)
  
  JSObjectSetProperty(ctx, moduleObj, JSStringCreateWithUTF8CString("exports"), cast[JSValueRef](exportsObj), kJSPropertyAttributeNone, nil)

  let globalObject = JSContextGetGlobalObject(ctx)
  JSObjectSetProperty(ctx, globalObject, JSStringCreateWithUTF8CString("exports"), cast[JSValueRef](exportsObj), kJSPropertyAttributeNone, nil)
  JSObjectSetProperty(ctx, globalObject, JSStringCreateWithUTF8CString("module"), cast[JSValueRef](moduleObj), kJSPropertyAttributeNone, nil)

  var jsException: JSValueRef = NULL_JS_VALUE
  discard JSEvaluateScript(ctx, JSStringCreateWithUTF8CString(transpiledCode.cstring), NULL_JS_VALUE, JSStringCreateWithUTF8CString(fullPath.cstring), 0, addr jsException)

  if jsException != NULL_JS_VALUE:
    let errorMsg = jsValueToNimStr(ctx, jsException)
    setJSException(ctx, exception, "Error in module " & modulePath & ": " & errorMsg)
    return NULL_JS_OBJECT

  let moduleObjValue = JSObjectGetProperty(ctx, moduleObj, JSStringCreateWithUTF8CString("exports"), nil)
  return JSValueToObject(ctx, moduleObjValue, nil)

proc requireCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    setJSException(ctx, exception, "require needs one argument")
    return JSValueMakeUndefined(ctx)

  let modulePath = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  
  if modules.hasKey(modulePath):
    return cast[JSValueRef](modules[modulePath])

  let moduleObj = loadModule(ctx, modulePath, exception)
  if moduleObj == NULL_JS_OBJECT:
    return JSValueMakeUndefined(ctx)

  modules[modulePath] = moduleObj
  return cast[JSValueRef](moduleObj)

proc addModuleSystem*(ctx: JSContextRef) =
  setupGlobalFunctions(ctx, @[
    ("require", requireCallback)
  ])
