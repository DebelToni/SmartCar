ENTITY PluginLoader
  SET @plugins = {}
  SET @loadedPlugins = {}
  SET @configFilePath = "config/plugins.xml"
  SET @pluginDirectory = "plugins/"
  SET @defaultTimeout = 3000

  METHOD initialize()
    IF fileExists(@configFilePath) THEN
      CALL parseConfig(@configFilePath)
    ELSE
      CALL log("Configuration file not found: " + @configFilePath)
    ENDIF
  END

  METHOD parseConfig(filePath)
    SET @xmlContent = readFile(filePath)
    IF @xmlContent IS NULL THEN
      CALL log("Failed to read config file: " + filePath)
      RETURN
    ENDIF
    SET @xmlDoc = parseXml(@xmlContent)
    FOREACH @pluginNode IN @xmlDoc.selectNodes("//plugin")
      SET @name = @pluginNode.selectSingleNode("name").getText()
      SET @path = @pluginNode.selectSingleNode("path").getText()
      SET @enabled = toBoolean(@pluginNode.selectSingleNode("enabled").getText())
      IF @enabled THEN
        SET @plugins[@name] = @path
      ENDIF
    ENDFOREACH
  END

  METHOD loadPlugin(pluginName)
    IF @plugins.containsKey(pluginName) THEN
      SET @pluginPath = @pluginDirectory + @plugins[pluginName]
      IF fileExists(@pluginPath) THEN
        TRY
          SET @pluginInstance = instantiate(@pluginPath)
          SET @loadedPlugins[pluginName] = @pluginInstance
          CALL log("Loaded plugin: " + pluginName)
        CATCH e
          CALL log("Error loading plugin " + pluginName + ": " + e.message)
        ENDTRY
      ELSE
        CALL log("Plugin file not found: " + @pluginPath)
      ENDIF
    ELSE
      CALL log("Plugin not configured: " + pluginName)
    ENDIF
  END

  METHOD unloadPlugin(pluginName)
    IF @loadedPlugins.containsKey(pluginName) THEN
      SET @pluginInstance = @loadedPlugins[pluginName]
      TRY
        CALL @pluginInstance.shutdown()
        REMOVE @loadedPlugins[pluginName]
        CALL log("Unloaded plugin: " + pluginName)
      CATCH e
        CALL log("Error unloading plugin " + pluginName + ": " + e.message)
      ENDTRY
    ELSE
      CALL log("Plugin not loaded: " + pluginName)
    ENDIF
  END

  METHOD reloadPlugin(pluginName)
    CALL unloadPlugin(pluginName)
    CALL loadPlugin(pluginName)
  END

  METHOD loadAllPlugins()
    FOREACH @pluginName IN @plugins.keySet()
      CALL loadPlugin(@pluginName)
    ENDFOREACH
  END

  METHOD unloadAllPlugins()
    FOREACH @pluginName IN @loadedPlugins.keySet()
      CALL unloadPlugin(@pluginName)
    ENDFOREACH
  END

  METHOD handleEvent(eventType, eventData)
    FOREACH @plugin IN @loadedPlugins.values()
      IF @plugin.respondsToEvent(eventType) THEN
        TRY
          CALL @plugin.handleEvent(eventType, eventData)
        CATCH e
          CALL log("Error in plugin response to event " + eventType + ": " + e.message)
        ENDTRY
      ENDIF
    ENDFOREACH
  END

  METHOD start()
    CALL initialize()
    CALL loadAllPlugins()
  END

  METHOD stop()
    CALL unloadAllPlugins()
  END

  METHOD reloadAll()
    CALL unloadAllPlugins()
    CALL loadAllPlugins()
  END

  METHOD dynamicReloadPlugin(pluginName)
    CALL reloadPlugin(pluginName)
  END

  METHOD monitorConfigChanges()
    WHILE TRUE
      IF fileChanged(@configFilePath) THEN
        CALL log("Configuration change detected, reloading...")
        CALL unloadAllPlugins()
        CALL parseConfig(@configFilePath)
        CALL loadAllPlugins()
      ENDIF
      WAIT(@defaultTimeout)
    ENDWHILE
  END

  METHOD run()
    CALL start()
    START_THREAD(@monitorThread, self, "monitorConfigChanges")
  END

ENDENTITY