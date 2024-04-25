#!/bin/bash
#================================================================
# HEADER
#================================================================
#% SYNOPSIS
#+    ${SCRIPT_NAME} [-hv]
#+    Example: ${SCRIPT_NAME}
#%
#% DESCRIPTION
#%    This is a script for the automated installation, upgrade,
#%    and uninstall of the dockerized Pen Aviation comm switching
#%    software on a Ubuntu / Debian ARM Linux distro.
#%
#% OPTIONS
#%    -h, --help                    Print this help
#%    -v, --version                 Print script information
#%
#% ARGUMENTS
#%    None
#%
#% EXAMPLES
#%    ${SCRIPT_NAME}
#%    ${SCRIPT_NAME} --help
#%
#================================================================
#- IMPLEMENTATION
#-    version         ${SCRIPT_NAME} ${SCRIPT_VERSION}
#-    author          Alexandros M. Kardaris <alexandros@protaso.nl>
#-    copyright       Copyright (c) https://www.protaso.nl
#-    license         Proprietary Commercial Software License
#-    script_id       PA001
#-
#================================================================
#  HISTORY
#     2024-01-05 : Script creation
#     2024-04-17 : Updating stable version tag
#
#================================================================
#  DEBUG OPTION
#    set -n  # Uncomment to check your syntax, without execution.
#    set -x  # Uncomment to debug this shell script
#
#================================================================
# END_OF_HEADER
#================================================================

########## Global Variables ##########

TAG_STABLE="protasobv/penaviation-scs:0.7.1"
TAG_LATEST="protasobv/penaviation-scs:latest"
CONF_ISBD="https://raw.githubusercontent.com/protasobv/penaviation-scs/main/isbd.conf"
CONF_NAVROUTER="https://raw.githubusercontent.com/protasobv/penaviation-scs/main/navrouter.conf"

########## Head and Usage Functions ###########

SCRIPT_HEADSIZE=$(head -200 ${0} |grep -n "^# END_OF_HEADER" | cut -f1 -d:)
SCRIPT_NAME="$(basename ${0})"
SCRIPT_VERSION="1.0.0"

usage( )
{
    printf "Usage  : "
    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#+" | sed -e "s/^#+[ ]*//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" -e "s/\${SCRIPT_VERSION}/${SCRIPT_VERSION}/g"
    printf "\nTry '${SCRIPT_NAME} --help' for more information.\n"
    return 0
}

usagefull( )
{
    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#[%+-]" | sed -e "s/^#[%+-]//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" -e "s/\${SCRIPT_VERSION}/${SCRIPT_VERSION}/g"
    return 0
}

scriptinfo( )
{
    head -${SCRIPT_HEADSIZE:-99} ${0} | grep -e "^#-" | sed -e "s/^#-//g" -e "s/\${SCRIPT_NAME}/${SCRIPT_NAME}/g" -e "s/\${SCRIPT_VERSION}/${SCRIPT_VERSION}/g"
    return 0
}

########## Functions ##########

initialize( )
{
    # Basic configuration
    clear

    # Define output colors
    readonly RED='\033[0;31m'
    readonly CYAN='\033[0;36m'
    readonly NC='\033[0m'

    menu

    return ${?}
}

menu( )
{
    local option=100
    while [ ${option} -ne 0 ]; do
        echo -e "${CYAN}Please select one of the following tasks:${NC}"
        echo -e "  1. Install and run software"
        echo -e "  2. Update software"
        echo -e "  3. Uninstall software"
        echo -e " "
        echo -e "  0. Exit"
        echo -e " "

        read -p "Enter a number: " option
        if [ -z "${option}" ]; then                                                         # Option variable is empty
                echo -e "${RED}Invalid option. Please try again...${NC}"
                echo -e " "
                option=100
        fi
        if ! [[ ${option} =~ ^[-+]?[0-9]+$ ]]; then                                         # Option variable is not a number
                echo -e "${RED}Invalid option. Please try again...${NC}"
                echo -e " "
                option=100
        fi

        clear

        if [ ${option} -eq 0 ]; then
            clear
            return 0
        elif [ ${option} -eq 1 ]; then
            installing
            return ${?}
        elif [ ${option} -eq 2 ]; then
            updating
            return ${?}
        elif [ ${option} -eq 3 ]; then
            uninstalling
            return ${?}
        else
            echo -e "${RED}Invalid option. Please try again...${NC}"
            echo -e " "
        fi
    done

    return 0
}

installing( )
{
    echo -e "[INFO] ${CYAN}Software installation proccess started...${NC}\t\t\t$(date)"

    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        echo -e "[WARN] ${CYAN}Docker is already installed. Skipping step...${NC}"
    else
        # Install Docker
        echo -e "[INFO] ${CYAN}Docker not found. Installing Docker...${NC}"
        sudo apt-get update
        sudo apt-get install -y docker.io

	if [ ${?} -eq 0 ]; then
            echo -e "[INFO] ${CYAN}Docker has been installed successfully!${NC}\t\t\t\t$(date)"
        else
            echo -e "[FAIL] ${RED}Failed installing Docker via Ubuntu package manager. Exiting now..${NC}"
            return 1
        fi

        # Add the current user to the docker group to avoid using sudo for docker commands
        sudo usermod -aG docker $USER
    fi

    # Pull Docker software image from repository
    echo -e "[INFO] ${CYAN}Retrieving Docker software image from repository...${NC}"
    sudo docker pull ${TAG_STABLE}
    if [ ${?} -eq 0 ]; then
        echo -e "[INFO] ${CYAN}Docker software image download completed!${NC}"
    else
        echo -e "[FAIL] ${RED}Failed downloading Docker software image from repository. Exiting now..${NC}"
        return 2
    fi

    # Install and make the required configuration files and directories
    sudo mkdir -p /data
    sudo touch /data/navrouter.log

    sudo curl -o /data/isbd.conf ${CONF_ISBD}
    if [ $? -eq 0 ]; then
        echo -e "[INFO] ${CYAN}Configuartion file isbd.conf retrieved successfully.${NC}"
    else
        echo -e "[FAIL] ${RED}Failed to retrieve configuration file isbd.conf file. Exiting now...${NC}"
        sudo rm -rf /data
        return 3
    fi

    sudo curl -o /data/navrouter.conf ${CONF_NAVROUTER}
    if [ $? -eq 0 ]; then
        echo -e "[INFO] ${CYAN}Configuartion file navrouter.conf retrieved successfully.${NC}"
    else
        echo -e "[FAIL] ${RED}Failed to retrieve configuration file navrouter.conf file. Exiting now...${NC}"
        sudo rm -rf /data
        return 4
    fi

    # Iridium SBD
    sudo chmod +666 /dev/ttyUSB0

    # AutoPilot connected via USB
    sudo chmod +666 /dev/ttyACM0

    # AutoPilot connected via serial line
    sudo chmod +666 /dev/ttyS0

    echo -e "[INFO] ${CYAN}Software installation proccess completed successfully.${NC}\t\t$(date)"

    echo -e "[INFO] ${CYAN}Run the software image container via Docker...${NC}\t\t\t$(date)"
    sudo docker run -d --rm --privileged \
        -p 5770:5770/tcp -p 14500:14500/udp -p 14600:14600/udp \
        -e DISPLAY=${DISPLAY} \
        --device=/dev/ttyUSB0:/dev/ttyUSB0 \
        --device=/dev/ttyACM0:/dev/ttyACM0 \
        -v ${HOME}/.Xauthority:/root/.Xauthority:rw \
        -v /tmp/.X11-unix/:/tmp/.X11-unix \
        -v /data/isbd.conf:/mavlink-splitter/examples/isbd.conf:rw \
        -v /data/navrouter.conf:/navlink/navrouter.conf:rw \
        -v /data/navrouter.log:/navlink/navrouter.log:rw \
        -v /data:/data \
        --mount type=bind,source=/data/isbd.conf,target=/mavlink-splitter/examples/isbd.conf:rw \
        --mount type=bind,source=/data/navrouter.conf,target=/navlink/navrouter.conf:rw \
        --mount type=bind,source=/data/navrouter.log,target=/navlink/navrouter.log:rw \
        --name=penaviation-scs ${TAG_STABLE} \
        bash -c "./mavlink-splitter/build/src/mavlink-routerd -c mavlink-splitter/examples/isbd.conf & sleep 5 && python3 ./navlink/navlink.py"

    echo -e "[INFO] ${CYAN}Software instalation and execution process completed.${NC}\t\t$(date)"
    return 0
}

updating( )
{
    echo -e "${CYAN}Software update proccess started...${NC}\t\t\t$(date)"

    # Stopping any running software image containers
    echo -e "[INFO] ${CYAN}Stopping any running software image containers...${NC}"
    sudo docker stop penaviation-scs

    # Pull Docker software image from repository
    echo -e "[INFO] ${CYAN}Retrieving latest Docker software image from repository...${NC}"
    sudo docker pull ${TAG_LATEST}
    if [ ${?} -eq 0 ]; then
        echo -e "[INFO] ${CYAN}Latest Docker software image download completed!${NC}"
    else
        echo -e "[FAIL] ${RED}Failed downloading latest Docker software image from repository. Exiting now..${NC}"
        return 5
    fi

    echo -e "[INFO] ${CYAN}Run the software image container via Docker...${NC}\t\t\t$(date)"
    sudo docker run -d --rm --privileged \
        -p 5770:5770/tcp -p 14500:14500/udp -p 14600:14600/udp \
        -e DISPLAY=${DISPLAY} \
        --device=/dev/ttyUSB0:/dev/ttyUSB0 \
        --device=/dev/ttyACM0:/dev/ttyACM0 \
        -v ${HOME}/.Xauthority:/root/.Xauthority:rw \
        -v /tmp/.X11-unix/:/tmp/.X11-unix \
        -v /data/isbd.conf:/mavlink-splitter/examples/isbd.conf:rw \
        -v /data/navrouter.conf:/navlink/navrouter.conf:rw \
        -v /data/navrouter.log:/navlink/navrouter.log:rw \
        -v /data:/data \
        --mount type=bind,source=/data/isbd.conf,target=/mavlink-splitter/examples/isbd.conf:rw \
        --mount type=bind,source=/data/navrouter.conf,target=/navlink/navrouter.conf:rw \
        --mount type=bind,source=/data/navrouter.log,target=/navlink/navrouter.log:rw \
        --name=penaviation-scs ${TAG_LATEST} \
        bash -c "./mavlink-splitter/build/src/mavlink-routerd -c mavlink-splitter/examples/isbd.conf & sleep 5 && python3 ./navlink/navlink.py"

    # Deleting Docker leftover images of the software
    echo -e "[INFO] ${CYAN}Deleting any leftover Docker images of the software...${NC}"
    sudo docker image rm ${TAG_STABLE}

    echo -e "${CYAN}Software update proccess completed successfully.${NC}\t$(date)"
    return 0
}

uninstalling( )
{
    echo -e "${CYAN}Software removal proccess started...${NC}\t\t\t$(date)"

    # Stopping any running software image containers
    echo -e "[INFO] ${CYAN}Stopping any running software image containers...${NC}"
    sudo docker stop penaviation-scs

    # Deleting Docker leftover images of the software
    echo -e "[INFO] ${CYAN}Deleting any leftover Docker images of the software...${NC}"
    sudo docker image rm ${TAG_STABLE}
    sudo docker image rm ${TAG_LATEST}

    # Deleting the /data directory
    echo -e "[INFO] ${CYAN}Deleting the /data directory...${NC}"
    sudo rm -rf /data

    echo -e "${CYAN}Software removal proccess completed successfully.${NC}\t$(date)"
    return 0
}

########## Main bash script ##########

if [ $(id -u) -ne 0 ]
then
    echo "This program should only be run as user root."
    exit 1
fi

if [ "X${1}X" = "X-hX" ] || [ "X${1}X" = "X--helpX" ]; then
    usagefull
    exit 0
elif [ "X${1}X" = "X-vX" ] || [ "X${1}X" = "X--versionX" ]; then
    scriptinfo
    exit 0
fi

# Check if lsb_release command is available
if ! command -v lsb_release &> /dev/null; then
    echo "lsb_release command not found. Exiting."
    exit 1
fi

# Check if the Linux distribution is Ubuntu or Debian
if [ "$(lsb_release -si)" != "Ubuntu" && "$(lsb_release -si)" != "Debian"]; then
    echo "This script is intended for Ubuntu or Debian only. Exiting."
    exit 1
fi

initialize
if [ ${?} -ne 0 ]; then
  echo -e "${RED}Playbook application had some errors.${NC}"
  exit ${?}
else
  exit 0
fi
