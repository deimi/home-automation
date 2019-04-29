#!/bin/bash

PACKAGE_VERSION="$(<VERSION)"

function show_help() {
    echo "Home automation system setup script"
    echo "Copyright (c) 2019 Matthias Deimbacher under MIT license"
    echo " "
    echo "Usage:"
    echo "home-automation install ... Build all necessary docker images and volumes"
    echo "home-automation start ... Start the system with all it necessary containers"
    echo "home-automation stop ... Stop the system and all related containers"
    echo "home-automation update ... Get latest version of git repo and update the container images"
    echo "home-automation uninstall ... Remove all installed docker images and volumes"
    echo "home-automation scratch ... Set up a complete home-automation system from scratch to running."
    echo "                            Useful for a \"virgin\" host where the home-automation system was not installed yet"
    echo "home-automation version ... Show version of the home-automation package"
    echo "home-automation help ... Show this help"

}

function show_Version() {
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

function install_system() {

}

function uninstall_system() {

}

function start_system() {

}

function stop_system() {

}

function update_system() {

}

function main() {

    check_dependencies

    case $1 in

        install)
            install_system
            ;;

        start)
            start_system
            ;;

        stop)
            stop_system
            ;;

        update)
            update_system
            ;;

        uninstall)
            uninstall_system
            ;;

        scratch)
            update_system
            install_system
            start_system
            ;;

        version | -version | --version | -v | --v)
            show_version
            exit 0
            ;;

        help | -help | --help | -h | --h)
            show_help
            exit 0
            ;;

        *)
            echo "Unknown home-automation command"
            show_help
            exit 1
            ;;
    esac

    exit 0
}

main "$@"
