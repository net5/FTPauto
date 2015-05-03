#!/bin/bash
s_version="0.3.3"
verbose="0" #0 Normal info | 1 debug console | 2 debug into logfile
script="$(readlink -f $0)"
scriptdir=$(dirname $script)

control_c() {
	# run if user hits control-c
	echo -ne '\n'
	cleanup die
}
trap control_c SIGINT

function verbose {
	#todo fix verbose in external scripts
	if [[ $quiet ]]; then
		#silent
		exec > /dev/null 2>&1
	elif [[ ! $quiet ]] && [[ $verbose == 1 ]]; then
		echo "STARTING PID=$BASHPID"
		set -x
	elif [[ ! $quiet ]] && [[ $verbose == 2 ]]; then
		#verbose
		echo "INFO: Debugging. All input is redirected to logfile. Script is finished when console is idle again. Please wait!"
		exec 2>> "$scriptdir/run/$username.ftpauto.debug"
		echo "STARTING PID=$BASHPID"
		set -x
	elif [[ $quiet ]] && [[ $verbose != 0 ]]; then
		echo -e "\e[00;31mERROR: Verbose and silent can't be used at the same time\e[00m"
		exit 0
	fi
}
# load verbose
verbose

function start_ftpmain {
	# used to start ftpmain script and set proper debug level
	source "$scriptdir/dependencies/ftp_main.sh"
	if [[ $verbose -eq 1 ]]; then
		start_main "${download_argument[@]}"
	elif [[ $verbose -eq 2 ]]; then
		start_main "${download_argument[@]}" >> "$ftpmaindebugfile"
	else
		# run in background or run normal
		if [[ $background == "true" ]]; then
			start_main "${download_argument[@]}" &> /dev/null &
		else
			start_main "${download_argument[@]}"
		fi
	fi
}

function confirm {
	case "$1" in
		queue_file )
			if [[ ! -f "$queue_file" ]]; then
				message "$2" "$3"
			fi
			;;
		lock_file )
			if [[ ! -f "$lockfile" ]]; then
				message "$2" "3"
			fi
		;;
	esac
}

function message {
	if [[ "$2" == "1" ]]; then
		echo -e "\e[00;31m$(date '+%d/%m/%y-%a-%H:%M:%S'): $1\e[00m"
	else
		echo -e "\e[00;32m$(date '+%d/%m/%y-%a-%H:%M:%S'): $1\e[00m"
	fi
	echo
	exit "$2"
}

function load_help {
	if [[ -e "$scriptdir/dependencies/help.sh" ]]; then
		source "$scriptdir/dependencies/help.sh"
	else
		echo -e "\e[00;31mError: /dependencies/help.sh is\n needed in order for this program to work\e[00m";
		exit 1
	fi
}

function load_user {
	if [[ -z "$username" ]] && [[ -f "$scriptdir/users/default/config" ]]; then
		username="default"
		config_name="$scriptdir/users/default/config"
		source "$scriptdir/users/$username/config"
		echo "INFO: User: $username"
	elif [[ -n "$username" ]] && [[ -f "$scriptdir/users/$username/config" ]]; then
		username="$username"
		config_name="$scriptdir/users/$username/default"
		source "$scriptdir/users/$username/config"
		echo "INFO: User: $username"
	elif [[ $option == "add" ]]; then
		# manually add user
		if [[ -z "$username" ]]; then
			username="default"
		else
			username="$username"
		fi
	else
		# user used not found, want to create them
		if [[ -z "$username" ]]; then
			echo -e "\e[00;31mERROR: No config found for default\e[00m"
			read -p "Do you want to create config for default user (y/n)? "
			if [ "$REPLY" == "y" ]; then
				username="default"
				option="add"
			else
				echo -e "\e[00;31mYou may want to have a look on --help\e[00m"
				echo
				exit 1
			fi
		elif [[ -n "$username" ]]; then
			echo -e "\e[00;31mERROR: No config found for user=$username\e[00m"
			read -p "Do you want to create config for $username user (y/n)? "
			if [ "$REPLY" == "y" ]; then
				username="$username"
				option="add"
			else
				echo -e "\e[00;31mYou may want to have a look on --help\e[00m"
				echo
				exit 1
			fi
		fi
	fi
	# confirm that config is most recent version
	if [[ $config_version -lt "4" ]] && [[ $option != "add" ]] && [[ $option != "edit" ]]; then
		echo -e "\e[00;31mERROR: Config is out-dated, please update it. See --help for more info!\e[00m"
		echo -e "\e[00;31mIt has to be version 4\e[00m"; echo ""
		exit 0
	fi
}

function invalid_arg {
echo -e "\e[00;31mInvalid input for argument '$@'\e[00m"
echo -e "\e[00;31mYou may want to have a look on --help\e[00m"
echo
exit 1
}

function option_manage {
if [[ -z ${option[0]} ]]; then
	option="$1"
else
	echo -e "\e[00;31mError: An option, --${option[0]} is already used. Only use one. Exiting...\e[00m"
	echo
	exit 1
fi
}

function main {
case "${option[0]}" in
	"add" ) # add user
		load_help; write_config
		read -p " Do you want to configure that user now(y/n)? "
		if [[ "$REPLY" == "y" ]]; then
			nano "$scriptdir/users/$username/config"
		else
			echo "You can edit the user, by editing \"$scriptdir/users/$username/config\""
		fi
		# create the user's logfile
		create_log_file
		message "User=$username added." "0"
	;;
	"edit" ) # edit user config
		nano "$scriptdir/users/$username/config"
		message "User=$username edited." "0"
	;;
	"remove" ) # remove all userfiles generated files. Does not remove config
		rm -rf "$scriptdir/run/$username"
		rm "$scriptdir/users/$username/log"
		message "Userfiles removed for $username." "0"
	;;
	"purge" ) # remove all userfiles log files and config from /run and /user/$username/
		confirm lock_file "Can't remove $username while session is running." "1"
		rm -rf "$scriptdir/users/$username"
		rm -rf "$scriptdir/run/$username"
		message "User=$username removed." "0"
	;;
	"pause" ) # Stop transfer
		confirm lock_file "Error, lockfile couldn't be found. Nothing could be done!" "1"
		cleanup stop
		cleanup session
		cleanup end
		message "Session has been terminated." "0"
	;;
	"stop" ) # Stop transfer and remove queue
		confirm lock_file "Error, lockfile couldn't be found. Nothing could be done!" "1"
		cleanup stop
		cleanup session
		cleanup end
		rm "$queue_file"
		message "Session has been terminated." "0"
	;;
	"start" ) # start session from queue file
		if [[ ! -e "$queue_file" ]]; then
			message "Nothing in queue." "1"
		fi
		start_ftpmain
		if [[ $background == "true" ]]; then
			message "Session has started." "0"
		elif [[ $? -eq 1 ]]; then
			message "Succeeded." "0"
		else
			message "Failed." "1"
		fi
	;;
	"download" )
		# set source
		if [[ -z $source ]]; then
			source="CONSOLE"
		else
			source="$source"
		fi
		# start download right away
		if [[ ${option[1]} == "start" ]]; then
			start_ftpmain
			if [[ $background == "true" ]]; then
				message "Session in background has started." "0"
			elif [[ $? -eq 0 ]]; then
				message "Succeeded." "0"
			else
				message "Failed." "1"
			fi
		# queue download
		# TODO: Add options to queuefile as well
		elif [[ ${option[1]} == "queue" ]]; then
			# determine if item exists already
			if [[ -e "$queue_file" ]]; then
				if [[ -n $(cat "$queue_file" | grep $(basename "$path")) ]]; then
					message "INFO: Item already exists. Doing nothing. Exiting..." "1"
				fi
				# find id to <ITEM>
				id=$(( $(tail -1 "$queue_file" | cut -d'#' -f1) + 1 ))
			else # no queue files exists
				id="1"
			fi
			# get transfer size
			if [[ "$transferetype" == "downftp" ]]; then
				# check size on ftp
				echo "INFO: Looking up size on ftp..."
			elif [[ "$transferetype" == "upftp" ]]; then
				# confirm file exists locally and then use it
				if [[ ! -d "$path" ]] || [[ ! -f "$path" ]] && [[ -z $(find "$path" -type f) ]]; then
					message "ERROR: Option --path is required with existing path and has to contain file(s).\n See --help for more info!!" "1"
					exit 1
				fi
			fi
			get_size "$path" "exclude_array[@]" &> /dev/null
			echo "$id#$source#$path#$size"MB"#$(date '+%d/%m/%y-%a-%H:%M:%S')" >> "$queue_file"
			message "Adding $(basename "$path") to queue with id=$id" "0"
		fi
	;;
	"list" ) # list content of queue file
		confirm queue_file "Empty queue!" "0"
		while read line; do
			id=$(echo $line | cut -d'#' -f1)
			source=$(echo $line | cut -d'#' -f2)
			path=$(echo $line | cut -d'#' -f3)
			size=$(echo $line | cut -d'#' -f4)
			time=$(echo $line | cut -d'#' -f5)
			echo $id $source $path $size $time
		done < "$queue_file"
		message "List has been shown." "0"
	;;
	"clear" ) # clear content of queue file
		confirm queue_file "Error, queue could not be found." "1"
		rm "$queue_file"
		message "Queue removed." "0"
	;;
	"forget" ) # remove item with <ID> from queue
		confirm queue_file "Error, queuefile couldn't be found. Nothing could be removed!" "1"
		if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
			#make sure id exists and is present in queue
			echo "Removing id=$id"
			sed "/^"$id"\#/d" -i "$queue_file" #ex -s -c '%s/^[0-9]*//|wq' file.txt if your ex is actually symlinked to the installed vim, then you can use \d and \+
			message "Id=$id removed from queue."	"0"
		else
			message "No Id=$id selected/in queue." "1"
		fi
	;;
	"up" ) # Move item with <ID> 1 up in queue
		confirm queue_file "Error, queuefile couldn't be found. Nothing could be moved!" "1"
		if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
			line_info=$(cat "$queue_file" | grep "^$id#")
			line_number=$(cat "$queue_file" | grep -ne "^$id#" | cut -d':' -f1)
			previous_line_number=$(($line_number -1))
			if [[ "$line_number" -lt "2" ]]; then
				#if id is the first, keep it there
				message "Id, $id, is at top." "0"
			else
				sed "/^"$id"\#/d" -i "$queue_file"
				sed "$previous_line_number i $line_info" -i "$queue_file"
				message "Moved Id=$id, up." "0"
			fi
		else
			message "No Id=$id, selected/in queue." "1"
		fi
	;;
	"down" ) # Move item with <ID> 1 down in queue
		confirm queue_file "Error, queuefile couldn't be found. Nothing could be moved!" "1"
		if [[ -n "$id" ]] && [[ -n $(cat "$queue_file" | grep "^$id#") ]]; then
			line_info=$(cat "$queue_file" | grep "^$id#")
			line_number=$(cat "$queue_file" | grep -ne "^$id#" | cut -d':' -f1)
			next_line_number=$(($line_number +1))
			last_line=$(cat "$queue_file" | grep -ne '' | cut -d':' -f1 | tail -n1 )
			if [[ $next_line_number -eq $last_line ]]; then
				#add id to the end of file
				sed "/^"$id"\#/d" -i "$queue_file"
				echo $line_info >> "$queue_file"
				message "Id=$id, is at the buttom." "0"
			elif [[ $next_line_number -gt $last_line ]]; then
				#if id is the last, do nothing
				message ": Id=$id, is at the buttom." "1"
			else
				#any other cases
				sed "/^"$id"\#/d" -i "$queue_file"
				sed "$next_line_number i $line_info" -i "$queue_file"
				message "$option: Moved Id=$id, down." "0"
			fi
		else
			message "$option: No Id, $id, selected/in queue." "1"
		fi
	;;
	"online" ) # Perform server test
		source "$scriptdir/dependencies/ftp_login.sh" && ftp_login
		source "$scriptdir/dependencies/ftp_online_test.sh" && online_test
		cleanup session
		if [[ $is_online -eq 0 ]]; then
			message "Server is OK" "0"
		else
			message "Server is NOT OK" "1"
		fi
	;;
	"freespace" ) # check free space
		source "$scriptdir/dependencies/ftp_login.sh" && ftp_login
		source "$scriptdir/dependencies/ftp_size_management.sh" && ftp_sizemanagement info
		cleanup session
		if [[ $is_online -eq 1 ]]; then
			message "$option: Could " "1"
		else
			message "$option: Server is responding" "0"
		fi
	;;
	"progress" ) # write out download progress
		confirm lock_file "Error, lockfile couldn't be found. Nothing is being transferred!" "1"
		echo "INFO: Keeps updating every 60 second. Exit with \"x\""
		if [ -t 0 ]; then stty -echo -icanon time 0 min 0; fi
		keypress=""
		while [[ "x$keypress" == "x" ]]; do
			info=$(sed -n '5p' < "$logfile" | egrep -o 'Transferring.*')
			if [[ -z "info" ]]; then
				echo "INFO: Nothing is transferred!"
				break
			fi
			echo -ne $info \(last update $(date '+%H:%M:%S')\) '\r'
			sleep 1
			read keypress
		done
		if [ -t 0 ]; then stty sane; fi
		echo -e '\n'
		message "Progress finished" "0"
	;;
	"dir" ) # list content of ftpserver and download it
		source "$scriptdir/dependencies/ftp_list.sh" && ftp_list
		message "Closing FTP filebrowser" "0"
	;;
	* )
		message "No options selected." "1"
	;;
esac
}
################################################### CODE BELOW #######################################################

echo
echo -e "\e[00;34mFTPauto script - $s_version\e[00m"
echo


download_argument=()
if (($# < 1 )); then echo -e "\e[00;31mERROR: No option specified\e[00m"; echo "See --help for more information"; echo ""; exit 0; fi
while :
do
	case "$1" in
		# Session
		--pause ) option_manage pause; shift;;
		--stop ) option_manage stop; shift;;
		--start ) option_manage start; shift;;
		# User
		--add ) option_manage add; shift;;
		--edit ) option_manage edit; shift;;
		--purge ) option_manage purge; shift;;
		--user ) if (($# > 1 )); then user=$2; download_argument+=("--user=$username"); else invalid_arg "$@"; fi; shift 2;;
		--user=* ) username=${1#--user=}; download_argument+=("--user=$username"); shift;;
		# Item
		--forget ) option_manage forget; shift;;
		--list ) option_manage list; shift;;
		--remove ) option_manage remove; shift;;
		--up ) option_manage up; shift;;
		--down ) option_manage down; shift;;
		--id ) if (($# > 1 )); then id=$2; else invalid_arg "$@"; fi; shift 2;;
		--id=* ) id=${1#--id=}; shift;;
		--clear ) option_manage clear; shift;;
		# Options
		--queue ) option[1]=queue; shift;;
		--delay ) if (($# > 1 )); then delay=\"$2\"; download_argument+=("--delay=$delay"); else invalid_arg "$@"; fi; shift 2;;
		--delay=* ) delay=${1#--delay=}; download_argument+=("--delay=$delay"); shift;;
		--sort ) if (($# > 1 )); then sortto="$2"; download_argument+=("--sortto=$sortto"); else invalid_arg "$@"; fi; shift 2;;
		--sort=* ) sortto=${1#--sort=}; download_argument+=("--sortto=$sortto"); shift;;
		--path ) if (($# > 1 )); then option[0]="download"; if [[ -z ${option[1]} ]]; then option[1]="start";fi; path="$2"; download_argument+=("--path=$path"); else invalid_arg "$@"; fi; shift 2;;
		--path=* ) option[0]="download"; if [[ -z ${option[1]} ]]; then option[1]="start";fi; path="${1#--path=}"; download_argument+=("--path=$path"); shift;;
		--source=* ) source=${1#--source=}; download_argument+=("--source=$source"); if [[ -z $source ]]; then invalid_arg "$@"; exit 1; fi; shift;;
		--source | -s ) if (($# > 1 )); then source=\"$2\"; download_argument+=("--source=$source"); else invalid_arg "$@"; fi; shift 2;;
		# Other
		--help | -h ) load_help; show_help; exit 1;;
		--verbose | -v) verbose=1; shift;;
		--debug ) verbose=2; shift;;
		--quiet) quiet=true; shift;;
		--bg) background=true; shift;;
		--progress) option=progress; shift;;
		--online ) option=online; shift;;
		--dir=* ) dir=${1#--dir=}; option=dir; shift;;
		--dir ) option=dir; if (($# > 1 )); then dir="$2"; fi; shift;;
		--force ) download_argument+=("--force"); shift;;
		--freespace ) option=freespace; shift;;
		--exec_post=* ) exec_post="${1#--exec_post=}"; download_argument+=("--exec_post"); shift;;
		--exec_post ) if (($# > 1 )); then exec_post="$2"; download_argument+=("--exec_post"); else invalid_arg "$@"; fi; shift 2;;
		--exec_pre=* ) exec_pre="${1#--exec_pre=}"; download_argument+=("--exec_pre"); shift;;
		--exec_pre ) if (($# > 1 )); then exec_pre="$2"; download_argument+=("--exec_pre"); else invalid_arg "$@"; fi; shift 2;;
		--test ) option=( "download" "start"); download_argument+=("--test"); shift;;
		-* ) echo -e "\e[00;31mInvalid option: $@\e[00m"; echo "Try viewing --help"; exit 0;;
		* ) break;;
		--) shift; break;;
	esac
done

# load verbose level
verbose
echo "INFO: Information level: $verbose"

# load user
load_user

# Load dependencies
source "$scriptdir/dependencies/setup.sh"
setup

# make sure user has a log file
if [ ! -e "$logfile" ] && [[ "${option[0]}" != add ]]; then
	load_help; create_log_file
fi

# Execute the given option
echo "INFO: Option(s): ${option[@]}"
main
