#!/bin/bash
############################################################
#  This script will automate the process of                #
#  Logging Calls on a Pi-Star Hotpot			   #
#  to assist with Net Logging                              #
#                                                          #
#  VE3RD                              Created 2021/07/05   #
############################################################
set -o errexit 
set -o pipefail 
set -e 
#set -x

ver=20210729

sudo mount -o remount,rw / 

callstat="" 
callinfo="No Info" 
lastcall2="" 
lastcall1=""
P1="$1" 
P2="$2" 
netcont=${P1^^} 
stat=${P2^^} 
#echo "$netcont"   "$stat" 
dur=$((0)) 
cnt=$((0))
cm=0
lcm=0
ber=0
netcontdone=0
nodupes=0

err_report() {
    echo "Error on line $1"
}

trap 'err_report $LINENO' ERR

function help(){
#echo "Syntax : \./netlog.sh Param1 Param2 Param3"
echo "All Parameters are optional"
echo "Param1 can be  any one of three things "
echo "1) Net Controller Call Sign.  If used This must be Param 1"
echo "2) The word 'NEW' This will initalize the Log File"
echo "3) The word 'NODUPES' This will stop the display from showing Dupes"
echo "Param 2 and 3 may be any cobination of items 2 and 3 above"
}


function header(){
	clear
	set -e sudo mount -o remount,rw / 
	echo ""
	echo "NET Logging Program by VE3RD Version $ver"
	echo ""
	echo "Dates and Times Shown are Local to your hotspot"
	echo ""
	echo "Net Log Started $dates"
	echo "0, Net Log Started $dates" > /home/pi-star/netlog.log
	echo ""

	if [ ! "$netcont" ] || [ "$netcont" == "NEW" ]; then
		echo "No Net Controller Specified"
		netcont="N/A"
	else
		echo "Net Controller is $netcont"
		echo ""
	fi
}

function getserver(){

Addr=$(sed -n -r "/^\[DMR Network\]/ { :l /^Address[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/mmdvmhost)
if [ $Addr = "127.0.0.1" ]; then
	fg=$(ls /var/log/pi-star/DMRGateway* | tail -n1)
	NetNum=$(sudo tail -n1 "$fg" | cut -d " " -f 6)
	server=$(sed -n -r "/^\[DMR Network "${NetNum##*( )}"\]/ { :l /^Name[ ]*=/ { s/.*=[ ]*//; p; q;}; n; b l;}" /etc/dmrgateway)
else
	ms=$(sudo sed -n '/^[^#]*'"$Addr"'/p' /usr/local/etc/DMR_Hosts.txt | head -n1 | sed -E "s/[[:space:]]+/|/g" | cut -d'|' -f1)
 	server=$(echo "$ms" | cut -d " " -f1)
fi
}

function getuserinfo(){
	if [ "$cm" != 6 ] && [ ! -z  "$call" ]; then
 		line=$(sed -n '/'"$call"',/p' /usr/local/etc/stripped.csv | tail -n1)	

		if [ line ]; then
			name=$(echo "$line" | cut -d "," -f 3 | cut -d " " -f 1)
			city=$(echo "$line"| cut -d "," -f 5)
			state=$(echo "$line" | cut -d "," -f 6)
			country=$(echo "$line" | cut -d "," -f 7)
		else
			callinfo="No Info"
			name=""
			city=""
			state=""
			country=""
		fi
	fi
}

function checkcall(){
	if [ "$cm" != 6 ]; then
	
		num=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log | head -n1) 
		if [ -z "$num" ]; then 
     			callstat="New"
		
		else
#			echo "Duplicate $call"
     			callstat="Dup"
			cnt2d=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log | head -n1 | cut -d "," -f 1)
			ck=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log | head -n1 | cut -d "," -f 3)
			ckt=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log | head -n1 | cut -d "," -f 2)
#			echo "Dupe Cnt = $cnt2d"
		fi	
	fi
}

function Logit(){
	sudo mount -o remount,rw /
	## Write New Call to Log File
	echo "$cnt,$Time,$call,$name,$city,$state,$country " >> /home/pi-star/netlog.log
}

function getnewcall(){
        f1=$(ls -tv /var/log/pi-star/MMDVM* | tail -n 1 )
        nline1=$(tail -n 1 "$f1")
	tg=""

	if [[ $nline1 =~ "header" ]]; then
   		cm=1
 		call=$(echo "$nline1" | cut -d " " -f 12) 
		tg=$(echo "$nline1" | cut -d " " -f 15)
        	call1="$call"
        	ln2=""
	elif [[ $nline1 =~ "transmission" ]]; then
        	call=$(echo "$nline1" | cut -d " " -f 14 )
		if [[ $nline1 =~ "RF" ]]; then
			durt=$(echo "$nline1" | cut -d " " -f 18)
			dur=$(printf "%1.0f\n" $durt)
			ber=$(echo "$nline1" | cut -d " " -f 21)
			cm=2
		else
			durt=$(echo "$nline1" | cut -d " " -f 18 )
			dur=$(printf "%1.0f\n" $durt)
			pl=$(echo "$nline1" | cut -d " " -f 20 )
			cm=2
		fi
		
		tg=$(echo "$nline1" | cut -d " " -f 17)
        	call2="$call"
        	ln1=""
		if [ "$cm" == 1 ]; then
			tput cuu 1
		fi
	
	elif [[ $nline1 =~ "watchdog" ]]; then
        	cm=5
        	call2="$call"
	
	elif [[ $nline1 =~ "overflow" ]]; then
        	cm=6
        	call2="NA"
	
	elif [[ $nline1 =~ "Data" ]]; then
        	cm=6
        	call2="NA"
	
	elif [ "$cm" != 1 ] && [ "lcm" == 1 ]; then
   		tput cuu 1
	fi
}



######## Start of Main Program
if [ "$netcont" == "HELP" ]; then
	help
	exit
fi

if [ "$netcont" == "HELP" ]; then
	help
	exit
fi

if [ "$netcont" == "NEW" ] || [ "$stat" == "NEW" ] || [ ! -f /home/pi-star/netlog.log ]; then
	## Delete and start a new data file starting with date line
	dates=$(date '+%A %Y-%m-%d %T')
        header 
else
	cntt=$(tail -n 1 /home/pi-star/netlog.log | cut -d "," -f 1)
	cnt=$((cntt))
	echo "Restart Program Ver:$ver - Counter = $cnt"
fi

if [ "$netcont" == "NODUPES" ] || [ "$stat" == "NODUPES" ]; then
	nodupes=1
	echo "Dupes Will Not be Displayed"
	echo ""
else
	nodupes=0
	echo "Dupes Will Be Displayed"
	echo ""
fi

if [ "$netcont" == "NODUPES" ] || [ "$stat" == "NODUPES" ]; then
	nodupes=1
	echo "Dupes Will Not be Displayed"
	echo ""
else
	nodupes=0
	echo "Dupes Will Be Displayed"
	echo ""
fi

getnewcall
callstat=""
if [ ! "$call" ]; then
	call="$netcont"
	lastcall="$netcont"
	lastcall1="$netcont"
	lastcall2="$netcont"
fi

######### Main Loop Starts Here

while true
do 
	cm=0	

	getnewcall
	if [ -z "$call" ]; then
		cm=0
	else
		getuserinfo
		checkcall
		getserver
	fi

#if [ "$lastcall1" != "$call1" ] && [ "$cm" == 1 ]; then

	if [ "$cm" == 1 ]; then
		printf '\e[0;40m'
		printf '\e[0;35m'
		if [ "$lcm" == 1 ]; then
			tput cuu 2
		else
			tput el 1
			tput el
		fi
		echo "    Active Transmission from $call1 $name, $city, $state, $country  $tg  $server"
		lcm=1
		call2=""
		lastcall2="n/a"
		lastcall1="$call1"
	fi

 	Time=$(date '+%T')  
	
	if [ "$call" != "$netcont" ]; then 
		netcontdone=0 
	fi

	if [ "$cm" == 2 ] && [ "$call" == "$netcont" ] && [ "$netcontdone" != 1 ]; then
			sudo mount -o remount,rw /
			tput el 1
			tput el
			printf '\e[0;40m'			
			echo -e '\e[1;34m'"-------------------- $Time  Net Control $netcont $name   $tg   $server"          
			echo -e "$cnt,--------------------- $Time  Net Control $netcont " >> /home/pi-star/netlog.log
			
			name=""
			city=""
			state=""
			country=""
			callstat="NC"		
			netcontdone=1
	fi

	if [ "$cm" == 2 ] && [ "$call" != "$netcont" ]; then
		lastcall1=""
		if [ "$lastcall2" != "$call" ]; then
			if [ $dur -lt 2 ]; then
				#### Keyup < 2 seconds
		#		getuserinfo
				lcm=0
				tput el 1
				tput el
				if [ "$callstat" == "New" ]; then
					printf '\e[0;40m'
					printf '\e[1;36m'
					cnt=$((cnt+1))
printf "%-3s New KeyUp  %-8s -- %-6s %s, %s, %s, %s, %s, %s, TG:%s  %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl" "$tg" "$server"	
					Logit
				fi
				
				if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
					printf '\e[0;46m'
					printf '\e[0;33m'
					cnt2d=$(sed -n '/'"$call"'/p' /home/pi-star/netlog.log | head -n1 | cut -d "," -f 1)
printf "KeyUp Dupe %-3s %-15s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time/$ckt" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl               "	
				fi	
#				echo "Dupe Callstat = $callstat $dur"
			else

				if [ "$callstat" == "New" ]; then
##					echo " Write New Call to Screen"
					cnt=$((cnt+1))
					printf '\e[0;40m'
					printf '\e[1;36m'

					tput el 1
					tput el
printf "%-3s New Call   %-8s -- %-6s %s, %s, %s, %s, $s  Dur:%s Secs, PL:%s, TG:%s %s\n" "$cnt" "$Time" "$call" "$name" "$city" "$state" "$country" "$durt"  "$pl" "$tg"  "$server"	
					lcm=0
					Logit
				fi
				if [ "$callstat" == "Dup" ] && [ "$nodupes" == 0 ]; then
					## Write Duplicate Info to Screen
					lcm=0
					tput el 1
					tput el
					printf '\e[0;46m'
					printf '\e[0;33m'
printf " Duplicate %-3s %-15s %-6s %s, %s, %s, %s, %s, %s\n" "$cnt2d" "$Time/$ckt" "$call" "$name" "$city" "$state" "$country" " Dur: $durt sec"  "PL: $pl               "	
				fi
			
			fi
			lastcall2="$call"
		fi
	fi

	if [ "$lcm" == 1 ] && [ "$cm" != 1 ]; then
		tput cuu 1
	fi	


	if [ "$cm" == 5 ] && [ "$lastcall3" != "$call" ]; then
        	call2="$call"
		durt=$(echo "$nline1" | cut -d " " -f 11 )
		pl=$(echo "$nline1" | cut -d " " -f 13 )
		dur=$(printf "%1.0f\n" $durt)
		printf '\e[0;40m'
		printf '\e[1;31m'
		tput el 1
		tput el
		echo "$Time - DMR Network Watchdog Timer has Expired for $call, $name, $dur Sec   PL:$pl        "
		lastcall3="$call"
		lcm=0
	fi
	if [ "$lcm" == 1 ]; then
		tput cuu 1
		lcm=0
	fi
sleep 0.75
#wait
done

