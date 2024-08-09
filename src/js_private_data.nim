import tables, hashes
import js_bindings

type
  PrivateDataStore = ref object
    data: Table[int, pointer]

var privateDataStore {.threadvar.}: PrivateDataStore

proc getStore*(): PrivateDataStore =
  if privateDataStore.isNil:
    privateDataStore = PrivateDataStore(data: initTable[int, pointer]())
  privateDataStore

proc setPrivateData*(obj: JSObjectRef, data: pointer) =
  getStore().data[cast[int](obj)] = data

proc getPrivateData*(obj: JSObjectRef): pointer =
  let store = getStore()
  let key = cast[int](obj)
  if key in store.data:
    result = store.data[key]
  else:
    result = nil

proc hasPrivateData*(obj: JSObjectRef): bool =
  cast[int](obj) in getStore().data

proc removePrivateData*(obj: JSObjectRef) =
  getStore().data.del(cast[int](obj))