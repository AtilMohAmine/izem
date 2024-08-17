import tables, sequtils, algorithm, strutils, json, uri, re
import ../js_bindings, ../js_utils, ../js_constants, ../js_private_data

type
  URL = ref object
    uri: Uri
    searchParams: JSObjectRef

var urlClassRef: JSClassRef

type
  URLParseError = object of CatchableError

proc isValidUrl(url: string): bool {.gcsafe.} =
  let urlRegex = re"(http(s)?:\/\/(www\.)?[a-zA-Z0-9@:%._\+~#=]{2,256}\.[a-z]{2,6}\b([-a-zA-Z0-9@:%_\+.~#?&//=]*))"
  return match(url, urlRegex)

proc parseUrl(url: string, base: string = ""): Uri =
  var resultUri: Uri
  if base.len > 0:
    resultUri = combine(parseUri(base), parseUri(url))
  else:
    resultUri = parseUri(url)

  let finalUrl = $resultUri

  if not isValidUrl(finalUrl):
    raise newException(URLParseError, "Invalid URL: " & finalUrl)
  
  return resultUri

proc urlConstructor(ctx: JSContextRef, constructor: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSObjectRef {.cdecl.} =
  var url = new(URL)
  GC_ref(url)
  if argumentCount > 0:
    let urlStr = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
    var baseStr = ""
    if argumentCount > 1:
      baseStr = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
    
    try:
      url.uri = parseUrl(urlStr, baseStr)
    except URLParseError:
      setJSException(ctx, exception, getCurrentExceptionMsg())
      return NULL_JS_OBJECT
    
    # Initialize searchParams using the existing URLSearchParams constructor
    let searchParamsConstructor = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), JSStringCreateWithUTF8CString("URLSearchParams"), nil)
    let searchParamsArgs = [JSValueMakeString(ctx, JSStringCreateWithUTF8CString(url.uri.query))]
    url.searchParams = JSObjectCallAsConstructor(ctx, cast[JSObjectRef](searchParamsConstructor), 1, addr searchParamsArgs[0], nil)

  let result = JSObjectMake(ctx, urlClassRef, nil)
  if result == NULL_JS_OBJECT:
    echo "Failed to create JSObject"
  else:
    setPrivateData(result, cast[pointer](url))
  result

proc urlParse(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    return JSValueMakeNull(ctx)
  
  let urlStr = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  var baseStr = ""
  if argumentCount > 1:
    baseStr = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
  
  try:
    let parsedUri = parseUrl(urlStr, baseStr)
    let constructorObj = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), JSStringCreateWithUTF8CString("URL"), nil)
    let constructorArgs = [JSValueMakeString(ctx, JSStringCreateWithUTF8CString($parsedUri))]
    return cast[JSValueRef](JSObjectCallAsConstructor(ctx, cast[JSObjectRef](constructorObj), 1, addr constructorArgs[0], nil))
  
  except URLParseError:
    setJSException(ctx, exception, getCurrentExceptionMsg())
    return JSValueMakeNull(ctx)
  
proc urlCanParse(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  if argumentCount < 1:
    return JSValueMakeBoolean(ctx, false.cint)
  
  let urlStr = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
  var baseStr = ""
  if argumentCount > 1:
    baseStr = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
  
  try:
    discard parseUrl(urlStr, baseStr)
    return JSValueMakeBoolean(ctx, true.cint)
  except URLParseError:
    return JSValueMakeBoolean(ctx, false.cint)

proc urlToJSON(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let url = cast[URL](getPrivateData(thisObject))
  nimStrToJSValue(ctx, $url.uri)

proc urlGetProperty(ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let url = cast[URL](getPrivateData(obj))
  let name = jsStringToNimStr(propertyName)
  case name
  of "href": result = nimStrToJSValue(ctx, $url.uri)
  of "origin": result = nimStrToJSValue(ctx, url.uri.scheme & "://" & url.uri.hostname)
  of "protocol": result = nimStrToJSValue(ctx, url.uri.scheme & ":")
  of "username": result = nimStrToJSValue(ctx, url.uri.username)
  of "password": result = nimStrToJSValue(ctx, url.uri.password)
  of "host": result = nimStrToJSValue(ctx, if url.uri.port.len > 0: url.uri.hostname & ":" & url.uri.port else: url.uri.hostname)
  of "hostname": result = nimStrToJSValue(ctx, url.uri.hostname)
  of "port": result = nimStrToJSValue(ctx, url.uri.port)
  of "pathname": result = nimStrToJSValue(ctx, url.uri.path)
  of "search": result = nimStrToJSValue(ctx, "?" & url.uri.query)
  of "searchParams": result = cast[JSValueRef](url.searchParams)
  of "hash": result = nimStrToJSValue(ctx, if url.uri.anchor.len > 0: "#" & url.uri.anchor else: "")

  of "toJSON": result = cast[JSValueRef](JSObjectMakeFunctionWithCallback(ctx, propertyName, urlToJSON))

proc urlGetPropertyNames(ctx: JSContextRef, obj: JSObjectRef, propertyNames: JSPropertyNameAccumulatorRef) {.cdecl.} =
  let properties = ["href", "origin", "protocol", "username", "password", "host", "hostname", "port", "pathname", "search", "searchParams", "hash", "toJSON"]
  for prop in properties:
    JSPropertyNameAccumulatorAddName(propertyNames, JSStringCreateWithUTF8CString(prop.cstring))

var staticFunctions = [
    JSStaticFunction(name: "parse", callAsFunction: urlParse, attributes: kJSPropertyAttributeDontDelete),
    JSStaticFunction(name: "canParse", callAsFunction: urlCanParse, attributes: kJSPropertyAttributeDontDelete),
    JSStaticFunction(name: nil, callAsFunction: nil, attributes: kJSPropertyAttributeNone)
  ]

proc createURLClass*(ctx: JSContextRef) =

  let classdef = JSClassDefinition(
    version: 0,
    attributes: kJSClassAttributeNone,
    className: "URL",
    parentClass: nil,
    staticValues: nil,
    staticFunctions: addr staticFunctions[0],
    initialize: nil,
    finalize: proc (obj: JSObjectRef) {.cdecl.} =
      let url = cast[URL](getPrivateData(obj))
      if not url.isNil:
        GC_unref(url)
      removePrivateData(obj),
    hasProperty: nil,
    getProperty: urlGetProperty,
    setProperty: nil,
    deleteProperty: nil,
    getPropertyNames: urlGetPropertyNames,
    callAsFunction: nil,
    callAsConstructor: urlConstructor,
    hasInstance: nil,
    convertToType: nil
  )

  urlClassRef = JSClassCreate(addr classdef)
  
  let constructor = JSObjectMakeConstructor(ctx, urlClassRef, urlConstructor)
  setPrivateData(constructor, cast[pointer](urlClassRef))

  let globalObject = JSContextGetGlobalObject(ctx)
  JSObjectSetProperty(ctx, globalObject, JSStringCreateWithUTF8CString("URL"), cast[JSValueRef](constructor), kJSPropertyAttributeNone, nil)