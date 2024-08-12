import tables, sequtils, algorithm, strutils, json
import ../js_bindings, ../js_utils, ../js_constants, ../js_private_data

type
  URLSearchParams = ref object
    params: OrderedTable[string, seq[string]]

var classRef: JSClassRef

proc urlSearchParamsConstructor(ctx: JSContextRef, constructor: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSObjectRef {.cdecl.} =
  let usp = new(URLSearchParams)
  usp.params = initOrderedTable[string, seq[string]]()
  GC_ref(usp)

  if argumentCount > 0:
    let arg = cast[ptr UncheckedArray[JSValueRef]](arguments)[0]
    if JSValueIsString(ctx, arg):
      let init = jsValueToNimStr(ctx, arg)
      for pair in init.split('&'):
        let parts = pair.split('=', 1)
        if parts.len == 2:
          usp.params.mgetOrPut(parts[0], @[]).add(parts[1])
        elif parts.len == 1:
          usp.params.mgetOrPut(parts[0], @[]).add("")
    elif JSValueIsObject(ctx, arg):
      let jsonStr = jsStringToNimStr(JSValueCreateJSONString(ctx, arg, 0, nil))
      let jsonNode = parseJson(jsonStr)
      if jsonNode.kind == JObject:
        for key, value in jsonNode.fields:
          if value.kind == JString:
            usp.params[key] = @[value.getStr()]
          elif value.kind == JArray:
            usp.params[key] = value.elems.mapIt(it.getStr())

  let result = JSObjectMake(ctx, cast[pointer](classRef), nil)
  
  if result == NULL_JS_OBJECT:
    echo "Failed to create JSObject"
  else:
    setPrivateData(result, cast[pointer](cast[int](usp)))
  result

proc urlSearchParamsAppend(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(thisObject))
  if argumentCount >= 2:
    let name = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
    let value = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
    usp.params.mgetOrPut(name, @[]).add(value)
  result = JSValueMakeUndefined(ctx)

proc urlSearchParamsDelete(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(thisObject))
  if argumentCount >= 1:
    let name = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
    if argumentCount >= 2:
      let value = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
      if name in usp.params:
        usp.params[name] = usp.params[name].filterIt(it != value)
        if usp.params[name].len == 0:
          usp.params.del(name)
    else:
      usp.params.del(name)
  result = JSValueMakeUndefined(ctx)

proc urlSearchParamsGet(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(thisObject))
  if (usp.isNil):
    result = JSValueMakeString(ctx, JSStringCreateWithUTF8CString("null usp"))

  if argumentCount >= 1:
    let name = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
    if name in usp.params and usp.params[name].len > 0:
      result = JSValueMakeString(ctx, JSStringCreateWithUTF8CString(usp.params[name][0].cstring))
    else:
      result = JSValueMakeNull(ctx)
  else:
    result = JSValueMakeNull(ctx)

proc urlSearchParamsGetAll(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(thisObject))
  if usp.isNil:
    return cast[JSValueRef](JSObjectMakeArray(ctx, 0, nil, nil))

  if argumentCount >= 1:
    let name = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
    let values = if name in usp.params: usp.params[name] else: @[]
    
    let jsArray = JSObjectMakeArray(ctx, 0.csize_t, nil, nil)
    for i, value in values:
      let jsValue = JSValueMakeString(ctx, JSStringCreateWithUTF8CString(value.cstring))
      JSObjectSetPropertyAtIndex(ctx, jsArray, i.cuint, jsValue, nil)
    result = cast[JSValueRef](jsArray)
  else:
    result = cast[JSValueRef](JSObjectMakeArray(ctx, 0, nil, nil))

proc urlSearchParamsHas(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(thisObject))
  if argumentCount >= 1:
    let name = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
    if argumentCount >= 2:
      let value = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
      result = JSValueMakeBoolean(ctx, (name in usp.params and value in usp.params[name]).cint)
    else:
      result = JSValueMakeBoolean(ctx, (name in usp.params).cint)
  else:
    result = JSValueMakeBoolean(ctx, false.cint)

proc urlSearchParamsSet(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(thisObject))
  if argumentCount >= 2:
    let name = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[0])
    let value = jsValueToNimStr(ctx, cast[ptr UncheckedArray[JSValueRef]](arguments)[1])
    usp.params[name] = @[value]
  result = JSValueMakeUndefined(ctx)

proc urlSearchParamsSort(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(thisObject))
  usp.params = usp.params.pairs.toSeq.sorted(proc(x, y: (string, seq[string])): int = cmp(x[0], y[0])).toOrderedTable
  result = JSValueMakeUndefined(ctx)

proc urlSearchParamsToString(ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(thisObject))
  if usp.isNil:
    return JSValueMakeNull(ctx)
  
  var pairs: seq[string] = @[]
  for key, values in usp.params:
    for value in values:
      pairs.add(key & "=" & value)
  
  let resultString = pairs.join("&")
  result = JSValueMakeString(ctx, JSStringCreateWithUTF8CString(resultString.cstring))

proc finalizeURLSearchParams(obj: JSObjectRef) {.cdecl.} =
  let usp = cast[URLSearchParams](getPrivateData(obj))
  if not usp.isNil:
    GC_unref(usp)
  removePrivateData(obj)

proc urlSearchParamsGetProperty(ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, exception: ptr JSValueRef): JSValueRef {.cdecl.} =
  let name = jsStringToNimStr(propertyName)
  case name
  of "size":
    let usp = cast[URLSearchParams](getPrivateData(obj))
    if usp.isNil:
      return JSValueMakeNumber(ctx, 0.cdouble)
    result = JSValueMakeNumber(ctx, usp.params.len.cdouble)

proc createURLSearchParamsClass*(ctx: JSContextRef) =
  var classdef = JSClassDefinition(
        version: 0,
        attributes: kJSClassAttributeHasPrivateData,
        className: "URLSearchParams",
        finalize: finalizeURLSearchParams,
        hasProperty: nil,
        getProperty: urlSearchParamsGetProperty,
        setProperty: nil,
        deleteProperty: nil,
        getPropertyNames: nil,
        callAsFunction: nil,
        callAsConstructor: nil,
        hasInstance: nil,
        convertToType: nil
    )

  classRef = JSClassCreate(addr classdef)
  
  let constructor = JSObjectMakeConstructor(ctx, classRef, urlSearchParamsConstructor)
  setPrivateData(constructor, cast[pointer](classRef))

  let prototype = JSObjectGetPrototype(ctx, constructor)
  
  let methods: Table[string, JSObjectCallAsFunctionCallback] = {
    "append": urlSearchParamsAppend,
    "delete": urlSearchParamsDelete,
    "get": urlSearchParamsGet,
    "getAll": urlSearchParamsGetAll,
    "has": urlSearchParamsHas,
    "set": urlSearchParamsSet,
    "sort": urlSearchParamsSort,
    "toString": urlSearchParamsToString
  }.toTable

  for name, fn in methods.pairs:
    let nameStr = JSStringCreateWithUTF8CString(name.cstring)
    let fnObj = JSObjectMakeFunctionWithCallback(ctx, nameStr, fn)
    JSObjectSetProperty(ctx, prototype, JSStringCreateWithUTF8CString(name.cstring), cast[JSValueRef](fnObj), kJSPropertyAttributeDontDelete, nil)
    JSStringRelease(nameStr)

  let globalObject = JSContextGetGlobalObject(ctx)
  JSObjectSetProperty(ctx, globalObject, JSStringCreateWithUTF8CString("URLSearchParams"), cast[JSValueRef](constructor), kJSPropertyAttributeNone, nil)