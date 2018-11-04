#!/bin/bash

set -e

session=mc-server
server_user=mc
server_path=/home/mc/minecraft_server
server_start_cmd="java -Xms1G -Xmx1G -jar server.jar"
valid="\033[0;32m✔\033[0m"
wrong="\033[0;31m✖\033[0m"
normal="\033[0m"
bold="\033[1m"
dump_file="$server_path"/tmp/cmd_dump.txt
backup_path="$server_path"/backup/
overworld_dir="world"
nether_dir="world_nether"
the_end_dir="world_the_end"
backup_limit=5

function on_fail
{
    printf "\n $wrong ${bold}fail!${normal}\n"
}

trap on_fail ERR

if [ whoami != "$server_user" ] ;then
    sudo_cmd="sudo -u "${server_user}""
else
    sudo_cmd=""
fi

if [ $(${sudo_cmd} whoami) != "$server_user" ] ;then
    printf " $wrong you have no permission"
    exit 1
fi

function is_alive
{
    if ${sudo_cmd} screen -S "$session" -Q info > /dev/null ;then
        return 0
    else
        return 1
    fi
}

function cmd
{
    if is_alive ;then : 
    else
        printf " $wrong no server running\n"
	    exit 1
    fi
    if [ -z $log_cmd ] ;then
        ${sudo_cmd} screen -S "$session" -X stuff "$(printf "%s\r" "$*")"
    else
        ${sudo_cmd} screen -S "$session" -X log on
        ${sudo_cmd} screen -S "$session" -X stuff "$(printf "%s\r" "$*")"
	    sleep 0.5
	    ${sudo_cmd} screen -S "$session" -X log off
        ${sudo_cmd} head -n -1 "$dump_file" | tail -n +2
	    echo
        ${sudo_cmd} rm "$dump_file"
    fi
}

function backup
{
    if [ ! -d "$backup_path" ] ;then
        ${sudo_cmd} mkdir "$backup_path"
    fi
    echo "starting backup..."
    cmd say "starting backup..."
    archive="backup_$(date +%d/%m/%Y_%H:%M:%S).tar.gz"
    if is_alive ;then
        cmd save-off
        cmd save-all
        sync && wait
        ${sudo_cmd} tar -C "$server_path" -czf "$backup_path/$archive" --totals "$overworld_dir" "$nether_dir" "$the_end_dir"
        cmd save-on
    else
        ${sudo_cmd} tar -C "$server_path" -czf "$backup_path/$archive" --totals "$overworld_dir" "$nether_dir" "$the_end_dir"
    fi
    printf " $valid backup done\n"
    cmd say "backup done"
    backup_count=$(ls -A "$backup_path" | wc -l)
    if [ ${backup_count} -gt ${backup_limit} ] ;then
        for old_backup in $(ls -tr "$backup_path" | head -n "$(( $backup_count - $backup_limit ))") ;do
            ${sudo_cmd} rm "$backup_path/$old_backup"
            echo "$old_backup" pruned
        done
    fi
}

function start
{
    if is_alive ;then
        printf " $wrong the server is already running\n"
    else
        ${sudo_cmd} screen -dmS "$session" /bin/bash -c "cd ${server_path}; ${server_start_cmd}"
        ${sudo_cmd} screen -S "$session" -X logfile "$dump_file"
	    printf " $valid server started\n"
    fi
}

function restart
{
    if is_alive ;then
        stop
        start
    else
        start
    fi
}

function stop
{
    if is_alive ;then
        cmd stop
    else
        printf " $wrong no server running\n"
        exit 1
    fi

    while is_alive ;do :
    done
    printf " $valid server stopped\n"
}

function status
{
    if is_alive ;then
        printf " $valid server running\n"
    else
        printf " $wrong server died\n"
    fi
}

function console
{
    if is_alive ;then
        ${sudo_cmd} screen -S "$session" -rx > /dev/null
    else
        printf " $wrong no server running\n"
    fi
}

function help
{
     printf "\t${bold}$0${normal} [option|cmd <server command>]\n\n"
     printf "\t${bold}start${normal}\t\tstart server\n"
     printf "\t${bold}restart${normal}\t\trestart server\n"
     printf "\t${bold}stop${normal}\t\tstop server\n"
     printf "\t${bold}status${normal}\t\tserver status\n"
     printf "\t${bold}console${normal}\t\topen server console, press CTRL-a d to quit console mod\n"
     printf "\t${bold}backup${normal}\t\tbackup server files\n"
     printf "\t${bold}cmd <server command>${normal}\n\t\tenter a server command\n"
     printf "\t${bold}help${normal}\t\tdisplay this help\n"
}

case "$1" in
    'start')
        start
    ;;
    'restart')
        restart
    ;;
    'stop')
        stop
    ;;
    'status')
        status
    ;;
    'console')
        console
    ;;
    'cmd')
        log_cmd=true
        cmd "${@:2}"
    ;;
    'backup')
        backup
    ;;
    *)
        help
    ;;
esac
