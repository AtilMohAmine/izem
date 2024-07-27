import asyncdispatch, httpbeast, httpcore, options, js_utils, js_constants, js_bindings

var globalCtx: JSContextRef
var jsCallback: JSObjectRef

proc handleRequest(req: Request): Future[void] =

    var body = req.body.get("{}")
    if body.len == 0:
      body = "{}"
    let jsonstr = "{\"method\": \"" & $req.httpMethod.get() & "\", \"path\": \"" & req.path.get("") & "\", \"body\": " & body & "}"
    let jsReqValue = nimStrToJSObject(globalCtx, jsonstr)

    let jsException: JSValueRef = JSValueRef(nil)
    let jsResult = JSObjectCallAsFunction(globalCtx, jsCallback, NULL_JS_OBJECT, 1, addr jsReqValue, addr jsException)
    if jsException != NULL_JS_VALUE and jsResult == NULL_JS_VALUE:
      req.send(Http500, "Internal server error")
    else:
      req.send(Http200, jsValueToNimStr(globalCtx, jsResult))

proc serverCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount != 2:
    echo "Error: server function expects 2 arguments (port and callback)"
    return JSValueMakeUndefined(ctx)

  globalCtx = ctx
  let port = JSValueToNumber(globalCtx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0], nil).int
  jsCallback = JSValueToObject(globalCtx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1], nil)
      
  let settings = initSettings(port = Port(port))
  run(handleRequest, settings)

  JSValueMakeUndefined(ctx)

proc createServerObject*(ctx: JSContextRef) =
  let globalObject = JSContextGetGlobalObject(ctx)
  let serverName = JSStringCreateWithUTF8CString("myruntime")
  let serverObject = JSObjectMake(ctx, nil, nil)
  JSObjectSetProperty(ctx, globalObject, serverName, cast[JSValueRef](serverObject), kJSPropertyAttributeNone, nil)
  JSStringRelease(serverName)

  let serverMethodName = JSStringCreateWithUTF8CString("server")
  let serverMethod = JSObjectMakeFunctionWithCallback(ctx, serverMethodName, serverCallback)
  JSObjectSetProperty(ctx, serverObject, serverMethodName, cast[JSValueRef](serverMethod), kJSPropertyAttributeNone, nil)
  JSStringRelease(serverMethodName)