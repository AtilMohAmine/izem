import asyncdispatch, js_bindings, js_api/timers, async_task_manager
import locks

type
  Task = ref object
    ctx: JSContextRef
    function: JSObjectRef
    obj: JSObjectRef
    args: seq[JSValueRef]
    exception: ptr JSValueRef
    promise: Future[JSValueRef]

var
  taskQueue: seq[Task]
  queueLock: Lock
  queueCond: Cond
  isRunning*: bool

proc shutdown*() =
  isRunning = false
  acquire(queueLock)
  queueCond.signal()  # Wake up the processing thread so it can exit
  release(queueLock)
  
  deinitLock(queueLock)
  deinitCond(queueCond)

proc addTaskToQueue(task: Task) =
  acquire(queueLock)
  taskQueue.add(task)
  queueCond.signal()  # Signal the condition variable to wake up the processing thread
  release(queueLock)

proc processQueue() {.thread.} =
  {.cast(gcsafe).}:
    while true:
      acquire(queueLock)
      if taskQueue.len == 0:
        queueCond.wait(queueLock)  # Wait for a task to be added
      if not isRunning:
        break
      var task = taskQueue[0]
      taskQueue.delete(0)
      release(queueLock)

      if task.isNil:
        continue

      let result = JSObjectCallAsFunction(task.ctx, task.function, task.obj, task.args.len.csize_t, 
                                          if task.args.len > 0: addr task.args[0] else: nil, task.exception)
      task.promise.complete(result)

proc startEventLoop*() {.async.} =
  if not isRunning:
    isRunning = true
    var t: Thread[void]

    createThread(t, processQueue)

    while isRunning:
      await sleepAsync(10)
      if taskQueue.len == 0 and getTimersCount() == 0 and not hasRunningTasks():
        shutdown()
      
proc initEventLoop*() =
  taskQueue = @[]
  initLock(queueLock)
  initCond(queueCond)
  isRunning = false
  initAsyncTaskManager()

proc callJSFunctionAsync*(ctx: JSContextRef, function: JSObjectRef, obj: JSObjectRef, args: seq[JSValueRef], exception: ptr JSValueRef): Future[JSValueRef] =
  result = newFuture[JSValueRef]()

  if JSObjectIsFunction(ctx, function):
    var task = new(Task)
    GC_ref(task)
    task.ctx = ctx
    task.function = function
    task.obj = obj
    task.args = args
    task.exception = exception
    task.promise = result

    addTaskToQueue(task)
  else:
    result.complete(JSValueMakeUndefined(ctx))
