#!/bin/bash

PACKAGE_VERSION="$(<VERSION)"

function show_help() {
    echo "Home automation system setup script"
    echo "Copyright (c) 2019 Matthias Deimbacher under MIT license"
    echo
    echo "Usage:"
    echo "$0 {install|start|stop|update|uninstall|scratch|getNodeRedFlows|version|help}"
    echo
    echo "install ... Build all necessary docker images and volumes"
    echo "start ... Start the system with all it necessary containers"
    echo "stop ... Stop the system and all related containers"
    echo "update ... Get latest version of git repo and update the container images"
    echo "uninstall ... Remove all installed docker images and volumes"
    echo "scratch ... Set up a complete home-automation system from scratch to running."
    echo "            Useful for a \"virgin\" host where the home-automation system was not installed yet"
    echo "getNodeRedFlows ... Copies NodeRed flows from the container to the current path"
    echo "                    Useful during developing the flows itself"
    echo "version | -v | --version ... Show version of the home-automation package"
    echo "help | -h | --help ... Show this help"

}

function show_version() {
    echo $PACKAGE_VERSION
}

function check_dependencies() {
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
    uname_os=$(uname -o)

    case $uname_os in
        "Msys")
            echo "Win"
            ;;

        "GNU/Linux")
            echo "Linux"
            ;;

        *)
            echo $uname_os
            ;;
    esac
}

function detect_arch() {
    uname_arch=$(uname -m)

    case $uname_arch in
        "x86_64")
            echo "amd64"
            ;;

        "arm")
            echo "arm"
            ;;

        *)
            echo $uname_arch
            ;;
    esac
}

function check_host_supported() {

    detected_os=$(detect_os)
    detected_arch=$(detect_arch)

    case $detected_os in
        "Win")
            echo "Error! Windows OS not supported"
            exit 1
            ;;

        "Linux")
            #  all fine
            ;;

        *)
            echo "Error! Unsupported host OS: $detected_os"
            exit 1
            ;;
    esac

    case $detected_arch in
        "arm" | "amd64")
            # all fine
            ;;

        *)
            echo "Error! Unsupported host architecture: $detected_arch"
            exit 1
            ;;
    esac
}

# function install_system() {
#     # Build docker file

#     # Create volume

#     # Create container

#     # Copy NodeRed flows
# }

# function uninstall_system() {
#     # Stop container

#     # Remove container

#     # Purge image and config files

# }

# function start_system() {
#     # start container
# }

# function stop_system() {
#     # stop container
# }

# function update_system() {
#     # stop container
#     # delete image

# }

# function getNodeRedFlows() {

# }

function main() {

    check_host_supported
    check_dependencies

    case $1 in

        "install")
            install_system
            ;;

        "start")
            start_system
            ;;

        "stop")
            stop_system
            ;;

        "update")
            update_system
            ;;

        "uninstall")
            uninstall_system
            ;;

        "scratch")
            update_system
            install_system
            start_system
            ;;

        "getNodeRedFlows" | "getnoderedflows")
            get_node_red_flows
            ;;

        "version" | "-v" | "--version")
            show_version
            ;;

        "help" | "-h" | "-?" | "--help")
            show_help
            ;;

        "")
            echo "ERROR! Missing command"
            echo
            show_help
            exit 1
            ;;

        *)
            echo "ERROR! Unknown command: $1"
            echo
            show_help
            exit 1
            ;;
    esac

    exit 0
}

main "$@"
