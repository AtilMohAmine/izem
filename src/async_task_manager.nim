import asyncdispatch, tables, oids

type
  AsyncTaskManager* = ref object
    activeTasks: Table[string, Future[void]]

var asyncTaskManager {.threadvar.}: AsyncTaskManager

proc initAsyncTaskManager*() =
  asyncTaskManager = AsyncTaskManager(activeTasks: initTable[string, Future[void]]())

proc removeTask(id: string) =
  if id in asyncTaskManager.activeTasks:
    asyncTaskManager.activeTasks.del(id)

proc addTask*(task: Future[void]): string =
  let id = $genOid()
  asyncTaskManager.activeTasks[id] = task
  return id

proc hasRunningTasks*(): bool =
  return asyncTaskManager.activeTasks.len > 0

proc trackAsync*(task: Future[void]) =
  let id = addTask(task)
  asyncCheck task
  task.addCallback(proc (fut: Future[void]) =
    removeTask(id)
  )

template asyncCheckTracked*(task: Future[void]) =
  trackAsync(task)
