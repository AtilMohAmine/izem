import os, js_bindings, js_constants, server, js_api/console
  
proc main() =
  if paramCount() != 1:
    echo "Usage: ./runtime <script.js>"
    return

  let filename = paramStr(1)
  if not fileExists(filename):
    echo "File not found: ", filename
    return

  let scriptContent = readFile(filename)

  let globalCtx = JSGlobalContextCreate(nil)
  if globalCtx.pointer != nil:
    echo "JavaScript context created successfully!"

    createConsoleObject(cast[JSContextRef](globalCtx))
    createServerObject(cast[JSContextRef](globalCtx))
    
    let scriptString = JSStringCreateWithUTF8CString(scriptContent.cstring)
    var exception: JSValueRef = NULL_JS_VALUE
    discard JSEvaluateScript(JSContextRef(globalCtx), scriptString, NULL_JS_VALUE, NULL_JS_STRING, 0, addr exception)
    
    JSStringRelease(scriptString)
    #JSGlobalContextRelease(ctx)
  else:
    echo "Failed to create JavaScript context."

when isMainModule:
  main()