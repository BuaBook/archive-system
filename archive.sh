#!/usr/bin/env bash

# BuaBook Archive System
# Copyright (C) Sport Trades Ltd
# 2016

readonly PROGNAME=$(basename $0)
readonly PROGDIR=$(readlink -m $(dirname $0))

readonly SOURCE_CONFIG=${BAS_CONFIG}/$(hostname)/archive.config
readonly TARGET_CONFIG=${BAS_CONFIG}/$(hostname)/archive.target

readonly RSYNC_OPTIONS="--archive --ipv4 --compress --verbose --copy-links --progress --relative --keep-dirlinks"

source ${PROGDIR}/bash-helpers/src/bash-helpers.sh
set +e

main()
{
    logInfo "\n**************************************"
    logInfo   "****    BUABOOK ARCHIVE SYSTEM    ****"
    logInfo   "**************************************\n"

    if [[ ! -f $SOURCE_CONFIG ]]; then
        logError "\nERROR: Source configuration file could not be found"
        logError "\tExpecting it @ $SOURCE_CONFIG"
        exit 1
    fi

    if [[ ! -f $TARGET_CONFIG ]]; then
        logError "\nERROR: Target configuration file could not be found"
        logError "\tExpecting it @ $TARGET_CONFIG"
        exit 2
    fi

    local sourceConfig=($(loadConfigFile $SOURCE_CONFIG))
    local targetConfig=($(loadConfigFile $TARGET_CONFIG))

    local singleTarget=${targetConfig[0]}

    if [[ "" == $singleTarget ]]; then
        logError "\nERROR: No target configuration specified"
        logError "\tEnsure target configuration is set in $TARGET_CONFIG"
        exit 3
    fi

    logInfo " * rsync Options:\t$RSYNC_OPTIONS\n"

    for sourceRow in "${sourceConfig[@]}"; do
        archiveSourceRow $sourceRow $singleTarget

        local archiveResult=$(echo $?)

        if [[ $archiveResult -ne 0 ]]; then
            logError "\nERROR: Previous archive attempt failed. Continuing...\n"
        fi
    done

    logInfo "\nARCHIVE COMPLETE\n"

}

archiveSourceRow()
{
    
    export IFS=","
    local sourceInfo=($1)
    local targetConfig=($2)
    unset IFS

    local configSourceFilePath=${sourceInfo[0]}
    local archiveCount=${sourceInfo[1]}
    local archiveFreq=${sourceInfo[2]}
    local shouldDelete=${sourceInfo[3]}

    local partialDate=$(getPreviousPartialDate $archiveCount $archiveFreq)
    local sourceFilePath=${configSourceFilePath/\{BBDATE\}/${partialDate}}*

    local targetLocalRemote=${targetConfig[0]}
    local target=${targetConfig[1]}

    local anyFilesMatch=$(find $sourceFilePath > /dev/null 2>&1; echo $?)

    logInfo "\n * [ $(date) ] Process start"
    logInfo "\t - Source:\t$sourceFilePath"
    logInfo "\t - Target:\t$target (${targetLocalRemote})" 
    logInfo "\t - Lookback:\t${archiveCount} ${archiveFreq}"
    logInfo "\t - Type:\t$shouldDelete\n"

    if [[ $anyFilesMatch -ne 0 ]]; then
        logInfo " * [ $(date) ] No archive required (no files match)"
        return 0
    fi

    if [[ "delete-only" == $shouldDelete ]]; then
        logInfo " * [ $(date) ] WARN: No archiving configured"
    else
        logInfo " * [ $(date) ] Starting archive\n"
        rsync $RSYNC_OPTIONS $sourceFilePath $target

        local archiveResult=$(echo $?)

        if [[ $archiveResult -ne 0 ]]; then
            logError " * [ $(date) ] ERROR: Archived failed. Aborting..."
            return 1
        fi

        logInfo "\n * [ $(date) ] Archive complete"
    fi

    if [[ "delete-only" == $shouldDelete ]] || [[ "archive-delete" == $shouldDelete ]]; then
        logInfo " * [ $(date) ] Deleting archived files\n"
        rm -v $sourceFilePath
        logInfo "\n * [ $(date) ] Deletion complete"
    fi

    logInfo " * [ $(date) ] Process complete"

    return 0
}

main
