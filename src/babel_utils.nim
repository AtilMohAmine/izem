import js_bindings, js_constants, js_utils
import std/json

proc loadBabel*(ctx: JSContextRef) =
  let babelCode = readFile("./src/js/babel.min.js")
  var exception: JSValueRef = NULL_JS_VALUE
  discard JSEvaluateScript(ctx, JSStringCreateWithUTF8CString(babelCode.cstring), NULL_JS_VALUE, NULL_JS_STRING, 0, addr exception)
  if exception != NULL_JS_VALUE:
    echo "Error loading Babel: ", jsValueToNimStr(ctx, exception)

proc transpileModule*(ctx: JSContextRef, code: string, filename: string): string =
  let babelGlobal = JSObjectGetProperty(ctx, JSContextGetGlobalObject(ctx), JSStringCreateWithUTF8CString("Babel"), nil)

  let babelTransform = JSValueToObject(ctx, babelGlobal, nil)
  let transformMethod = JSObjectGetProperty(ctx, babelTransform, JSStringCreateWithUTF8CString("transform"), nil)
  
  let options = %*{
    "presets": ["env", "typescript"],
    "plugins": ["transform-modules-commonjs"],
    "filename": filename
  }
  
  var exception: JSValueRef = NULL_JS_VALUE
  let args = [JSValueMakeString(ctx, JSStringCreateWithUTF8CString(code)),
              nimStrToJSObject(ctx, $options)]
  let result = JSObjectCallAsFunction(ctx, JSValueToObject(ctx, transformMethod, nil), NULL_JS_OBJECT, 2, addr args[0], addr exception)
  
  if exception != NULL_JS_VALUE:
    echo "Babel transform error: ", jsValueToNimStr(ctx, exception)
    return ""
  
  let codeProperty = JSObjectGetProperty(ctx, JSValueToObject(ctx, result, nil), JSStringCreateWithUTF8CString("code"), nil)
  return jsValueToNimStr(ctx, codeProperty)
