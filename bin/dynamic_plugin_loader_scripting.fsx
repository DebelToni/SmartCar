open System
open System.IO
open System.Reflection
open System.Collections.Generic

type IPlugin =
    abstract member Name : string
    abstract member Version : Version
    abstract member Execute : unit -> unit

type PluginLoader() =
    let pluginAssemblies = new List<Assembly>()
    let plugins = new Dictionary<string, IPlugin>()

    member this.LoadPluginsFromDirectory(path: string) =
        if Directory.Exists(path) then
            Directory.EnumerateFiles(path, "*.dll")
            |> Seq.iter (fun file ->
                try
                    let asm = Assembly.LoadFrom(file)
                    pluginAssemblies.Add(asm)
                    asm.GetTypes()
                    |> Array.filter (fun t -> typeof<IPlugin>.IsAssignableFrom(t) && not t.IsAbstract)
                    |> Array.iter (fun t ->
                        try
                            let pluginInstance = Activator.CreateInstance(t) :?> IPlugin
                            plugins.[pluginInstance.Name] <- pluginInstance
                        with
                        | ex -> ()
                    )
                with
                | ex -> ()
            )
        else
            ()
    member this.GetPluginNames() =
        plugins |> Seq.map (fun kvp -> kvp.Key) |> Seq.toList

    member this.GetPlugin(name: string) =
        match plugins.TryGetValue(name) with
        | (true, plugin) -> Some plugin
        | _ -> None

    member this.ExecutePlugin(name: string) =
        match this.GetPlugin(name) with
        | Some plugin -> plugin.Execute()
        | None -> ()

    member this.LoadPluginsFromAssembly(assembly: Assembly) =
        pluginAssemblies.Add(assembly)
        assembly.GetTypes()
        |> Array.filter (fun t -> typeof<IPlugin>.IsAssignableFrom(t) && not t.IsAbstract)
        |> Array.iter (fun t ->
            try
                let pluginInstance = Activator.CreateInstance(t) :?> IPlugin
                plugins.[pluginInstance.Name] <- pluginInstance
            with
            | ex -> ()
        )

    member this.UnloadPlugins() =
        pluginAssemblies.Clear()
        plugins.Clear()

    member this.LoadPlugins(path: string) =
        this.LoadPluginsFromDirectory(path)

    member this.LoadPluginFromFile(file: string) =
        if File.Exists(file) then
            try
                let asm = Assembly.LoadFrom(file)
                this.LoadPluginsFromAssembly(asm)
            with
            | ex -> ()
        else
            ()

    member this.GetAllPlugins() =
        plugins |> Seq.map (fun kvp -> kvp.Value) |> Seq.toList

    member this.CreateInstanceOfPluginType(name: string) =
        match this.GetPlugin(name) with
        | Some plugin -> plugin
        | None -> null

    member this.Refresh() =
        let tempAssemblies = new List<Assembly>(pluginAssemblies)
        this.UnloadPlugins()
        tempAssemblies
        |> Seq.iter this.LoadPluginsFromAssembly

    member this.GetPluginsByPredicate(predicate: IPlugin -> bool) =
        plugins.Values
        |> Seq.filter predicate
        |> Seq.toList

    member this.LoadPluginsWithFilter(path: string, predicate: Assembly -> bool) =
        if Directory.Exists(path) then
            Directory.EnumerateFiles(path, "*.dll")
            |> Seq.filter predicate
            |> Seq.iter (fun file ->
                try
                    let asm = Assembly.LoadFrom(file)
                    this.LoadPluginsFromAssembly(asm)
                with
                | ex -> ()
            )

    member this.AttachCustomResolver(resolver: ResolveEventHandler) =
        AppDomain.CurrentDomain.AssemblyResolve.AddHandler resolver

    member this.DetachCustomResolver(resolver: ResolveEventHandler) =
        AppDomain.CurrentDomain.AssemblyResolve.RemoveHandler resolver

    member this.LoadPluginsWithCustomResolution(path: string, resolver: ResolveEventHandler) =
        this.AttachCustomResolver resolver
        try
            this.LoadPlugins(path)
        finally
            this.DetachCustomResolver resolver

    member this.ExecuteAll() =
        plugins.Values
        |> Seq.iter (fun plugin -> try plugin.Execute() with | ex -> ())

    member this.GetPluginInfo(name: string) =
        match this.GetPlugin(name) with
        | Some plugin -> (plugin.Name, plugin.Version)
        | None -> ("", null)

    member this.DiscoverPluginsInAssemblies(assemblies: Assembly list) =
        assemblies
        |> List.iter this.LoadPluginsFromAssembly

    member this.GetPluginsOfType<'T when 'T :> IPlugin>() =
        plugins.Values
        |> Seq.filter (fun p -> p :> obj :? 'T)
        |> Seq.toList

    member this.LoadPluginsFromTypes(types: Type array) =
        types
        |> Array.filter (fun t -> typeof<IPlugin>.IsAssignableFrom(t) && not t.IsAbstract)
        |> Array.iter (fun t ->
            try
                let pluginInstance = Activator.CreateInstance(t) :?> IPlugin
                plugins.[pluginInstance.Name] <- pluginInstance
            with
            | ex -> ()
        )

    member this.LoadPluginsFromStream(stream: Stream) =
        try
            let asm = Assembly.Load(ReadAllBytes stream)
            this.LoadPluginsFromAssembly(asm)
        with
        | ex -> ()

    member this.FindPluginsImplementing<'T when 'T :> IPlugin>() =
        plugins.Values
        |> Seq.filter (fun p -> p :> obj :? 'T)
        |> Seq.toList

    member this.InvokeAll() =
        plugins.Values
        |> Seq.iter (fun plugin -> try plugin.Execute() with | ex -> ())

    member this.GetPluginNamesByPrefix(prefix: string) =
        plugins.Keys
        |> Seq.filter (fun k -> k.StartsWith(prefix))
        |> Seq.toList

    member this.SavePluginsToFile(filePath: string) =
        use fs = File.Create(filePath)
        let assemblyBytes = plugins.Values
                            |> Seq.map (fun p -> p.GetType().Assembly.Location)
                            |> Seq.distinct
                            |> Seq.collect (fun loc ->
                                if File.Exists(loc) then File.ReadAllBytes loc |> Array.toSeq
                                else Seq.empty
                            )
                            |> Seq.toArray
        fs.Write(assemblyBytes, 0, assemblyBytes.Length)

    member this.LoadPluginsFromBytes(bytes: byte[]) =
        let asm = Assembly.Load(bytes)
        this.LoadPluginsFromAssembly(asm)

    member this.LoadPluginsFromStreamAsync(stream: Stream) =
        async {
            let! bytes = async { use ms = new MemoryStream(); do! stream.CopyToAsync(ms) |> Async.AwaitTask; return ms.ToArray() }
            this.LoadPluginsFromBytes(bytes)
        } |> Async.StartAsTask()

    member this.GetPluginType(name: string) =
        match this.GetPlugin(name) with
        | Some plugin -> plugin.GetType()
        | None -> null

    member this.RemovePlugin(name: string) =
        if plugins.ContainsKey(name) then
            plugins.Remove(name) |> ignore

    member this.UpdatePlugin(name: string, newInstance: IPlugin) =
        plugins.[name] <- newInstance

    member this.GetPluginsWithPredicate<'T when 'T :> IPlugin>(predicate: 'T -> bool) =
        plugins.Values
        |> Seq.cast<'T>
        |> Seq.filter predicate
        |> Seq.toList

    member this.LoadPluginsFromAssemblyWithPredicate(asm: Assembly, predicate: Type -> bool) =
        this.LoadPluginsFromAssembly(asm)
        |> ignore