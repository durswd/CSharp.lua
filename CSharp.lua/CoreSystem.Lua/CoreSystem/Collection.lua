--[[
Copyright 2017 YANG Huan (sy.yanghuan@gmail.com).

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

  http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
--]]

local System = System
local define = System.define
local throw = System.throw
local div = System.div
local emptyFn = System.emptyFn
local getCurrent = System.getCurrent
local ArgumentOutOfRangeException = System.ArgumentOutOfRangeException
local InvalidOperationException = System.InvalidOperationException
local ArgumentNullException = System.ArgumentNullException
local NullReferenceException = System.NullReferenceException
local EqualityComparer_1 = System.EqualityComparer_1
local Comparer_1 = System.Comparer_1

local table = table
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local tmove = table.move
local pack = table.pack
local unpack = table.unpack
local setmetatable = setmetatable
local select = select
local type = type
local assert = assert
local coroutine = coroutine
local ccreate = coroutine.create
local cresume = coroutine.resume
local cyield = coroutine.yield

local Collection = {}
local null = {}

local function throwFailedVersion()
  throw(InvalidOperationException("Collection was modified; enumeration operation may not execute."))
end

local function checkIndex(t, index) 
  if index < 0 or index >= #t then
    throw(ArgumentOutOfRangeException("index"))
  end
end

local function checkIndexAndCount(t, index, count)
  if count < 0 or index > #t - count then
    throw(ArgumentOutOfRangeException("index or count"))
  end
end

Collection.checkIndex = checkIndex
Collection.checkIndexAndCount = checkIndexAndCount

local function wrap(v)
  if v == nil then 
    return null 
  end
  return v
end

local function unWrap(v)
  if v == null then 
    return nil 
  end
  return v
end

Collection.wrap = wrap
Collection.unWrap = unWrap

local function checkInsertIndex(t, index)   
  if index < 0 or index > #t then
    throw(ArgumentOutOfRangeException("index"))
  end
end

function Collection.insertArray(t, index, v)
  checkInsertIndex(t, index)
  tinsert(t, index + 1, wrap(v))
  t.version = t.version + 1
end

local function copyArray(sourceArray, sourceIndex, destinationArray, destinationIndex, length, reliable)
  if not reliable then
    if sourceArray == nil then throw(ArgumentNullException("sourceArray")) end
    if destinationArray == nil then throw(ArgumentNullException("destinationArray")) end
    checkIndexAndCount(sourceArray, sourceIndex, length)
    checkIndexAndCount(destinationArray, destinationIndex, length)
  end
  tmove(sourceArray, sourceIndex + 1, sourceIndex + length, destinationIndex + 1, destinationArray)
end 

function Collection.copyArray(t, ...)
  local len = select("#", ...)     
  if len == 2 then
    local array, length = ...
    copyArray(t, 0, array, 0, length)
  else 
    copyArray(t, ...)
  end
end

function Collection.removeArray(t, index, count)
  checkIndexAndCount(t, index, count)
  if count > 0 then
    local size = #t - count
    if index < size then
      copyArray(t, index + count, t, index, size - index)
    end
    for i = size + 1, size + count do
      t[i] = nil
    end
    t.version = t.version + 1
  end
end

local function binarySearchArray(t, index, count, v, comparer)
  checkIndexAndCount(t, index, count)
  local compare
  if comparer == nil then
    compare = Comparer_1(t.__genericT__).getDefault().Compare 
  else    
    compare = comparer.compare
  end
  local lo = index
  local hi = index + count - 1
  while lo <= hi do
    local i = lo + div(hi - lo, 2)
    local order = compare(unWrap(t[i + 1]), v);
    if order == 0 then return i end
    if order < 0 then
      lo = i + 1
    else
      hi = i - 1
    end
  end
  return -1
end 

function Collection.binarySearchArray(t, ...)
  local v, index, count, comparer
  local len = select("#", ...)
  if len == 1 then
    v = ...
    index = 0
    count = #t
  elseif len == 2 then
    v, index = ...
    count = #t - index
  elseif len == 3 then
    index, count, v = ...
  else
    index, count, v, comparer = ...
  end
  return binarySearchArray(t, index, count, v, comparer)
end

local function findIndexOfArray(t, ...)
  local startIndex, count, match
  local len = select("#", ...)
  if len == 1 then
    startIndex = 0
    count = #t
    match = ...
  elseif len == 2 then
    startIndex, match  = ...
    count = #t - startIndex
  else
    startIndex, count, match = ...
  end
  if match == nil then
    throw(ArgumentNullException("match"))
  end
  checkIndexAndCount(t, startIndex, count)
  local endIndex = startIndex + count
  for i = startIndex + 1, endIndex  do
    local item = unWrap(t[i])
    if match(item) then
      return i - 1
    end
  end
  return -1
end

Collection.findIndexOfArray = findIndexOfArray

function Collection.existsOfArray(t, match)
  return findIndexOfArray(t, match) ~= -1
end

function Collection.findOfArray(t, match)
  if match == nil then
    throw(ArgumentNullException("match"))
  end
  for i = 1, #t do
    local item = unWrap(t[i])
    if match(item) then
      return item
    end
  end
  return t.__genericT__:default()
end

function Collection.findAllOfArray(t, match)
  if match == nil then
    throw(ArgumentNullException("match"))
  end
  local list = System.List(t.__genericT__)()
  for i = 1, #t do
    local item = unWrap(t[i])
    if match(item) then
      list:Add(item)
    end
  end
  return list
end

function Collection.findLastOfArray(t, match)
  if match == nil then
    throw(ArgumentNullException("match"))
  end
  for i = #t, 1, -1 do
    local item = unWrap(t[i])
    if match(item) then
      return item
    end
  end
  return t.__genericT__:default()
end

function Collection.findLastIndexOfArray(t, ...)
  local startIndex, count, match
  local len = select("#", ...)
  if len == 1 then
    startIndex = 0
    count = #t
    match = ...
  elseif len == 2 then
    startIndex, match  = ...
    count = #t - startIndex
  else
    startIndex, count, match = ...
  end
  if match == nil then
    throw(ArgumentNullException("match"))
  end
  if count < 0 or startIndex - count + 1 < 0 then
    throw(ArgumentOutOfRangeException("count"))
  end
  local endIndex = startIndex - count
  checkIndex(endIndex)
  for i = startIndex + 1, endIndex, -1 do
    local item = unWrap(t[i])
    if match(item) then
      return i - 1
    end
  end
  return -1
end

local function indexOfArray(t, v, index, count)
  checkIndexAndCount(t, index, count)
  local equals = EqualityComparer_1(t.__genericT__).getDefault().Equals
  for i = index + 1, index + count do 
    if equals(unWrap(t[i]), v) then
      return i - 1
    end
  end
  return -1
end

function Collection.indexOfArray(t, ...)
  local v, index, count
  local len = select("#", ...)
  if len == 1 then
    v = ...
    index = 0
    count = #t
  elseif len == 2 then
    v, index = ...
    count = #t - index
  else
    v, index, count = ...
  end
  return indexOfArray(t, v, index, count)
end

function Collection.contains(t, item)
  return indexOfArray(t, item, 0, #t) ~= -1
end

local function lastIndexOfArray(t, v, index, count)
  if count < 0 or index - count + 1 < 0 then
    throw(ArgumentOutOfRangeException("count"))
  end
  checkIndex(t, index - count)
  local equals = EqualityComparer_1(t.__genericT__).getDefault().Equals
  for i = index + 1, index - count, -1 do 
    if equals(unWrap(t[i]), v) then
      return i - 1
    end
  end
  return -1
end

function Collection.lastIndexOfArray(t, ...)
  local v, index, count
  local len = select("#", ...)
  if len == 1 then
    v = ...
    count = #t
    index = count - 1
  elseif len == 2 then
    v, index = ...
    count = #t == 0 and 0 or (index + 1)
  else
    v, index, count = ...
  end
  return lastIndexOfArray(t, v, index, count)
end

function Collection.resizeArray(t, newSize, T)
  if newSize < 0 then throw(ArgumentOutOfRangeException("newSize")) end
  if t == nil then
    return System.Array(T):new(newSize)
  end
  local arr = t
  if #arr ~= newSize then
    arr = setmetatable({}, System.Array(T))
    tmove(t, 1, #t, 1, arr)
  end
  return arr
end

function Collection.reverseArray(t, index, count)
  if not index then
    index = 0
    count = #t
  end 
  checkIndexAndCount(t, index, count)
  local i, j = index + 1, index + count
  while i <= j do
    t[i], t[j] = t[j], t[i]
    i = i + 1
    j = j - 1
  end
  t.version = t.version + 1
end

local function getComp(t, comparer)
  local compare
  if comparer == nil then
    compare = Comparer_1(t.__genericT__).getDefault().Compare 
  elseif comparer.Compare then    
    compare = comparer.Compare
  else
    compare = comparer
  end
  return function(x, y) 
    return compare(unWrap(x), unWrap(y)) < 0
  end
end

local function sort(t, comparer)
  if #t > 1 then
    tsort(t, getComp(t, comparer))
    t.version = t.version + 1
  end
end

Collection.sort = sort

local function sortArray(t, index, count, comparer)
  if count > 1 then
    local comp = getComp(t, comparer)
    if index == 0 and count == #t then
      tsort(t, comp)
    else
      checkIndexAndCount(t, index, count)
      local arr = {}
      tmove(t, index + 1, index + count, 1, arr)
      tsort(arr, comp)
      tmove(arr, 1, count, index + 1, t)
    end
    t.version = t.version + 1
  end
end

function Collection.sortArray(t, ...)
  local len = select("#", ...)
  if len == 0 then
    sort(t)
  elseif len == 1 then
    local comparer = ...
    sort(t, comparer)
  else
    local index, count, comparer = ...
    sortArray(t, index, count, comparer)
  end
end

function Collection.trueForAllOfArray(t, match)
  if match == nil then
    throw(ArgumentNullException("match"))
  end
  for i = 1, #t do
    if not match(unWrap(t[i])) then
      return false
    end
  end
  return true
end

local function ipairsArray(t)
  local version = t.version
  return function (t, i)
    if version ~= t.version then
      throwFailedVersion()
    end
    local v = t[i]
    if v ~= nil then
      if v == null then
        v = nil
      end
      return i + 1, v
    end
  end, t, 1
end

function Collection.forEachArray(t, action)
  if action == null then throw(ArgumentNullException("action")) end
  local version = t.version
  for i = 1, #t do
    if version ~= t.version then
      throwFailedVersion()
    end
    action(unWrap(t[i]))
  end
end

local ArrayEnumerator = {
  __index = false,
  getCurrent = getCurrent, 
  Dispose = emptyFn,
  Reset = function (this)
    this.index = 1
    this.current = nil
  end,
  MoveNext = function (this)
    local t = this.list
    if this.version ~= t.version then
      throwFailedVersion()
    end
    local index = this.index
    local v = t[index]
    if v ~= nil then
      if v == null then
        this.current = nil
      else
        this.current = v
      end
      this.index = index + 1
      return true
    end
    this.current = nil
    return false
  end,
}
ArrayEnumerator.__index = ArrayEnumerator

local function arrayEnumerator(t)
  return setmetatable({ list = t, index = 1, version = t.version }, ArrayEnumerator)
end

Collection.arrayEnumerator = arrayEnumerator

local function isArrayLike(t)
  return t.GetEnumerator == arrayEnumerator
end

local function isEnumerableLike(t)
  return type(t) == "table" and t.GetEnumerator ~= nil
end

local function eachFn(en)
  if en:MoveNext() then
    return true, en:getCurrent()
  end
  return nil
end

local function each(t)
  if t == nil then throw(NullReferenceException(), 1) end
  local getEnumerator = t.GetEnumerator
  if getEnumerator == arrayEnumerator then
    return ipairsArray(t)
  end
  local en = getEnumerator(t)
  return eachFn, en
end

function Collection.insertRangeArray(t, index, collection) 
  if collection == nil then
    throw(ArgumentNullException("collection"))
  end
  checkInsertIndex(t, index)
  for _, v in each(collection) do
    index = index + 1
    tinsert(t, index, wrap(v))
  end
  t.version = t.version + 1
end

function Collection.toArray(t)
  local array = {}    
  if isArrayLike(t) then
    tmove(t, 1, #t, 1, array)
  else
    local count = 1
    for _, v in each(t) do
      array[count] = wrap(v)
      count = count + 1
    end
  end
  return System.arrayFromTable(array, t.__genericT__)
end

local function toLuaTable(array)
  local t = {}
  for i = 1, #array do
    t[i] = unWrap(array[i])
  end   
  return t
end

local Nullable = System.Nullable
function Nullable.Compare(n1, n2, T)
  if n1 then
    if n2 then return Comparer_1(T).getDefault().Compare(n1, n2) end
    return 1
  end
  if n2 then return -1 end
  return 0
end

function Nullable.Equals(n1, n2, T)
  if n1 then
    if n2 then return EqualityComparer_1(t.__genericT__).getDefault().Equals(n1, n2) end
    return false
  end
  if n2 then return false end
  return true
end

local yieldCoroutinePool = {}
local yieldCoroutineExit = {}

local function yieldCoroutineCreate(f)
  local co = tremove(yieldCoroutinePool)
  if co == nil then
    co = ccreate(function (...)
      f(...)
      while true do
        f = nil
        yieldCoroutinePool[#yieldCoroutinePool + 1] = co
        f = cyield(yieldCoroutineExit)
        f(cyield())
      end
    end)
  else
    cresume(co, f)
  end
  return co
end

local YieldEnumerator = { getCurrent = getCurrent, Dispose = emptyFn }
YieldEnumerator.__inherits__ = { System.IEnumerator }

function YieldEnumerator.MoveNext(this)
  local co = this.co
  if co == "exit" then
    return false
  end

  local ok, v
  if co == nil then
    co = yieldCoroutineCreate(this.f)
    this.co = co
    local args = this.args
    ok, v = cresume(co, unpack(args, 1, args.n))
    this.args = nil
  else
    ok, v = cresume(co)
  end

  if ok then
    if v == yieldCoroutineExit then
      this.co = "exit"
      this.current = nil
      return false
    else
      this.current = v
      return true
    end
  else
    throw(v)
  end
end

define("System.YieldEnumerator", YieldEnumerator)

local function yieldIEnumerator(f, T, ...)
  return setmetatable({ f = f, __genericT__ = T, args = pack(...) }, YieldEnumerator)
end

local YieldEnumerable = {}
YieldEnumerable.__inherits__ = { System.IEnumerable }

function YieldEnumerable.GetEnumerator(this)
  return setmetatable({ f = this.f, __genericT__ = this.__genericT__, args = this.args }, YieldEnumerator)
end

define("System.YieldEnumerable", YieldEnumerable)

local function yieldIEnumerable(f, T, ...)
  return setmetatable({ f = f, __genericT__ = T, args = pack(...) }, YieldEnumerable)
end

System.toLuaTable = toLuaTable
System.Collection = Collection
System.null = null
System.Void = null
System.each = each
System.ipairs = ipairsArray
System.isArrayLike = isArrayLike
System.isEnumerableLike = isEnumerableLike
System.throwFailedVersion = throwFailedVersion
System.yieldIEnumerator = yieldIEnumerator
System.yieldIEnumerable = yieldIEnumerable
System.yieldReturn = cyield
