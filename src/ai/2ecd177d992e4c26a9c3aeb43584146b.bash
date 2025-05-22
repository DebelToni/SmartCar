#!/bin/bash

# Base plugin directory
PLUGIN_DIR="/usr/local/myapp/plugins"
# Directory where enabled plugins are listed
ENABLED_CONFIG="/etc/myapp/enabled_plugins.conf"
# Associative array to hold loaded plugins
declare -A loaded_plugins
# Array to hold plugin load order
declare -a plugin_order

# Function to load plugin configuration
load_plugin_config() {
    local plugin_path="$1"
    local config_file="$plugin_path/plugin.conf"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        # Expect plugins to define variables like PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_DEPENDENCIES
        echo "Loaded config for $(basename "$plugin_path")"
    else
        echo "No config found for $(basename "$plugin_path")"
    fi
}

# Function to check dependencies
check_dependencies() {
    local plugin_name="$1"
    shift
    local dependencies=("$@")
    local missing_deps=()
    for dep in "${dependencies[@]}"; do
        if ! declare -p "$dep" &>/dev/null; then
            missing_deps+=("$dep")
        fi
    done
    if (( ${#missing_deps[@]} > 0 )); then
        echo "Missing dependencies for $plugin_name: ${missing_deps[*]}"
        return 1
    fi
    return 0
}

# Function to initialize plugin
initialize_plugin() {
    local plugin_path="$1"
    local plugin_name="$2"
    if [[ -f "$plugin_path/init.sh" ]]; then
        source "$plugin_path/init.sh"
        echo "Initialized plugin $plugin_name"
    else
        echo "No init script for $plugin_name"
    fi
}

# Function to load a plugin
load_plugin() {
    local plugin_path="$1"
    load_plugin_config "$plugin_path"
    local plugin_name="${PLUGIN_NAME:-$(basename "$plugin_path")}"
    local dependencies=("${PLUGIN_DEPENDENCIES[@]}")
    if check_dependencies "$plugin_name" "${dependencies[@]}"; then
        initialize_plugin "$plugin_path" "$plugin_name"
        loaded_plugins["$plugin_name"]="$plugin_path"
        plugin_order+=("$plugin_name")
        echo "Loaded plugin: $plugin_name"
    else
        echo "Failed to load plugin: $plugin_name due to missing dependencies"
    fi
}

# Function to resolve plugin dependencies (topological sort)
resolve_dependencies() {
    local deps_map=()
    local temp_stack=()
    local visited=()
    local plugin
    declare -A graph=()
    # Build dependency graph
    for plugin_path in "$PLUGIN_DIR"/*; do
        if [[ -d "$plugin_path" ]]; then
            load_plugin_config "$plugin_path"
            local plugin_name="${PLUGIN_NAME:-$(basename "$plugin_path")}"
            local dependencies=("${PLUGIN_DEPENDENCIES[@]}")
            graph["$plugin_name"]="${dependencies[*]}"
        fi
    done
    # Function for DFS
    dfs() {
        local node="$1"
        local state="$2"
        if [[ "$state" == "temp" ]]; then
            echo "Circular dependency detected at $node" >&2
            return 1
        fi
        if [[ "$state" == "perm" ]]; then
            return 0
        fi
        # mark node as temporary
        temp_stack+=("$node")
        for dep in ${graph["$node"]}; do
            # Check if dependency exists
            if [[ -z "${graph["$dep"]}" ]]; then
                echo "Dependency $dep for $node not found" >&2
                continue
            fi
            dfs "$dep" "temp" || return 1
        done
        # mark node as permanent
        # Remove from temp_stack
        for i in "${!temp_stack[@]}"; do
            if [[ "${temp_stack[i]}" == "$node" ]]; then
                unset 'temp_stack[i]'
            fi
        done
        plugin_order+=("$node")
        return 0
    }
    # Resolve dependencies for all plugins
    for plugin in "${!graph[@]}"; do
        # Reset temp_stack
        temp_stack=()
        dfs "$plugin" "perm" || return 1
    done
    # Remove duplicates while preserving order
    local unique_order=()
    declare -A seen=()
    for p in "${plugin_order[@]}"; do
        if [[ -z "${seen[$p]}" ]]; then
            unique_order+=("$p")
            seen["$p"]=1
        fi
    done
    plugin_order=("${unique_order[@]}")
    return 0
}

# Function to load all plugins based on dependency resolution
load_all_plugins() {
    if resolve_dependencies; then
        for plugin_name in "${plugin_order[@]}"; do
            local plugin_path
            plugin_path="${PLUGIN_DIR}/${plugin_name}"
            if [[ -d "$plugin_path" ]]; then
                load_plugin "$plugin_path"
            else
                echo "Plugin directory for $plugin_name not found"
            fi
        done
    else
        echo "Failed to resolve plugin dependencies"
        exit 1
    fi
}

# Function to enable plugins from configuration
enable_plugins() {
    if [[ -f "$ENABLED_CONFIG" ]]; then
        while IFS= read -r plugin_name; do
            local plugin_path="${PLUGIN_DIR}/${plugin_name}"
            if [[ -d "$plugin_path" ]]; then
                load_plugin "$plugin_path"
            else
                echo "Plugin $plugin_name not found in $PLUGIN_DIR"
            fi
        done < "$ENABLED_CONFIG"
    else
        echo "Enabled plugins config not found"
    fi
}

# Function to monitor plugin directory for changes
monitor_plugins() {
    local dir="$PLUGIN_DIR"
    inotifywait -e create -e delete -e modify -r "$dir" | while read -r event; do
        echo "Change detected in plugin directory: $event"
        # Reload plugins based on change
        # For simplicity, reload all plugins
        loaded_plugins=()
        plugin_order=()
        load_all_plugins
    done
}

# Main script execution
main() {
    echo "Starting plugin loader..."
    enable_plugins
    load_all_plugins
    echo "Monitoring plugin directory for changes..."
    monitor_plugins &
    wait
}

# Run main
main