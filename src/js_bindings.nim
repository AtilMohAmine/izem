{.push header: "<JavaScriptCore/JavaScript.h>".}

type
  JSContextRef* = distinct pointer
  JSValueRef* = distinct pointer
  JSStringRef* = distinct pointer
  JSGlobalContextRef* = distinct JSContextRef
  JSObjectRef* = distinct pointer
  JSPropertyAttributes* = enum
   kJSPropertyAttributeNone = 0

  JSObjectCallAsFunctionCallback* = proc (ctx: JSContextRef, function: JSObjectRef, 
    thisObject: JSObjectRef, argumentCount: csize_t, arguments: ptr JSValueRef, 
    exception: ptr JSValueRef): JSValueRef {.cdecl.}

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
proc JSObjectMake*(ctx: JSContextRef, jsClass: pointer, data: pointer): JSObjectRef {.importc.}
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

{.pop.}