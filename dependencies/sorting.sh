#!/bin/bash
#version 0.3
function sortFiles {
	# $1 is the argument passed using --sort=<Directory>. No trailing slash is needed
	if [[ -n "$1" ]]; then
		if [[ "$1" == "nosort" ]]; then
			echo "INFO: No sorting. Transferring to default complete directory: \"$ftpcomplete\""
		else
			ftpcomplete="${ftpcomplete}${1}/"
			echo "INFO: Sorted to ${ftpcomplete}"
		fi
	elif [[ $orig_name =~ (\.(x86|x64|mac|android|iphone)) ]]; then
		ftpcomplete=$ftpcomplete"Appz/"
		echo "INFO: Sorted to ${ftpcomplete}"
	elif [[ $orig_name =~ (PAL|NTSC).+DVDR. ]]; then
		ftpcomplete=$ftpcomplete"DVD/"
		echo "INFO: Sorted to ${ftpcomplete}"
	elif [[ $orig_name =~ (BDRip|DVDRip).+(XviD|x264) ]] && [[ ! $orig_name =~ (S[0-9][0-9]) ]] && [[ ! $orig_name =~ (S[0-9][0-9]E[0-9][0-9]) ]] && [[ ! $orig_name =~ (E[0-9][0-9]) ]] && [[ ! $orig_name =~ (S[0-9][0-9]) ]] && [[ ! $orig_name =~ (\.(episode|ep|e|Part|pt)\.(([0-9][0-9]?)|(I|II|III|IV|V|VI|VII|VIII|IIX|IX|X|XI|XII))\.) ]]  && [[ ! $orig_name =~ ([[:digit:]](x|of)[[:digit:]]) ]]; then
		ftpcomplete=$ftpcomplete"XViD/"
		echo "INFO: Sorted to ${ftpcomplete}"
	elif [[ $orig_name =~ (HDDVD|BluRay).+x264 ]] && [[ ! $orig_name =~ (S[0-9][0-9]) ]]; then
		ftpcomplete=$ftpcomplete"HD/"
		echo "INFO: Sorted to ${ftpcomplete}"
	elif [[ $orig_name =~ \.XXX\. ]]; then
		ftpcomplete=$ftpcomplete"XXX/"
		echo "INFO: Sorted to ${ftpcomplete}"
	elif [[ $orig_name =~ (S[0-9][0-9]E[0-9][0-9]) ]] || [[ $orig_name =~ (\.E[0-9][0-9]?[0-9]?\.) ]] || [[ $orig_name =~ (S[0-9][0-9]) ]] || [[ $orig_name =~ (\.(episode|ep|e|Part|pt)\.(([0-9][0-9]?)|(I|II|III|IV|V|VI|VII|VIII|IIX|IX|X|XI|XII))\.) ]]  || [[ $orig_name =~ ([[:digit:]](x|of)[[:digit:]]) ]] || [[ $orig_name =~ ([[:digit:]]{4}.[[:digit:]]{2}.[[:digit:]]{2})|([[:digit:]]{2}.[[:digit:]]{2}.[[:digit:]]{4}) ]]; then
		# Sort to series folders if format matches
		local series_name="${orig_name%%.S[[:digit:]]*}"
		if [[ $orig_name == $series_name ]]; then
			ftpcomplete=$ftpcomplete"TV/"
			echo "INFO: Series name could not be found"
			echo "INFO: Sorted to: ${ftpcomplete}"
		else
			series_name="${series_name//./ }" # replace dots with spaces 
			echo -e "\e[00;37mINFO: Series name: \e[00;32m$series_name\e[00m"
			ftpcomplete=$ftpcomplete"TV/$series_name/"
			echo "INFO: Sorted to: ${ftpcomplete}"
		fi
	else
		echo -e "\e[00;33mINFO: Category could not be parsed\e[00m"
		echo "INFO: Moving files upon finish to default directory: \"$ftpcomplete\""
	fi
}
