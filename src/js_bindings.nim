{.push header: "<JavaScriptCore/JavaScript.h>".}

const
  kJSClassAttributeHasPrivateData* = 1 shl 0

type
  JSContextRef* = distinct pointer
  JSValueRef* = distinct pointer
  JSStringRef* = distinct pointer
  JSGlobalContextRef* = distinct JSContextRef
  JSObjectRef* = distinct pointer
  JSClassRef* = distinct pointer
  JSPropertyAttributes* = enum
   kJSPropertyAttributeNone = 0
   kJSPropertyAttributeReadOnly = 1 shl 1
   kJSPropertyAttributeDontEnum = 1 shl 2
   kJSPropertyAttributeDontDelete = 1 shl 3

  JSObjectCallAsFunctionCallback* = proc (ctx: JSContextRef, function: JSObjectRef, 
    thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, 
    exception: ptr JSValueRef): JSValueRef {.cdecl.}

  JSPropertyNameArrayRef* = distinct pointer
  JSObjectInitializeCallback* = proc (ctx: JSContextRef, obj: JSObjectRef) {.cdecl.}
  JSObjectFinalizeCallback* = proc (obj: JSObjectRef) {.cdecl.}
  JSObjectHasPropertyCallback* = proc (ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef): bool {.cdecl.}
  JSObjectGetPropertyCallback* = proc (ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, exception: ptr JSValueRef): JSValueRef {.cdecl.}
  JSObjectSetPropertyCallback* = proc (ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, value: JSValueRef, exception: ptr JSValueRef): bool {.cdecl.}
  JSObjectDeletePropertyCallback* = proc (ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, exception: ptr JSValueRef): bool {.cdecl.}
  JSObjectGetPropertyNamesCallback* = proc (ctx: JSContextRef, obj: JSObjectRef, propertyNames: JSPropertyNameArrayRef) {.cdecl.}
  JSObjectCallAsConstructorCallback* = proc (ctx: JSContextRef, constructor: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSObjectRef {.cdecl.}
  JSObjectHasInstanceCallback* = proc (ctx: JSContextRef, constructor: JSObjectRef, possibleInstance: JSValueRef, exception: ptr JSValueRef): bool {.cdecl.}
  JSObjectConvertToTypeCallback* = proc (ctx: JSContextRef, obj: JSObjectRef, toType: cint, exception: ptr JSValueRef): JSValueRef {.cdecl.}

  JSClassDefinition* = object
    version*: cint
    attributes*: cint
    className*: cstring
    parentClass*: pointer
    staticValues*: pointer
    staticFunctions*: pointer
    initialize*: JSObjectInitializeCallback
    finalize*: JSObjectFinalizeCallback
    hasProperty*: JSObjectHasPropertyCallback
    getProperty*: JSObjectGetPropertyCallback
    setProperty*: JSObjectSetPropertyCallback
    deleteProperty*: JSObjectDeletePropertyCallback
    getPropertyNames*: JSObjectGetPropertyNamesCallback
    callAsFunction*: JSObjectCallAsFunctionCallback
    callAsConstructor*: JSObjectCallAsConstructorCallback
    hasInstance*: JSObjectHasInstanceCallback
    convertToType*: JSObjectConvertToTypeCallback

  JSStaticValue* = object
    name*: cstring
    getProperty*: JSObjectGetPropertyCallback
    setProperty*: JSObjectSetPropertyCallback
    attributes*: JSPropertyAttributes

proc `==`*(a, b: JSValueRef): bool {.borrow.}
proc `==`*(a, b: JSStringRef): bool {.borrow.}
proc `==`*(a, b: JSObjectRef): bool {.borrow.}

proc JSGlobalContextCreate*(globalObject: pointer): JSGlobalContextRef {.importc.}
proc JSGlobalContextRelease*(ctx: JSGlobalContextRef) {.importc.}
proc JSStringCreateWithUTF8CString*(str: cstring): JSStringRef {.importc.}
proc JSStringRelease*(str: JSStringRef) {.importc.}
proc JSEvaluateScript*(ctx: JSContextRef, script: JSStringRef, thisObject: JSValueRef, sourceURL: JSStringRef, startingLineNumber: cint, exception: ptr JSValueRef): JSValueRef {.importc.}
proc JSValueToStringCopy*(ctx: JSContextRef, value: JSValueRef, exception: ptr JSValueRef): JSStringRef {.importc.}
proc JSStringGetUTF8CString*(string: JSStringRef, buffer: cstring, bufferSize: csize_t): csize_t {.cdecl, importc.}

proc JSValueMakeUndefined*(ctx: JSContextRef): JSValueRef {.importc.}
proc JSValueMakeString*(ctx: JSContextRef, string: JSStringRef): JSValueRef {.cdecl, importc.}
proc JSContextGetGlobalObject*(ctx: JSContextRef): JSObjectRef {.importc.}
proc JSObjectMake*(ctx: JSContextRef, jsClass: pointer, data: pointer): JSObjectRef {.importc, cdecl.}
proc JSObjectMakeFunctionWithCallback*(ctx: JSContextRef, name: JSStringRef, callAsFunction: proc (ctx: JSContextRef, function: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl.}): JSObjectRef {.importc, cdecl.}
proc JSObjectSetProperty*(ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, value: JSValueRef, attributes: JSPropertyAttributes, exception: ptr JSValueRef) {.importc.}
proc JSObjectCallAsFunction*(ctx: JSContextRef, obj: JSObjectRef, thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSValueRef {.cdecl, importc.}
proc JSObjectSetPropertyAtIndex*(ctx: JSContextRef, obj: JSObjectRef, index: cuint, value: JSValueRef, exception: ptr JSValueRef) {.cdecl, importc.}
proc JSStringGetMaximumUTF8CStringSize*(string: JSStringRef): csize_t {.importc.}

proc JSValueIsUndefined*(ctx: JSContextRef, value: JSValueRef): bool {.importc.}
proc JSValueIsNull*(ctx: JSContextRef, value: JSValueRef): bool {.importc.}
proc JSValueIsBoolean*(ctx: JSContextRef, value: JSValueRef): bool {.importc.}
proc JSValueIsNumber*(ctx: JSContextRef, value: JSValueRef): bool {.importc.}
proc JSObjectIsFunction*(ctx: JSContextRef, obj: JSObjectRef): bool {.importc.}
proc JSValueIsObject*(ctx: JSContextRef, value: JSValueRef): bool {.importc.}
proc JSValueIsArray*(ctx: JSContextRef, value: JSValueRef): bool {.importc.}
proc JSValueIsString*(ctx: JSContextRef, value: JSValueRef): bool {.importc.}

proc JSValueToBoolean*(ctx: JSContextRef, value: JSValueRef): bool {.importc.}
proc JSValueToNumber*(ctx: JSContextRef, value: JSValueRef, exception: ptr JSValueRef): cdouble {.importc.}
proc JSValueToObject*(ctx: JSContextRef, value: JSValueRef, exception: ptr JSValueRef): JSObjectRef {.importc.}

proc JSValueMakeFromJSONString*(ctx: JSContextRef, string: JSStringRef): JSValueRef {.importc.}
proc JSValueMakeNumber*(ctx: JSContextRef, number: cdouble): JSValueRef {.cdecl, importc.}
proc JSValueMakeBoolean*(ctx: JSContextRef, boolean: cint): JSValueRef {.cdecl, importc.}
proc JSValueMakeNull*(ctx: JSContextRef): JSValueRef {.cdecl, importc.}
proc JSObjectMakeArray*(ctx: JSContextRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSObjectRef {.cdecl, importc.}

proc JSValueUnprotect*(ctx: JSContextRef, value: JSValueRef) {.cdecl.}
proc JSObjectGetProperty*(ctx: JSContextRef, obj: JSObjectRef, propertyName: JSStringRef, exception: ptr JSValueRef): JSValueRef {.importc.}
proc JSObjectMakeFunction*(ctx: JSContextRef, name: JSStringRef, paramCount: csize_t, paramNames: ptr JSStringRef, body: JSStringRef, sourceURL: JSStringRef, startingLineNumber: cint, exception: ptr JSValueRef): JSObjectRef {.importc.}
proc JSObjectGetPropertyAtIndex*(ctx: JSContextRef, obj: JSObjectRef, index: cuint, exception: ptr JSValueRef): JSValueRef {.importc.}
proc JSObjectCopyPropertyNames*(ctx: JSContextRef, obj: JSObjectRef): JSPropertyNameArrayRef {.importc, cdecl.}
proc JSPropertyNameArrayGetCount*(array: JSPropertyNameArrayRef): csize_t {.importc, cdecl.}
proc JSPropertyNameArrayGetNameAtIndex*(array: JSPropertyNameArrayRef, index: csize_t): JSStringRef {.importc, cdecl.}
proc JSPropertyNameArrayRelease*(array: JSPropertyNameArrayRef) {.importc, cdecl.}

proc JSObjectSetPrivate*(obj: JSObjectRef, data: pointer): bool {.importc, cdecl.}
proc JSObjectGetPrivate*(obj: JSObjectRef): pointer {.importc, cdecl.}
proc JSClassCreate*(definition: ptr JSClassDefinition): JSClassRef {.importc, cdecl.}
proc JSObjectMakeConstructor*(ctx: JSContextRef, jsClass: JSClassRef, callAsConstructor: JSObjectCallAsConstructorCallback): JSObjectRef {.importc, cdecl.}
proc JSObjectSetPrototype*(ctx: JSContextRef, obj: JSObjectRef, value: JSValueRef) {.importc, cdecl.}
proc JSObjectGetPrototype*(ctx: JSContextRef, obj: JSObjectRef): JSObjectRef {.importc, cdecl.}
proc JSStringGetLength*(string: JSStringRef): csize_t {.importc.}
proc JSValueCreateJSONString*(ctx: JSContextRef, value: JSValueRef, indent: cuint, exception: ptr JSValueRef): JSStringRef {.importc, cdecl.}
proc JSObjectCallAsConstructor*(ctx: JSContextRef, obj: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, exception: ptr JSValueRef): JSObjectRef {.importc.}

{.pop.}