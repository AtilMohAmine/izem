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

proc startServer(port: int): Future[void] {.async.} =
  await sleepAsync(0)
  let settings = initSettings(port = Port(port))
  run(handleRequest, settings)

proc serverCallback(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount != 2: 
    setJSException(ctx, exception, "Error: server function expects 2 arguments (port and callback)")
    return JSValueMakeUndefined(ctx)

  globalCtx = ctx
  let port = JSValueToNumber(globalCtx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0], nil).int
  jsCallback = JSValueToObject(globalCtx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1], nil)
      
  asyncCheck startServer(port)
  JSValueMakeUndefined(ctx)

proc createServerObject*(ctx: JSContextRef) =
  setupJSObjectFunctions(ctx, "izem", @[
    ("server", serverCallback)
  ])