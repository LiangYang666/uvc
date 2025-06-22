#!/bin/bash

# Environment search directories, can contain multiple environments, default first line is $HOME/.uvc/envs
UVC_ENV_SEARCH_ROOTS_CONFIG="$HOME/.uvc/env-search-roots"
# Additional environment paths, directly pointing to environment directories, e.g., virtual environment directory of a project, /project/example/.venv
UVC_LINKED_ENV_PATHS_CONFIG="$HOME/.uvc/linked-env-paths"

uvc_load_config() {
    if [ -f "$UVC_ENV_SEARCH_ROOTS_CONFIG" ]; then
        UVC_ENV_SEARCH_ROOTS=$(tr '\n' ':' < "$UVC_ENV_SEARCH_ROOTS_CONFIG" | sed 's/:$//')
        export UVC_ENV_SEARCH_ROOTS
    else
        mkdir -p "$(dirname "$UVC_ENV_SEARCH_ROOTS_CONFIG")"
        echo "$HOME/.uvc/envs" > "$UVC_ENV_SEARCH_ROOTS_CONFIG"
        export UVC_ENV_SEARCH_ROOTS="$HOME/.uvc/envs"
    fi

    if [ -f "$UVC_LINKED_ENV_PATHS_CONFIG" ]; then
        UVC_LINKED_ENV_PATHS=$(tr '\n' ':' < "$UVC_LINKED_ENV_PATHS_CONFIG" | sed 's/:$//')
        export UVC_LINKED_ENV_PATHS
    else
        mkdir -p "$(dirname "$UVC_LINKED_ENV_PATHS_CONFIG")"
        touch "$UVC_LINKED_ENV_PATHS_CONFIG"
        export UVC_LINKED_ENV_PATHS=""
    fi
}

uvc_save_config() {
    echo "$UVC_ENV_SEARCH_ROOTS" | tr ':' '\n' > "$UVC_ENV_SEARCH_ROOTS_CONFIG"
}

uvc_add_env_search_root() {
    DIR=$1
    if grep -qxF "$DIR" "$UVC_ENV_SEARCH_ROOTS_CONFIG"; then
        echo "$DIR is already in the env-search-roots file."
    else
        echo "$DIR" >> "$UVC_ENV_SEARCH_ROOTS_CONFIG"
        uvc_load_config
        echo "Added $DIR to env-search-roots and updated UVC_ENV_SEARCH_ROOTS."
    fi
}

uvc_remove_env_search_root() {
    DIR=$1
    if grep -qxF "$DIR" "$UVC_ENV_SEARCH_ROOTS_CONFIG"; then
        sed -i '' "\|^$DIR\$|d" "$UVC_ENV_SEARCH_ROOTS_CONFIG"
        uvc_load_config
        echo "Removed $DIR from env-search-roots and updated UVC_ENV_SEARCH_ROOTS."
    else
        echo "$DIR is not in the env-search-roots file."
    fi
}

uvc_list_env_search_roots() {
    if [ -f "$UVC_ENV_SEARCH_ROOTS_CONFIG" ]; then
        echo "# Environment directories:"
        cat "$UVC_ENV_SEARCH_ROOTS_CONFIG"
    else
        echo "No environment directories found."
    fi
}

uvc_link_an_env() {
    ENV_PATH=$1
    if grep -qxF "$ENV_PATH" "$UVC_LINKED_ENV_PATHS_CONFIG"; then
        echo "$ENV_PATH is already in the linked-env-paths file."
    else
        echo "$ENV_PATH" >> "$UVC_LINKED_ENV_PATHS_CONFIG"
        uvc_load_config
        echo "Added $ENV_PATH to linked-env-paths and updated UVC_LINKED_ENV_PATHS."
    fi
}
uvc_unlink_an_env() {
    ENV_PATH=$1
    if grep -qxF "$ENV_PATH" "$UVC_LINKED_ENV_PATHS_CONFIG"; then
        sed -i '' "\|^$ENV_PATH\$|d" "$UVC_LINKED_ENV_PATHS_CONFIG"
        uvc_load_config
        echo "Removed $ENV_PATH from linked-env-paths and updated UVC_LINKED_ENV_PATHS."
    else
        echo "$ENV_PATH is not in the linked-env-paths file."
    fi
}

uvc_remove_env() {
    ENV_NAME=$1
    IFS=":" read -r paths <<< $(echo $UVC_ENV_SEARCH_ROOTS)
    for t_path in ${paths}; do
        ENV_PATH="$t_path/$ENV_NAME"
        if [ -d "$ENV_PATH" ]; then
            rm -rf "$ENV_PATH"
            echo "Removed environment $ENV_NAME in $t_path"
            return
        fi
    done
    echo "Environment $ENV_NAME does not exist."
}

uvc_activate() {
    if [ -n "$VIRTUAL_ENV" ]; then
        uvc_deactivate
    fi

    # Internal function to activate environment
    _do_activate() {
        local t_env_path="$1"
        local t_env_name="$2"

        if [ -f "$t_env_path/bin/activate" ]; then
            # Environment with activate script
            source "$t_env_path/bin/activate"
        elif [ -f "$t_env_path/.venv/bin/activate" ]; then
            # Environment with activate script
            source "$t_env_path/.venv/bin/activate"
        else
            export _OLD_VIRTUAL_PATH="$PATH"
            export _OLD_PS1="$PS1"
            export _OLD_VIRTUAL_ENV="$VIRTUAL_ENV"
            export VIRTUAL_ENV="$t_env_path"
            export PATH="$VIRTUAL_ENV/bin:$PATH"
            export PS1="($t_env_name) $PS1"
        fi
        echo "Activated environment: $t_env_name"
        return 0
    }

    # Check linked environments first
    IFS=":" read -r linked_paths <<< $(echo $UVC_LINKED_ENV_PATHS)
    for linked_path in ${linked_paths}; do
        if [ -d "$linked_path" ]; then
            t_env_name=$(basename "$linked_path")
            # If folder name is .venv, use parent directory name
            if [ "$t_env_name" = ".venv" ]; then
                t_env_name=$(basename "$(dirname "$linked_path")")
            fi

            if [ "$t_env_name" = "$1" ]; then
                ENV_PATH="$linked_path"
                if [ -d "$ENV_PATH" ]; then
                    _do_activate "$ENV_PATH" "$1"
                    return
                fi
            fi
        fi
    done

    # Check search root directories
    IFS=":" read -r paths <<< $(echo $UVC_ENV_SEARCH_ROOTS)
    for t_path in ${paths}; do
        ENV_PATH="$t_path/$1"
        if [ -d "$ENV_PATH" ]; then
            _do_activate "$ENV_PATH" "$1"
            return
        fi
    done

    echo "Environment $1 does not exist."
}

uvc_deactivate() {
    if [ -n "$VIRTUAL_ENV" ]; then
        if [ -f "$VIRTUAL_ENV/bin/activate" ]; then
            # 带activate环境变量
            deactivate
            return
        else
            export PATH="$_OLD_VIRTUAL_PATH"
            export PS1="$_OLD_PS1"
            export VIRTUAL_ENV="$_OLD_VIRTUAL_ENV"
            unset _OLD_VIRTUAL_PATH
            unset _OLD_PS1
            unset _OLD_VIRTUAL_ENV
        fi
        echo "Deactivated current environment."
    else
        echo "No environment is currently active."
    fi
}

uvc_env_list() {
    echo "# Custom Python environments:"
    echo "#"

    # Create a temporary file to store environments
    temp_file="${TMPDIR:-/tmp}/uvc_envs_$$"
    max_len=0

    # Add environments from search roots
    if [ -n "$UVC_ENV_SEARCH_ROOTS" ]; then
        OLD_IFS="$IFS"
        IFS=":"
        set -- $UVC_ENV_SEARCH_ROOTS
        IFS="$OLD_IFS"

        for t_path in "$@"; do
            [ -z "$t_path" ] && continue
            if [ -d "$t_path" ]; then
                for env_dir in "$t_path"/*; do
                    if [ -d "$env_dir" ]; then
                        ENV_NAME=$(basename "$env_dir")
                        echo "$ENV_NAME|$env_dir" >> "$temp_file"
                        # Calculate string length
                        env_name_len=$(echo "$ENV_NAME" | wc -c)
                        env_name_len=$((env_name_len - 1))
                        if [ $env_name_len -gt $max_len ]; then
                            max_len=$env_name_len
                        fi
                    fi
                done
            fi
        done
    fi

    # Add linked environments
    if [ -n "$UVC_LINKED_ENV_PATHS" ]; then
        OLD_IFS="$IFS"
        IFS=":"
        set -- $UVC_LINKED_ENV_PATHS
        IFS="$OLD_IFS"

        for linked_path in "$@"; do
            [ -z "$linked_path" ] && continue
            if [ -d "$linked_path" ]; then
                t_env_name=$(basename "$linked_path")
                # If folder name is .venv, use parent directory name
                if [ "$t_env_name" = ".venv" ]; then
                    t_env_name=$(basename "$(dirname "$linked_path")")
                fi
                echo "$t_env_name|$linked_path (linked)" >> "$temp_file"
                env_name_len=$(echo "$t_env_name" | wc -c)
                env_name_len=$((env_name_len - 1))
                if [ $env_name_len -gt $max_len ]; then
                    max_len=$env_name_len
                fi
            fi
        done
    fi

    # Display all environments if temp file exists and has content
    if [ -f "$temp_file" ] && [ -s "$temp_file" ]; then
        while IFS='|' read -r t_env_name t_env_path; do
            # Remove " (linked)" suffix for comparison
            case "$t_env_path" in
                *" (linked)")
                    actual_path="${t_env_path% (linked)}"
                    ;;
                *)
                    actual_path="$t_env_path"
                    ;;
            esac

            # Check if this environment is currently active
            if [ -n "$VIRTUAL_ENV" ] && [ "$VIRTUAL_ENV" = "$actual_path" ]; then
                printf "%-${max_len}s *  %s\n" "$t_env_name" "$t_env_path"
            else
                printf "%-${max_len}s    %s\n" "$t_env_name" "$t_env_path"
            fi
        done < "$temp_file" | /usr/bin/sort
    fi
    # Clean up
    rm -f "$temp_file"
}

uvc_create() {
    IFS=":" read -r paths <<< $(echo $UVC_ENV_SEARCH_ROOTS)
    for t_path in ${paths}; do
        ENV_PATH="$t_path/$1"
        if [ -d "$ENV_PATH" ]; then
            echo "Environment $1 already exists in $t_path."
            return
        fi
    done

    ENV_PATH="${paths[0]}/$1"

    if [ ! -z "$2" ]; then
        (uv init "$ENV_PATH" --python "$2" && cd "$ENV_PATH" && uv venv --python "$2")
    else
        (uv init "$ENV_PATH" && cd "$ENV_PATH" && uv venv)
    fi
    echo "Created environment: $1 in $ENV_PATH"
}

uvc_uv() {
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "No virtual environment is currently activated."
        echo "Please activate an environment first using: uvc activate <t_env_name>"
        return 1
    fi

    # Get the environment root directory (parent of bin)
    ENV_ROOT=$(dirname "$VIRTUAL_ENV")

    # Change to environment directory and execute uv command
    (cd "$ENV_ROOT" && uv "$@")
}

uvc() {
    COMMAND=$1
    shift
    case "$COMMAND" in
        activate)
            if [ -z "$1" ]; then
                echo "Usage: uvc activate <t_env_name>"
            else
                uvc_activate $1
            fi
            ;;
        deactivate)
            uvc_deactivate
            ;;
        uv)
            uvc_uv "$@"
            ;;
        env)
            SUBCOMMAND=$1
            shift
            case "$SUBCOMMAND" in
                list)
                    uvc_env_list
                    ;;
                link)
                    if [ $# -eq 1 ]; then
                        uvc_link_an_env "$1"
                    else
                        echo "Usage: uvc env link <t_env_path>"
                    fi
                    ;;
                unlink)
                    if [ $# -eq 1 ]; then
                        uvc_unlink_an_env "$1"
                    else
                        echo "Usage: uvc env unlink <t_env_path>"
                    fi
                    ;;
                *)
                    echo "Unknown subcommand: $SUBCOMMAND"
                    echo "Usage: uvc env list|link|unlink"
                    ;;
            esac
            ;;
        create)
            ENV_NAME=""
            PYTHON_VERSION=""

            while [[ $# -gt 0 ]]; do
                case $1 in
                    -n|--name)
                        ENV_NAME=$2
                        shift
                        shift
                        ;;
                    python=*)
                        PYTHON_VERSION="${1#python=}"  # Extract the version after 'python='
                        shift
                        ;;
                    *)
                        echo "Unknown option: $1"
                        echo "Usage: uvc create -n <t_env_name> [python=<version>]"
                        ;;
                esac
            done
            if [ -z "$ENV_NAME" ]; then
                echo "Usage: uvc create -n <t_env_name> [python=<version>]"
            else
                uvc_create $ENV_NAME $PYTHON_VERSION
            fi
            ;;
        remove)
            ENV_NAME=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    -n|--name)
                        ENV_NAME=$2
                        shift
                        shift
                        ;;
                    *)
                        echo "Unknown option: $1"
                        echo "Usage: uvc remove -n <t_env_name>"
                        ;;
                esac
            done

            if [ -z "$ENV_NAME" ]; then
                echo "Usage: uvc remove <t_env_name>"
            else
                uvc_remove_env $ENV_NAME
            fi
            ;;
        config)
            SUBCOMMAND=$1
            shift
            case "$SUBCOMMAND" in
                --add)
                    OPTION=$1
                    DIR=$2
                    if [ "$OPTION" = "env-search-roots" ] && [ ! -z "$DIR" ]; then
                        uvc_add_env_search_root "$DIR"
                    else
                        echo "Usage: uvc config --add env-search-roots <dir>"
                    fi
                    ;;
                --remove)
                    OPTION=$1
                    DIR=$2
                    if [ "$OPTION" = "env-search-roots" ] && [ ! -z "$DIR" ]; then
                        uvc_remove_env_search_root "$DIR"
                    else
                        echo "Usage: uvc config --remove env-search-roots <dir>"
                    fi
                    ;;
                --show)
                    OPTION=$1
                    if [ "$OPTION" = "env-search-roots" ]; then
                        uvc_list_env_search_roots
                    else
                        echo "Usage: uvc config --show env-search-roots"
                    fi
                    ;;
                *)
                    echo "Unknown config option: $SUBCOMMAND"
                    ;;
            esac
            ;;
        *)
            echo "Unknown command: $COMMAND"
            echo "Usage: uvc <command> [<args>]"
            echo "Commands:"
            echo "  activate <t_env_name>  Activate the specified environment"
            echo "  deactivate           Deactivate the current environment"
            echo "  uv <uv_command>      Execute uv commands in the current virtual environment"
            echo "  env list             List all available environments"
            echo "  env link <t_env_path>   Link an environment to the linked environments"
            echo "  env unlink <t_env_path>  Unlink an environment from the linked environments"
            echo "  remove -n <t_env_name>  Remove the specified environment"
            echo "  create -n <t_env_name>  Create a new environment using default Python version"
            echo "  create -n <t_env_name> python=3.x   Create a new environment using Python 3.x"
            echo "  config --add env-search-roots <dir>      Add a directory to env-search-roots in the config"
            echo "  config --remove env-search-roots <dir>   Remove a directory from env-search-roots in the config"
            echo "  config --show env-search-roots           Show the current env-search-roots in the config"
            ;;
    esac
}

uvc_load_config

