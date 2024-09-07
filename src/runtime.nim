import os, asyncdispatch
import js_bindings, js_constants, js_utils, server, filesystem, js_modules, event_loop, babel_utils
import js_api/console, js_api/timers, js_api/url_search_params, js_api/url, js_api/writable_stream, js_api/writable_stream_default_writer

proc setupJSContext(ctx: JSContextRef, filename: string) =
  createConsoleObject(ctx)
  createServerObject(ctx)
  addTimerFunctions(ctx)
  addFileSystemFunctions(ctx)
  addModuleSystem(ctx)
  createURLSearchParamsClass(ctx)
  createURLClass(ctx)
  createWritableStreamClass(ctx)
  createWritableStreamDefaultWriterClass(ctx)

proc evaluateScript(ctx: JSContextRef, scriptContent: string, filename: string): bool =
  let scriptString = JSStringCreateWithUTF8CString(scriptContent.cstring)
  var exception: JSValueRef = NULL_JS_VALUE
  discard JSEvaluateScript(ctx, scriptString, NULL_JS_VALUE, 
                           JSStringCreateWithUTF8CString(filename), 0, addr exception)
  JSStringRelease(scriptString)

  if exception != NULL_JS_VALUE:
    echo "Error executing script: ", jsValueToNimStr(ctx, exception)
    return false
  return true

proc main() {.async.} =
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
    #echo "JavaScript context created successfully!"

    let ctx = cast[JSContextRef](globalCtx)
    
    loadBabel(ctx)
    let transpiledCode = transpileModule(ctx, scriptContent, filename)

    setupJSContext(ctx, filename)
    initEventLoop()

    if evaluateScript(ctx, transpiledCode, filename):
      await startEventLoop()
      
    JSGlobalContextRelease(globalCtx)
  else:
    echo "Failed to create JavaScript context."

when isMainModule:
  waitFor main()