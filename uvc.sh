# ~/.uvc/uvc.sh

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
        sed -i "\|^$DIR\$|d" "$UVC_ENV_SEARCH_ROOTS_CONFIG"
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
        sed -i "\|^$ENV_PATH\$|d" "$UVC_LINKED_ENV_PATHS_CONFIG"
        uvc_load_config
        echo "Removed $ENV_PATH from linked-env-paths and updated UVC_LINKED_ENV_PATHS."
    else
        echo "$ENV_PATH is not in the linked-env-paths file."
    fi
}

uvc_remove_env() {
    ENV_NAME=$1
    IFS=":" read -r -a paths <<< "$UVC_ENV_SEARCH_ROOTS"
    for path in "${paths[@]}"; do
        ENV_PATH="$path/$ENV_NAME"
        if [ -d "$ENV_PATH" ]; then
            rm -rf "$ENV_PATH"
            echo "Removed environment $ENV_NAME in $path"
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
        local env_path="$1"
        local env_name="$2"

        if [ -f "$env_path/bin/activate" ]; then
            # Environment with activate script
            source "$env_path/bin/activate"
        elif [ -f "$env_path/.venv/bin/activate" ]; then
            # Environment with activate script
            source "$env_path/.venv/bin/activate"
        else
            export VIRTUAL_ENV="$env_path"
            export PATH="$VIRTUAL_ENV/bin:$PATH"
            export PS1="($env_name) $PS1"


            export _OLD_VIRTUAL_PATH="$PATH"
            export _OLD_PS1="$PS1"
            export _OLD_VIRTUAL_ENV="$VIRTUAL_ENV"
            export VIRTUAL_ENV="$env_path"
            export PATH="$VIRTUAL_ENV/bin:$PATH"
            export PS1="($env_name) $PS1"

        fi
        echo "Activated environment: $env_name"
        return 0
    }

    # Check linked environments first
    IFS=":" read -r -a linked_paths <<< "$UVC_LINKED_ENV_PATHS"
    for linked_path in "${linked_paths[@]}"; do
        if [ -d "$linked_path" ]; then
            env_name=$(basename "$linked_path")
            # If folder name is .venv, use parent directory name
            if [ "$env_name" = ".venv" ]; then
                env_name=$(basename "$(dirname "$linked_path")")
            fi

            if [ "$env_name" = "$1" ]; then
                ENV_PATH="$linked_path"
                if [ -d "$ENV_PATH" ]; then
                    _do_activate "$ENV_PATH" "$1"
                    return
                fi
            fi
        fi
    done

    # Check search root directories
    IFS=":" read -r -a paths <<< "$UVC_ENV_SEARCH_ROOTS"
    for path in "${paths[@]}"; do
        ENV_PATH="$path/$1"
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
            PATH=${PATH#"$VIRTUAL_ENV"}
            unset VIRTUAL_ENV
            PS1="${PS1#(*\) }"

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

    # Collect all environments (both from search roots and linked)
    declare -A all_envs
    max_len=0

    # Add environments from search roots
    if [ -n "$UVC_ENV_SEARCH_ROOTS" ]; then
        IFS=":" read -r -a paths <<< "$UVC_ENV_SEARCH_ROOTS"
        for path in "${paths[@]}"; do
            if [ -d "$path" ]; then
                for env in "$path"/*; do
                    if [ -d "$env" ]; then
                        ENV_NAME=$(basename "$env")
                        all_envs["$ENV_NAME"]="$env"
                        if [ ${#ENV_NAME} -gt $max_len ]; then
                            max_len=${#ENV_NAME}
                        fi
                    fi
                done
            fi
        done
    fi

    # Add linked environments
    if [ -n "$UVC_LINKED_ENV_PATHS" ]; then
        IFS=":" read -r -a linked_paths <<< "$UVC_LINKED_ENV_PATHS"
        for linked_path in "${linked_paths[@]}"; do
            if [ -d "$linked_path" ]; then
                env_name=$(basename "$linked_path")
                # If folder name is .venv, use parent directory name
                if [ "$env_name" = ".venv" ]; then
                    env_name=$(basename "$(dirname "$linked_path")")
                fi
                all_envs["$env_name"]="$linked_path (linked)"
                if [ ${#env_name} -gt $max_len ]; then
                    max_len=${#env_name}
                fi
            fi
        done
    fi

    # Display all environments
    for env_name in "${!all_envs[@]}"; do
        env_path="${all_envs[$env_name]}"
        actual_path="${env_path% (linked)}"

        if [ -n "$VIRTUAL_ENV" ] && [[ "$VIRTUAL_ENV" == "$actual_path" ]]; then
            printf "%-${max_len}s *  %s\n" "$env_name" "$env_path"
        else
            printf "%-${max_len}s    %s\n" "$env_name" "$env_path"
        fi
    done | sort
}

uvc_create() {
    IFS=":" read -r -a paths <<< "$UVC_ENV_SEARCH_ROOTS"
    for path in "${paths[@]}"; do
        ENV_PATH="$path/$1"
        if [ -d "$ENV_PATH" ]; then
            echo "Environment $1 already exists in $path."
            return
        fi
    done

    ENV_PATH="${paths[0]}/$1"

    if [ -n "$2" ]; then
        (uv init "$ENV_PATH" --python "$2" && cd "$ENV_PATH" && uv venv --python "$2")
    else
        (uv init "$ENV_PATH" && cd "$ENV_PATH" && uv venv)
    fi
    echo "Created environment: $1 in $ENV_PATH"
}

uvc_uv() {
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "No virtual environment is currently activated."
        echo "Please activate an environment first using: uvc activate <env_name>"
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
                echo "Usage: uvc activate <env_name>"
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
                        echo "Usage: uvc env link <env_path>"
                    fi
                    ;;
                unlink)
                    if [ $# -eq 1 ]; then
                        uvc_unlink_an_env "$1"
                    else
                        echo "Usage: uvc env unlink <env_path>"
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
                        echo "Usage: uvc create -n <env_name> [python=<version>]"
                        ;;
                esac
            done
            if [ -z "$ENV_NAME" ]; then
                echo "Usage: uvc create -n <env_name> [python=<version>]"
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
                        echo "Usage: uvc remove -n <env_name>"
                        ;;
                esac
            done

            if [ -z "$ENV_NAME" ]; then
                echo "Usage: uvc remove <env_name>"
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
                    if [ "$OPTION" = "env-search-roots" ] && [ -n "$DIR" ]; then
                        uvc_add_env_search_root "$DIR"
                    else
                        echo "Usage: uvc config --add env-search-roots <dir>"
                    fi
                    ;;
                --remove)
                    OPTION=$1
                    DIR=$2
                    if [ "$OPTION" = "env-search-roots" ] && [ -n "$ENV_NAME" ]; then
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
            echo "  activate <env_name>  Activate the specified environment"
            echo "  deactivate           Deactivate the current environment"
            echo "  uv <uv_command>      Execute uv commands in the current virtual environment"
            echo "  env list             List all available environments"
            echo "  env link <env_path>   Link an environment to the linked environments"
            echo "  env unlink <env_path>  Unlink an environment from the linked environments"
            echo "  remove -n <env_name>  Remove the specified environment"
            echo "  create -n <env_name>  Create a new environment using default Python version"
            echo "  create -n <env_name> python=3.x   Create a new environment using Python 3.x"
            echo "  config --add env-search-roots <dir>      Add a directory to env-search-roots in the config"
            echo "  config --remove env-search-roots <dir>   Remove a directory from env-search-roots in the config"
            echo "  config --show env-search-roots           Show the current env-search-roots in the config"
            ;;
    esac
}

uvc_load_config

