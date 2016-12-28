ifs="$IFS"
export IFS="
"
while [ 1 ]
do
	clear
	echo Available screen sessions:
	echo --------------------------
	x=0;
	session=( $(screen -d))
	let "length=${#session[*]}-1"
	for name in ${session[@]}
		do
			if [ $x -gt 0 -a $x -lt $length ]
				then
				echo "$x $name"
			fi
			((x++))
	done
	if [ $length -le 0 ]; then echo "--- no open screen sessions ---";fi
	echo -n "type session number (x to exit):"
	read sel
	if [ "$sel" == "x" ]; then break;fi
	if [ $sel ]; then
		if echo $sel | grep "^[0-9]*$"
		then
			arg=( $( echo ${session[$sel]} | tr "." "\n" | tr -d "\t"))
			screen -r $arg
		fi
	fi
done
export IFS="$ifs"

