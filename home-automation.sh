#!/bin/bash

readonly PACKAGE_VERSION="$(<VERSION)"
readonly LOG_DEBUG_ACTIVE=${2} # TODO cleaner solution with independence of amount of arguments

readonly DOCKER_BASE="./docker"
readonly DOCKER_FILE_NODERED="${DOCKER_BASE}/node-red/dockerfile"
readonly DOCKER_IMAGE_NODERED="home-auto-nodered"
readonly DOCKER_CONTAINER_NODERED="home-auto-nodered"

readonly NODE_RED_PORT=1880 # Node-red port for accessing from outside the container
readonly NODE_RED_DATA_FOLDER="/data"

readonly NODE_RED_FILES="./node-red-files"
readonly NODE_RED_FLOW_FILES=("flows.json") #TODO when copying the flows_cred.json is necessary the usage of fix credentials have to be implemented. Keyword: key handling
readonly NODE_RED_SETTING_FILES=("settings.js")
readonly SCRIPT_SET_CREDENTIALS="set_credentials.sh"
readonly SCRIPT_SET_LOGIN="set_login.sh"

function add_auto_completion() {
    local completion_script='
#/usr/bin/env bash
_home-automation_completions() 
{
  COMPREPLY=($(compgen -W "scratch getNodeRedFiles updateNodeRedFiles install start stop update uninstall setCredentials version help" "${COMP_WORDS[1]}"))
}
complete -F _home-automation_completions home-automation.sh'

    echo "${completion_script}" >/etc/bash_completion.d/home-automation
}

function show_help() {
    echo "Home automation system setup script"
    echo "Copyright (c) 2019 Matthias Deimbacher under MIT license"
    echo
    echo "Usage:"
    echo "${0} {scratch|getNodeRedFlows|updateNodeRedFlows|install|start|stop|update|uninstall|setCredentials|version|help|--addAutoCompletion} {dir}"
    echo
    echo "scratch                       Set up a complete home-automation system from scratch to running."
    echo "                              Useful for a \"virgin\" host where the home-automation system was not installed yet"
    echo "getNodeRedFiles {dir}         Copies NodeRed files from the container to the given directory"
    echo "                              Useful during developing the flows itself"
    echo "updateNodeRedFiles {dir}      Copies NodeRed files from current repo dir to the container volume"
    echo "                              Useful for updating the NodeRed files without rebuilding the container image"
    echo
    echo "install                       Build all necessary docker images and volumes"
    echo "start                         Start the system with all it necessary containers"
    echo "stop                          Stop the system and all related containers"
    echo "update                        Get latest version of git repo and update the container images"
    echo "uninstall                     Remove all installed docker images and volumes"
    echo "setCredentials                Set login password and flow credentials"
    echo "                              Container must be running!"
    echo
    echo "version | -v | --version      Show version of the home-automation package"
    echo "help | -h | --help            Show this help"
    echo "--addAutoCompletion           adds auto completion for this script to the bash setting. Root permission required!"
}

function show_version() {
    echo ${PACKAGE_VERSION}
}

function log_debug() {
    if [[ "${LOG_DEBUG_ACTIVE}" == "-d" ]]; then
        echo "home-automation script: ${1}"
    fi
}

function check_dependencies() {
    log_debug "check_dependencies"

    #Check for installed docker
    if ! [[ -x "$(which docker)" ]]; then
        echo
        echo "Error! Docker not installed"
        exit 1
    fi

    #Check for installed git
    if ! [[ -x "$(which git)" ]]; then
        echo
        echo "Error! Git not installed"
        exit 1
    fi
}

function detect_os() {
    local uname_os=$(uname -o)

    case ${uname_os} in
        "Msys")
            echo "win"
            ;;

        "GNU/Linux")
            echo "linux"
            ;;

        *)
            echo ${uname_os}
            ;;
    esac
}

function detect_arch() {
    local uname_arch=$(uname -m)

    case ${uname_arch} in
        "x86_64")
            echo "amd64"
            ;;

        *"arm"*)
            echo "arm"
            ;;

        *)
            echo ${uname_arch}
            ;;
    esac
}

function check_host_supported() {
    log_debug "check_host_supported"

    local detected_os=$(detect_os)
    local detected_arch=$(detect_arch)

    log_debug "Detected OS: ${detected_os}"
    log_debug "Detected architecture: ${detected_arch}"

    case ${detected_os} in
        "win")
            echo "Error! Windows OS not supported"
            exit 1
            ;;

        "linux")
            #  all fine
            ;;

        *)
            echo "Error! Unsupported host OS: ${detected_os}"
            exit 1
            ;;
    esac

    case ${detected_arch} in
        "arm" | "amd64")
            # all fine
            ;;

        *)
            echo "Error! Unsupported host architecture: ${detected_arch}"
            exit 1
            ;;
    esac
}

function confirm_command() {
    echo -n "Are you sure that you want to ${1} (Non persistent data will be lost!!!!)? [yes|no] "
    read confirm_choice

    case ${confirm_choice} in
        "yes" | "Yes" | "y" | "Y")
            # continue
            return
            ;;

        "no" | "No" | "n" | "N" | "")
            echo "... aborted"
            exit 0
            ;;

        *)
            echo "What?????"
            exit 1
            ;;
    esac
}

function get_container_status() {
    local raw_container_status=$(docker container inspect ${DOCKER_CONTAINER_NODERED} | grep Status)
    # FIXME find better solution where we won't get an error in case of a non existing container

    case ${raw_container_status} in
        "            \"Status\": \"running\",")
            echo "running"
            ;;

        "            \"Status\": \"created\",")
            echo "created"
            ;;

        "            \"Status\": \"exited\",")
            echo "exited"
            ;;

        *)
            echo "unknown"
            ;;
    esac
}

function update_repo() {
    log_debug "Get newest repo version from Git"
    if ! git pull; then
        echo "Error! Git pull failed. Hint: Files must be cloned from Git"
        exit 1
    fi
}

function install_system() {
    log_debug "install_system"

    log_debug "Build docker image"
    if ! docker build -t ${DOCKER_IMAGE_NODERED}:latest -f ${DOCKER_FILE_NODERED}_$(detect_os)_$(detect_arch) .; then
        echo "Error! Building node-red docker image failed"
        exit 1
    fi

    log_debug "Create container"
    if ! docker create -p ${NODE_RED_PORT}:1880 --restart unless-stopped --name ${DOCKER_CONTAINER_NODERED} ${DOCKER_IMAGE_NODERED}; then
        echo "Error! Creating node-red docker container failed"
        exit 1
    fi

    for filename in "${NODE_RED_SETTING_FILES[@]}"; do
        if ! docker cp ${NODE_RED_FILES}/${filename} ${DOCKER_CONTAINER_NODERED}:${NODE_RED_DATA_FOLDER}/; then
            echo "Error! Copying ${filename} to docker failed"
            exit 1
        fi
    done
}

function uninstall_system() {
    # Remove container
    if ! docker container rm ${DOCKER_CONTAINER_NODERED}; then
        echo "Error! Removing node-red docker container failed"
        exit 1
    fi

    # Delete image and config files
    if ! docker image rm ${DOCKER_IMAGE_NODERED}; then
        echo "Error! Removing node-red docker image failed"
        exit 1
    fi
}

function start_system() {
    log_debug "start_system"

    log_debug "Starting docker container"
    if ! docker start ${DOCKER_CONTAINER_NODERED}; then
        echo "Error! Starting node-red docker container failed"
        exit 1
    fi
}

function stop_system() {
    log_debug "stop_system"

    log_debug "Stopping docker container"
    if ! docker stop ${DOCKER_CONTAINER_NODERED}; then
        echo "Error! Stopping node-ned docker container failed"
        exit 1
    fi
}

function restart_system() {
    log_debug "restart_system"

    log_debug "Restarting docker container"
    if ! docker restart ${DOCKER_CONTAINER_NODERED}; then
        echo "Error! Restarting node-ned docker container failed"
        exit 1
    fi
}

function update_system() {
    log_debug "update_system"
    local container_status=$(get_container_status)

    stop_system
    uninstall_system
    update_repo
    install_system

    if [[ ${container_status} == "running" ]]; then
        start_system
        set_credentials
        restart_system
    else
        echo
        echo "ATTENTION!!!! Remember to set credentials after starting the system"
        echo
    fi
}

function set_credentials() {
    log_debug "setting credentials"

    if [[ $(get_container_status) != "running" ]]; then
        echo "Error! Container must be running"
        exit 1
    fi

    # copy script for setting login
    if ! docker cp ${NODE_RED_FILES}/${SCRIPT_SET_LOGIN} ${DOCKER_CONTAINER_NODERED}:${NODE_RED_DATA_FOLDER}/; then
        echo "Error! Copying login pass script to docker failed"
        exit 1
    fi

    if ! docker exec -i ${DOCKER_CONTAINER_NODERED} ${NODE_RED_DATA_FOLDER}/${SCRIPT_SET_LOGIN}; then
        echo "Error! Setting login pass for node-red editor failed"
    fi

    # copy script for setting credential
    if ! docker cp ${NODE_RED_FILES}/${SCRIPT_SET_CREDENTIALS} ${DOCKER_CONTAINER_NODERED}:${NODE_RED_DATA_FOLDER}/; then
        echo "Error! Copying credential script to docker failed"
        exit 1
    fi
    if ! docker exec -i ${DOCKER_CONTAINER_NODERED} ${NODE_RED_DATA_FOLDER}/${SCRIPT_SET_CREDENTIALS}; then
        echo "Error! Setting credential for node-red flows failed"
    fi
}

function system_from_scratch() {
    log_debug "system_from_scratch"

    local container_status=$(get_container_status)

    # if container already exists then we cannot build from scratch
    if [[ ${container_status} == "running" ]] || [[ ${container_status} == "created" ]] || [[ ${container_status} == "exited" ]]; then
        echo "Error! Set up from scratch not possible because system is already installed and/or running"
        exit 1
    fi

    update_repo
    install_system
    #update_node_red_flow_files "./node-red-files"
    start_system
    set_credentials
    restart_system
}

function get_node_red_flow_files() {
    log_debug "get_node_red_flows"

    local destination_folder=${1}

    for filename in "${NODE_RED_FLOW_FILES[@]}"; do
        if ! docker cp ${DOCKER_CONTAINER_NODERED}:${NODE_RED_DATA_FOLDER}/${filename} ${destination_folder}/; then
            echo "Error! Copying ${filename} to docker failed"
            exit 1
        fi
    done
}

function update_node_red_flow_files() {
    log_debug "update_node_red_flows"

    local source_folder=${1}

    for filename in "${NODE_RED_FLOW_FILES[@]}"; do
        if ! docker cp ${source_folder}/${filename} ${DOCKER_CONTAINER_NODERED}:${NODE_RED_DATA_FOLDER}/; then
            echo "Error! Copying ${filename} to docker failed"
            exit 1
        fi
    done
}

function main() {

    check_host_supported
    check_dependencies

    case ${1} in
        "install")
            echo "Installing home automation system"
            install_system
            ;;

        "start")
            echo "Starting home automation system"
            start_system
            ;;

        "stop")
            echo "Stopping home automation system"
            stop_system
            ;;

        "update")
            echo "Updating home automation system"
            confirm_command "update the system"
            update_system
            ;;

        "uninstall")
            echo "Uninstalling home automation system"
            confirm_command "uninstall the system"
            uninstall_system
            ;;

        "setCredentials" | "setcredentials")
            echo "Setting credentials of home automation system"
            set_credentials
            restart_system
            ;;

        "scratch")
            echo "Setting up home automation system from scratch to complete running"
            system_from_scratch
            ;;

        "getNodeRedFiles" | "getnoderedfiles")
            echo "Getting NodeRed flows from home automation system"
            get_node_red_flow_files ${2}
            ;;

        "updateNodeRedFiles" | "updatenoderedfiles")
            echo "Copy NodeRed flows to home automation system"
            confirm_command "update the nodered flows"
            update_node_red_flow_files ${2}
            restart_system
            ;;

        "version" | "-v" | "--version")
            show_version
            exit 0
            ;;

        "help" | "-h" | "-?" | "--help")
            show_help
            exit 0
            ;;

        "--addAutoCompletion" | "--addautocompletion")
            echo "Adding auto completion for this script to the bash configuration"
            add_auto_completion
            ;;

        "")
            echo "ERROR! Missing command"
            echo
            show_help
            exit 1
            ;;

        *)
            echo "ERROR! Unknown command: ${1}"
            echo
            show_help
            exit 1
            ;;
    esac

    echo "..... finished!"
    exit 0
}

main "$@"
