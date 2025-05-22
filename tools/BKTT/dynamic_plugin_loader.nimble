import os, strutils, json, sugar, sequtils, options, macros

type
  PluginInfo* = object
    name*: string
    version*: string
    path*: string
    loaded*: bool

type
  PluginManager* = object
    plugins*: seq[PluginInfo]
    loadedPlugins*: Table[string, pointer]

proc initPluginManager*(): PluginManager =
  return PluginManager(plugins: @[], loadedPlugins: initTable[string, pointer]())

proc discoverPlugins*(manager: var PluginManager, directory: string) =
  for entry in walkDir(directory, {pcFile}):
    if entry.name.endsWith(".dll") or entry.name.endsWith(".so") or entry.name.endsWith(".dylib"):
      var info = PluginInfo(name: entry.name, version: "0.0.1", path: entry.absoluteFilePath, loaded: false)
      manager.plugins.add(info)

proc loadPlugin*(manager: var PluginManager, pluginName: string): bool =
  for i, plugin in manager.plugins:
    if plugin.name == pluginName:
      if plugin.loaded:
        return true
      let handleProc = importc("dlsym", "LoadLibrary")(plugin.path)
      if handleProc.isNil:
        return false
      var handlePtr = cast[pointer](handleProc)
      if handlePtr.isNil:
        return false
      manager.loadedPlugins[pluginName] = handlePtr
      manager.plugins[i].loaded = true
      return true
  return false

proc unloadPlugin*(manager: var PluginManager, pluginName: string): bool =
  if manager.loadedPlugins.containsKey(pluginName):
    let handle = manager.loadedPlugins[pluginName]
    let result = importc("dlclose", "FreeLibrary")(cast[voidptr](handle))
    if result:
      manager.loadedPlugins.del(pluginName)
      for i, plugin in manager.plugins:
        if plugin.name == pluginName:
          manager.plugins[i].loaded = false
      return true
  return false

proc getPluginInfo*(manager: var PluginManager, pluginName: string): Option[PluginInfo] =
  for plugin in manager.plugins:
    if plugin.name == pluginName:
      return some(plugin)
  return none(PluginInfo)

proc listPlugins*(manager: PluginManager): seq[string] =
  result = @[]
  for plugin in manager.plugins:
    result.add(plugin.name & " (" & plugin.version & ") Loaded: " & $plugin.loaded)
  return result

proc reloadPlugin*(manager: var PluginManager, pluginName: string): bool =
  if unloadPlugin(manager, pluginName):
    return loadPlugin(manager, pluginName)
  return false

proc savePluginConfig*(manager: PluginManager, filepath: string) =
  var jsonObj = %{}
  for plugin in manager.plugins:
    jsonObj[plugin.name] = {
      "version": plugin.version,
      "path": plugin.path,
      "loaded": plugin.loaded
    }.toJson()
  writeFile(filepath, jsonObj.toPretty())

proc loadPluginConfig*(manager: var PluginManager, filepath: string) =
  if not fileExists(filepath):
    return
  let jsonStr = readFile(filepath)
  let jsonObj = parseJson(jsonStr)
  for name, data in jsonObj.pairs:
    var info = PluginInfo(
      name: name,
      version: data["version"].getStr(),
      path: data["path"].getStr(),
      loaded: data["loaded"].getBool()
    )
    manager.plugins.add(info)
    if info.loaded:
      loadPlugin(manager, info.name)

proc main() =
  var pluginDir = getCurrentDir() / "plugins"
  var configFile = "plugin_config.json"
  var manager = initPluginManager()
  discoverPlugins(manager, pluginDir)
  loadPluginConfig(manager, configFile)
  echo "Available plugins:"
  for pluginStr in listPlugins(manager):
    echo(pluginStr)
  let pluginName = "examplePlugin.dll"
  if loadPlugin(manager, pluginName):
    echo "Loaded ", pluginName
  else:
    echo "Failed to load ", pluginName
  savePluginConfig(manager, configFile)
  let pluginToUnload = "examplePlugin.dll"
  if unloadPlugin(manager, pluginToUnload):
    echo "Unloaded ", pluginToUnload
  else:
    echo "Failed to unload ", pluginToUnload

when isMainModule:
  main()