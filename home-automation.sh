#!/bin/bash

PACKAGE_VERSION="$(<VERSION)"
LOG_DEBUG_ACTIVE=${2}

DOCKER_BASE="./docker"
DOCKER_FILE_NODERED="${DOCKER_BASE}/node-red/dockerfile"
DOCKER_IMAGE_NODERED="home-auto-nodered"
DOCKER_CONTAINER_NODERED="home-auto-nodered"

NODE_RED_PORT=1880 # Node-red port for accessing from outside the container

function add_auto_completion() {
    local completion_script='
#/usr/bin/env bash
_home-automation_completions() 
{
  COMPREPLY=($(compgen -W "scratch getNodeRedFiles updateNodeRedFiles install start stop update uninstall version help" "${COMP_WORDS[1]}"))
}
complete -F _home-automation_completions home-automation.sh'

    echo "${completion_script}" >/etc/bash_completion.d/home-automation
}

function show_help() {
    echo "Home automation system setup script"
    echo "Copyright (c) 2019 Matthias Deimbacher under MIT license"
    echo
    echo "Usage:"
    echo "${0} {scratch|getNodeRedFlows|updateNodeRedFlows|install|start|stop|update|uninstall|version|help|--addAutoCompletion}"
    echo
    echo "scratch ... Set up a complete home-automation system from scratch to running."
    echo "            Useful for a \"virgin\" host where the home-automation system was not installed yet"
    echo "getNodeRedFiles ... Copies NodeRed flows from the container to the current path"
    echo "                    Useful during developing the flows itself"
    echo "updateNodeRedFiles ... Copies NodeRed flow from current repo dir to the container volume"
    echo "                       Useful for updating the NodeRed flows without rebuilding the container image"
    echo
    echo "install ... Build all necessary docker images and volumes"
    echo "start ... Start the system with all it necessary containers"
    echo "stop ... Stop the system and all related containers"
    echo "update ... Get latest version of git repo and update the container images"
    echo "uninstall ... Remove all installed docker images and volumes"
    echo
    echo "version | -v | --version ... Show version of the home-automation package"
    echo "help | -h | --help ... Show this help"
    echo "--addAutoCompletion ... adds auto completion for this script to the bash setting. Root permission required!"
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

    # TODO create volume

    log_debug "Create container"
    if ! docker create -p ${NODE_RED_PORT}:1880 --restart unless-stopped --name ${DOCKER_CONTAINER_NODERED} ${DOCKER_IMAGE_NODERED}; then
        echo "Error! Creating node-red docker container failed"
        exit 1
    fi
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

function update_system() {
    log_debug "update_system"
    local container_status=$(get_container_status)

    stop_system
    uninstall_system
    update_repo
    install_system

    if [[ ${container_status} == "running" ]]; then
        start_system
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
    update_node_red_flows
    start_system
}

function get_node_red_files() {
    log_debug "get_node_red_flows"

    # TODO Copy node-red flow files from volume to current dir
}

function update_node_red_files() {
    log_debug "update_node_red_flows"

    # TODO Copy node-red flow files from dir into volume
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

        "scratch")
            echo "Setting up home automation system from scratch to complete running"
            system_from_scratch
            ;;

        "getNodeRedFiles" | "getnoderedfiles")
            echo "Getting NodeRed flows from home automation system"
            get_node_red_files # TODO test
            ;;

        "updateNodeRedFiles" | "updatenoderedfiles")
            echo "Copy NodeRed flows to home automation system"
            confirm_command "update the nodered flows"
            update_node_red_files # TODO test
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
