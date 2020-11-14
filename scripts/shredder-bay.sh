#!/bin/bash
#
# Regards, The Alveare Solutions society.
#

declare -A DEFAULT
declare -A ERASURE_PATTERNS

CONF_FILE_PATH="$1"
if [ ! -z "$CONF_FILE_PATH" ]; then
    source $CONF_FILE_PATH
fi

# FETCHERS

function fetch_hdd_erasure_pattern_stages_by_label () {
    local LABEL="$1"
    IFS=','
    PATTERN=()
    for pattern in "${ERASURE_PATTERNS[$LABEL]}"; do
        PATTERN=( ${PATTERN[@]} $pattern )
    done
    IFS=' '
    echo ${PATTERN[@]}
    return 0
}

function fetch_ultimatum_from_user () {
    while :
    do
        local ANSWER=`fetch_data_from_user \
            "Are you sure about this? ${YELLOW}Y/N${RESET}"`
        case "$ANSWER" in
            'y' | 'Y' | 'yes' | 'Yes' | 'YES')
                return 0
                ;;
            'n' | 'N' | 'no' | 'No' | 'NO')
                return 1
                ;;
            *)
        esac
    done
    return 2
}

function fetch_selection_from_user () {
    local PROMPT="$1"
    local OPTIONS=( "${@:2}" "Back" )
    local OLD_PS3=$PS3
    PS3="$PROMPT> "
    select opt in "${OPTIONS[@]}"; do
        case $opt in
            'Back')
                PS3="$OLD_PS3"
                return 1
                ;;
            *)
                local CHECK=`check_item_in_set "$opt" "${OPTIONS[@]}"`
                if [ $? -ne 0 ]; then
                    warning_msg "Invalid option."
                    continue
                fi
                PS3="$OLD_PS3"
                echo "$opt"
                return 0
                ;;
        esac
    done
    PS3="$OLD_PS3"
    return 1
}

function fetch_default_hdd_pattern () {
    if [ -z ${DEFAULT['hdd-pattern']} ]; then
        error_msg "No HDD erasure pattern set."
        return 1
    fi
    echo "${DEFAULT['hdd-pattern']}"
    return 0
}

function fetch_default_hdd_erasure_pattern_labels () {
    local LABELS=()
    for label in ${!ERASURE_PATTERNS[@]}; do
        LABELS=( ${LABELS[@]} $label )
    done
    if [ ${#LABELS[@]} -eq 0 ]; then
        error_msg "No HDD erasure pattern labels found."
        return 1
    fi
    echo ${LABELS[@]}
    return 0
}

function fetch_data_from_user () {
    local PROMPT="$1"
    while :
    do
        read -p "$PROMPT> " DATA
        if [ -z "$DATA" ]; then
            continue
        elif [[ "$DATA" == ".back" ]]; then
            return 1
        fi
        echo "$DATA"; break
    done
    return 0
}

function check_device_exists () {
    local DEVICE_PATH="$1"
    fdisk -l $DEVICE_PATH &> /dev/null
    return $?
}

function fetch_device_size () {
    local TARGET_DEVICE="$1"
    check_device_exists $TARGET_DEVICE
    if [ $? -ne 0 ]; then
        warning_msg "Device $TARGET_DEVICE not found."
        return 2
    fi
    local SIZE=`lsblk -bo NAME,SIZE "$TARGET_DEVICE" | \
        grep -e '^[a-z].*' | \
        awk '{print $NF}'`
    if [ -z "$SIZE" ]; then
        return 1
    fi
    echo "$SIZE"
    return 0
}

function fetch_all_available_devices () {
    AVAILABLE_DEVS=(
        `lsblk | \
        grep -e '^[a-z].*' -e 'disk' | \
        awk '{print $1}' | \
        sed 's:^:/dev/:g'`
    )
    if [ ${#AVAILABLE_DEVS[@]} -eq 0 ]; then
        error_msg "Could not detect any devices connected to machine."
        return 1
    fi
    echo "${AVAILABLE_DEVS[@]}"
    return 0
}

# SETTERS

function set_default_hdd_pattern () {
    local PATTERN_LABEL="$1"
    VALID_PATTERNS=( `fetch_default_hdd_erasure_pattern_labels` )
    check_item_in_set "$PATTERN_LABEL" ${VALID_PATTERNS[@]}
    if [ $? -ne 0 ]; then
        error_msg "Invalid HDD erasure pattern label $PATTERN_LABEL."
        return 1
    fi
    echo; info_msg "Setting default HDD erasure pattern \
${YELLOW}$PATTERN_LABEL${RESET} - \
${CYAN}${ERASURE_PATTERNS[$PATTERN_LABEL]}${RESET}"
    DEFAULT['hdd-pattern']="$PATTERN_LABEL"
    return 0
}

function set_default_block_size () {
    local BLOCK_SIZE=$1
    DEFAULT['block-size']=$BLOCK_SIZE
    return 0
}

function set_block_size () {
    info_msg "Type block size for device or ${MAGENTA}.back${RESET}:"
    local BLOCK_SIZE=`fetch_data_from_user 'BlockSize'`
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo; info_msg "Setting default block size to $BLOCK_SIZE."
    set_default_block_size $BLOCK_SIZE
    return $?
}

function set_hdd_erasure_pattern () {
    VALID_PATTERNS=( `fetch_default_hdd_erasure_pattern_labels` )
    if [ $? -ne 0 ]; then
        return 1
    fi
    display_valid_hdd_erasure_pattern_details "${VALID_PATTERNS[@]}"
    PATTERN_LABEL=`fetch_selection_from_user "ErasurePattern" ${VALID_PATTERNS[@]}`
    if [ $? -ne 0 ]; then
        return 1
    fi
    set_default_hdd_pattern "$PATTERN_LABEL"
    return $?
}

function set_safety_off () {
    if [[ "$SHREDDERBAY_SAFETY" == "off" ]]; then
        info_msg "Shredder bay safety is already ${RED}OFF${RESET}."
        return 1
    fi
    while :
    do
        qa_msg "Taking off the training wheels. Are you sure about this?"
        local ANSWER=`fetch_data_from_user 'Y/N'`
        case "$ANSWER" in
            'y'|'Y'|'yes'|'Yes'|'YES')
                SHREDDERBAY_SAFETY='off'
                echo; ok_msg "Safety is ${RED}OFF${RESET}."
                break
                ;;
            'n'|'N'|'no'|'No'|'NO')
                echo; info_msg "Aborting action."
                break
                ;;
            *) warning_msg "Invalid argument ${RED}$ANSWER${RESET}."
                ;;
        esac
    done
    return 0
}

function set_safety_on () {
    if [[ "$SHREDDERBAY_SAFETY" == "on" ]]; then
        info_msg "Shredder bay safety is already ${GREEN}ON${RESET}."
        return 1
    fi
    while :
    do
        qa_msg "Getting scared, are we?"
        local ANSWER=`fetch_data_from_user 'Y/N'`
        case "$ANSWER" in
            'y'|'Y'|'yes'|'Yes'|'YES')
                SHREDDERBAY_SAFETY='on'
                echo; ok_msg "Safety is ${GREEN}ON${RESET}."
                break
                ;;
            'n'|'N'|'no'|'No'|'NO')
                echo; info_msg "Aborting action."
                break
                ;;
            *) warning_msg "Invalid argument ${RED}$ANSWER${RESET}."
                ;;
        esac
    done
    return 0
}

# CHECKERS

function check_item_in_set () {
    local ITEM="$1"
    local ITEM_SET=( "${@:2}" )
    for SET_ITEM in "${ITEM_SET[@]}"; do
        if [[ "$ITEM" == "$SET_ITEM" ]]; then
            return 0
        fi
    done
    return 1
}

function check_valid_directory () {
    local TARGET_DIR="$1"
    if [ ! -d "$TARGET_DIR" ]; then
        return 1
    fi
    return 0
}

function check_valid_file () {
    local TARGET_FILE="$1"
    if [ ! -f "$TARGET_FILE" ]; then
        return 1
    fi
    return 0
}

function check_valid_device () {
    local TARGET_DEV="$1"
    local AVAILABLE_DEVICES=( `fetch_all_available_devices` )
    for AVAILABLE_DEV in "${AVAILABLE_DEVICES[@]}"
    do
        if [[ "$TARGET_DEV" == "$AVAILABLE_DEV" ]]; then
            return 0
        fi
    done
    return 1
}

# GENERAL

# INSTALLERS

function apt_install_dependency() {
    local UTIL="$1"
    symbol_msg "${GREEN}+${RESET}" "Installing package ${YELLOW}$UTIL${RESET}..."
    apt-get install $UTIL
    return $?
}

function apt_install_shredderbay_dependencies () {
    if [ ${#APT_DEPENDENCIES[@]} -eq 0 ]; then
        info_msg 'No dependencies to fetch using the apt package manager.'
        return 1
    fi
    info_msg "Installing dependencies using apt package manager:"
    for package in "${APT_DEPENDENCIES[@]}"; do
        apt_install_dependency $package
        if [ $? -ne 0 ]; then
            nok_msg "Failed to install $SCRIPT_NAME dependency ${RED}$package${RESET}!"
        else
            ok_msg "Successfully installed $SCRIPT_NAME dependency ${GREEN}$package${RESET}."
        fi
    done
    return 0
}

function install_shredderbay_dependencies () {
    if [[ "$SHREDDERBAY_SAFETY" == "on" ]]; then
        warning_msg "Shredder safety is ${GREEN}ON${RESET}. \
${RED}ShredderBay${RESET} dependencies are not beeing installed."
        return 1
    else
        ANSWER=`fetch_ultimatum_from_user`
        if [ $? -ne 0 ]; then
            echo; info_msg "Aborting action."
            return 1
        fi
        echo; apt_install_shredderbay_dependencies
    fi
    local EXIT_CODE=$?
    if [ $EXIT_CODE -ne 0 ]; then
        nok_msg "Software failure! \
Could not install ${RED}ShredderBay${RESET} dependencies."
        return 1
    else
        ok_msg "${GREEN}ShredderBay${RESET} \
dependencies successfully installed."
    fi
    return $EXIT_CODE
}

# SHREDDERS

function fetch_file_size_in_bytes () {
    local FILE_PATH="$1"
    BYTES=`ls -la "$FILE_PATH" | awk '{print $5}'`
    echo $BYTES
    return 0
}

function remove_file () {
    local FILE_PATH="$1"
    if [ ! -f $FILE_PATH ]; then
        error_msg "No file found at $FILE_PATH."
        return 1
    fi
    rm $FILE_PATH
    return $?
}

function truncate_file_to_size () {
    local FILE_PATH="$1"
    local SIZE=$2
    truncate --size=$SIZE $FILE_PATH &> /dev/null
    return $?
}

function shred_device_stage_custom () {
    local TARGET_DEV="$1"
    local DEV_SIZE="$2"
    local BLOCKS="$3"
    local MESSAGE_PREFIX="Erasure Pattern Stage - \
${YELLOW}$SHREDDERBAY_ERASURE_PATTERN${RESET} -"
    if [[ "$SHREDDERBAY_SAFETY" == "on" ]]; then
        warning_msg "Shredder safety is ${GREEN}ON${RESET}. \
Device ${YELLOW}$TARGET_DEV${RESET} is not beeing shredded."
    else
        yes "$SHREDDERBAY_ERASURE_PATTERN" | \
            dd  bs=${DEFAULT['block-size']} count=$BLOCKS | \
            pv -ptebar --size $DEV_SIZE | \
            dd of=$TARGET_DEV bs=${DEFAULT['block-size']} count=$BLOCKS
    fi
    if [ $? -ne 0 ]; then
        nok_msg "$MESSAGE_PREFIX Software failure! \
Could not shred device ${RED}$TARGET_DEV${RESET}.
        "
        return 1
    else
        ok_msg "$MESSAGE_PREFIX \
Device ${GREEN}$TARGET_DEV${RESET} successfully shredded.
        "
    fi
    return 0
}

function shred_directory () {
    local TARGET_DIR="$1"
    if [[ "$SHREDDERBAY_SAFETY" == "on" ]]; then
        warning_msg "Shredder safety is ${GREEN}ON${RESET}. \
File ${YELLOW}$TARGET_FILE${RESET} is not beeing shredded."
    else
        find "$TARGET_DIR" -type f | xargs shred f -n 10 -z -u &> /dev/null
        rm -rf "$TARGET_DIR" &> /dev/null
        return $?
    fi
    return 1
}

function shred_file () {
    local TARGET_FILE="$1"
    if [[ "$SHREDDERBAY_SAFETY" == "on" ]]; then
        warning_msg "Shredder safety is ${GREEN}ON${RESET}. \
File ${YELLOW}$TARGET_FILE${RESET} is not beeing shredded."
    else
        shred -f -n 10 -z -u "$TARGET_FILE" &> /dev/null
        return $?
    fi
    return 1
}

function shred_device_stage_zero () {
    local TARGET_DEV="$1"
    local DEV_SIZE="$2"
    local BLOCKS="$3"
    if [[ "$SHREDDERBAY_SAFETY" == "on" ]]; then
        warning_msg "Shredder safety is ${GREEN}ON${RESET}. \
Device ${YELLOW}$TARGET_DEV${RESET} is not beeing shredded."
    else
        dd if=/dev/zero bs=${DEFAULT['block-size']} count=$BLOCKS | \
            pv -ptebar --size $DEV_SIZE | \
            dd of="$TARGET_DEV" bs=${DEFAULT['block-size']} count=$BLOCKS
    fi
    local EXIT_CODE=$?
    local MESSAGE_PREFIX="Erasure Pattern Stage - ${YELLOW}Zero${RESET} -"
    if [ $EXIT_CODE -ne 0 ]; then
        nok_msg "$MESSAGE_PREFIX Software failure! \
Could not shred device ${RED}$TARGET_DEV${RESET}.
        "
    else
        ok_msg "$MESSAGE_PREFIX \
Device ${GREEN}$TARGET_DEV${RESET} successfully shredded.
        "
    fi
    return $EXIT_CODE
}

function shred_device_stage_random () {
    local TARGET_DEV="$1"
    local DEV_SIZE="$2"
    local BLOCKS="$3"
    if [[ "$SHREDDERBAY_SAFETY" == "on" ]]; then
        warning_msg "Shredder safety is ${GREEN}ON${RESET}. \
Device ${YELLOW}$TARGET_DEV${RESET} is not beeing shredded."
    else
        dd if=/dev/random bs=${DEFAULT['block-size']} count=$BLOCKS | \
            pv -ptebar --size $DEV_SIZE | \
            dd of="$TARGET_DEV" bs=${DEFAULT['block-size']} count=$BLOCKS
    fi
    local EXIT_CODE=$?
    local MESSAGE_PREFIX="Erasure Pattern Stage - ${YELLOW}Random${RESET} -"
    if [ $EXIT_CODE -ne 0 ]; then
        nok_msg "$MESSAGE_PREFIX Software failure! \
Could not shred device ${RED}$TARGET_DEV${RESET}.
        "
    else
        ok_msg "$MESSAGE_PREFIX \
Device ${GREEN}$TARGET_DEV${RESET} successfully shredded.
        "
    fi
    return $EXIT_CODE
}

function shred_device () {
    local TARGET_DEV="$1"
    local DEV_SIZE=`fetch_device_size "$TARGET_DEV"`
    BLOCKS="$((DEV_SIZE / ${DEFAULT['block-size']}))"
    local PATTERN_LABEL="`fetch_default_hdd_pattern`"
    PATTERN_STAGES=(
        `fetch_hdd_erasure_pattern_stages_by_label "$PATTERN_LABEL"`
    )
    info_msg "This may really take a while, \
do something cool in the mean time ;)."
    local total_count=0
    local failure_count=0
    for stage in "${PATTERN_STAGES[@]}"; do
        local total_count=$((total_count + 1))
        case "$stage" in
            'zero')
                info_msg "Initiated ${MAGENTA}Zero${RESET} bit device shredder: \
iteration ${WHITE}$total_count/${#PATTERN_STAGES[@]}${RESET}, \
device ${YELLOW}$TARGET_DEV${RESET}, \
capacity ${YELLOW}$DEV_SIZE bytes${RESET}, \
block size ${YELLOW}${DEFAULT['block-size']} bytes${RESET}, \
block count ${YELLOW}$BLOCKS${RESET}."
                shred_device_stage_zero $TARGET_DEV $DEV_SIZE $BLOCKS
                ;;
            'random')
                info_msg "Initiated ${MAGENTA}Random${RESET} bit device shredder: \
iteration ${WHITE}$total_count/${#PATTERN_STAGES[@]}${RESET}, \
device ${YELLOW}$TARGET_DEV${RESET}, \
capacity ${YELLOW}$DEV_SIZE bytes${RESET}, \
block size ${YELLOW}${DEFAULT['block-size']} bytes${RESET}, \
block count ${YELLOW}$BLOCKS${RESET}."
                shred_device_stage_random $TARGET_DEV $DEV_SIZE $BLOCKS
                ;;
            "$SHREDDERBAY_ERASURE_PATTERN")
                info_msg "Initiated ${MAGENTA}$SHREDDERBAY_ERASURE_PATTERN${RESET} device shredder: \
iteration ${WHITE}$total_count/${#PATTERN_STAGES[@]}${RESET}, \
device ${YELLOW}$TARGET_DEV${RESET}, \
capacity ${YELLOW}$DEV_SIZE bytes${RESET}, \
block size ${YELLOW}${DEFAULT['block-size']} bytes${RESET}, \
block count ${YELLOW}$BLOCKS${RESET}."
                shred_device_stage_custom $TARGET_DEV $DEV_SIZE $BLOCKS
                ;;
            *)
                error_msg "Invalid pattern stage ${RED}$stage${RESET}.";
                continue
        esac
        if [ $? -ne 0 ]; then
            local failure_count=$((failure_count + 1))
        fi
    done
    info_msg "Completed ${WHITE}$total_count${RESET} \
HDD erasure pattern iterations, ${RED}$failure_count${RESET} failures."
    return 0
}

# ACTIONS

function shredderbay_control_panel () {
    local OPTIONS=(
        "Set ${RED}Safety OFF${RESET}"
        "Set ${GREEN}Safety ON${RESET}"
        "Set Block Size"
        "Set HDD Erasure Pattern"
        "Install ShredderBay Dependencies"
        "Back"
    )
    select opt in "${OPTIONS[@]}"
    do
        case "$opt" in
            "Set ${RED}Safety OFF${RESET}")
                echo; set_safety_off
                break
                ;;
            "Set ${GREEN}Safety ON${RESET}")
                echo; set_safety_on
                break
                ;;
            'Set Block Size')
                echo; set_block_size
                break
                ;;
            'Set HDD Erasure Pattern')
                echo; set_hdd_erasure_pattern
                break
                ;;
            'Install ShredderBay Dependencies')
                echo; install_shredderbay_dependencies
                break
                ;;
            'Back')
                return 1
                ;;
            *) echo; warning_msg "Invalid option."
                ;;
        esac
    done
    return 0
}

function action_access_shredderbay_control_panel () {
    echo "
[ ${BLUE}$SCRIPT_NAME${RESET} ]: ${CYAN}Control Panel${RESET}

[ ${YELLOW}INFO${RESET} ]: ShredderBay safety is $SHREDDERBAY_SAFETY."
    while :
    do
        display_shredderbay_settings
        shredderbay_control_panel
        if [ $? -ne 0 ]; then
            return 1
        fi
    done
    return 0
}

function action_shred_directory () {
    LOCAL target_dir="$1"
    CHECK=`check_valid_directory "$TARGET_DIR"`
    if [ $? -ne 0 ]; then
        error_msg "Invalid directory path ${RED}$TARGET_DIR${RESET}."
        return 1
    fi
    shred_directory "$TARGET_DIR"
    if [ -d "$TARGET_DIR" ]; then
        nok_msg "Something went wrong. \
Could not shred directory ${RED}$TARGET_DIR${RESET}."
        info_msg "You could check user and group permissions."
        return 1
    fi
    ok_msg "${GREEN}$TARGET_DIR${RESET} directory successfully shredded."
    return 0
}

function action_shred_file () {
    local TARGET_FILE="$1"
    CHECK=`check_valid_file "$TARGET_FILE"`
    if [ $? -ne 0 ]; then
        error_msg "Invalid file path ${RED}$TARGET_FILE${RESET}."
        return 1
    fi
    shred_file "$TARGET_FILE"
    if [ -f $TARGET_FILE ]; then
        nok_msg "Something went wrong. \
Could not shred file ${RED}$TARGET_DIR${RESET}."
        info_msg "You could check user and group permissions."
        return 1
    fi
    ok_msg "File ${GREEN}$TARGET_FILE${RESET} successfully shredded."
    return 0
}

function action_shred_device () {
    local TARGET_DEV="$1"
    CHECK=`check_valid_device "$TARGET_DEV"`
    if [ $? -ne 0 ]; then
        error_msg "Invalid device ${RED}$TARGET_DEV${RESET}."
        return 1
    fi
    shred_device "$TARGET_DEV"
    done_msg "Operation complete."
    return 0
}

# HANDLERS

function handle_action_shred_file () {
    echo; info_msg "Type absolute file path or ${MAGENTA}.back${RESET}."
    FILE_PATH=`fetch_data_from_user "FilePath"`
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo; action_shred_file "$FILE_PATH"
    return 0
}

function handle_action_shred_directory () {
    echo; info_msg "Type absolute directory path or ${MAGENTA}.back${RESET}."
    DIR_PATH=`fetch_data_from_user "DirPath"`
    if [ $? -ne 0 ]; then
        return 1
    fi
    echo; action_shred_directory "$DIR_PATH"
    return 0
}

function check_device_exists () {
    local DEVICE_PATH="$1"
    lsblk $DEVICE_PATH &> /dev/null
    if [ $? -ne 0 ]; then
        return 1
    else
        return 0
    fi
    return 2
}

function handle_action_shred_device () {
    display_block_devices
    info_msg "Type absolute device path or ${MAGENTA}.back${RESET}."
    DEV_PATH=`fetch_data_from_user "DevPath"`
    if [ $? -ne 0 ]; then
        return 1
    fi
    check_device_exists "$DEV_PATH"
    if [ $? -ne 0 ]; then
        echo; error_msg "Device ${RED}$DEV_PATH${RESET} not found."
        return 2
    fi
    echo; action_shred_device "$DEV_PATH"
    return 0
}

function handle_action_access_control_panel () {
    action_access_shredderbay_control_panel
}

# CONTROLLERS

function shredder_bay_main_controller () {
    echo "
[ ${BLUE}$SCRIPT_NAME${RESET} ]: ${CYAN}Disturbing Places Teeth Can Grow${RESET}
    "
    local OPTIONS=(
        'Shred File'
        'Shred Directory'
        'Shred Device'
        'Control Panel'
        'Back'
    )
    select opt in "${OPTIONS[@]}"
    do
        case "$opt" in
            'Shred File')
                handle_action_shred_file
                break
                ;;
            'Shred Directory')
                handle_action_shred_directory
                break
                ;;
            'Shred Device')
                handle_action_shred_device
                break
                ;;
            'Control Panel')
                handle_action_access_control_panel
                break
                ;;
            'Back')
                clear; ok_msg 'Terminating ShredderBay.'; exit 0
                ;;
            *) warning_msg "Invalid option."
                ;;
        esac
    done
    return 0
}

function shredder_bay_init () {
    while :
    do
        shredder_bay_main_controller
    done
}

# DISPLAY

function display_block_devices () {
    echo; echo -n "${CYAN}DEVICE${RESET}" && \
        echo ${CYAN}`lsblk | grep -e MOUNTPOINT`${RESET} && \
        lsblk | grep -e disk | sed 's/^/\/dev\//g'
    EXIT_CODE=$?
    echo
    return $EXIT_CODE
}

function display_valid_hdd_erasure_pattern_details () {
    VALID_PATTERNS=( "${@}" )
    echo "[ ${BLUE}$SCRIPT_NAME${RESET} ]: ${CYAN}HDD Erasure Patterns${RESET}
    "
    local COUNT=1
    for pattern in "${VALID_PATTERNS[@]}"; do
        echo "${WHITE}$COUNT${RESET}) ${YELLOW}$pattern${RESET} - \
${CYAN}${ERASURE_PATTERNS[$pattern]}${RESET}"
        local COUNT=$((COUNT + 1))
    done
    echo; return 0
}

function display_shredderbay_settings () {
    case $SHREDDERBAY_SAFETY in
        'on')
            local DISPLAY_SAFETY="${GREEN}$SHREDDERBAY_SAFETY${RESET}"
            ;;
        'off')
            local DISPLAY_SAFETY="${RED}$SHREDDERBAY_SAFETY${RESET}"
            ;;
        *)
            local DISPLAY_SAFETY=$SHREDDERBAY_SAFETY
            ;;
    esac
    echo "
[ ${CYAN}Block Size${RESET}          ]: ${WHITE}${DEFAULT['block-size']}${RESET}
[ ${CYAN}HDD Erasure Pattern${RESET} ]: ${DEFAULT['hdd-pattern']}
[ ${CYAN}Safety${RESET}              ]: $DISPLAY_SAFETY
"
    return 0
}

function done_msg () {
    local MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${CYAN}DONE${RESET} ]: $MSG"
    return 0
}

function ok_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${GREEN}OK${RESET} ]: $MSG"
    return 0
}

function nok_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${RED}NOK${RESET} ]: $MSG"
    return 0
}

function qa_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${YELLOW}Q/A${RESET} ]: $MSG"
    return 0
}

function info_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${YELLOW}INFO${RESET} ]: $MSG"
    return 0
}

function error_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${RED}ERROR${RESET} ]: $MSG"
    return 0
}

function warning_msg () {
    MSG="$@"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ ${RED}WARNING${RESET} ]: $MSG"
    return 0
}

function symbol_msg () {
    SYMBOL="$1"
    MSG="${@:2}"
    if [ -z "$MSG" ]; then
        return 1
    fi
    echo "[ $SYMBOL ]: $MSG"
    return 0
}

if [ $EUID -ne 0 ]; then
    echo
    warning_msg "ShredderBay requires elevated privileges, \
current EUID is ${RED}$EUID${RESET}."
    echo; exit 1
fi

shredder_bay_init

