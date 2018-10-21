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
     printf "\t${bold}$0${normal} [help|start|restart|stop|status|console|cmd <server command>]\n\n"
     printf "\t${bold}start${normal}\t\tstart server\n"
     printf "\t${bold}restart${normal}\t\trestart server\n"
     printf "\t${bold}stop${normal}\t\tstop server\n"
     printf "\t${bold}status${normal}\t\tserver status\n"
     printf "\t${bold}console${normal}\t\topen server console, press CTRL-a d to quit console mod\n"
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
    *)
        help
    ;;
esac
