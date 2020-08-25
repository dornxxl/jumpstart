#!/bin/bash
ret_code=1
if [ $# -ne 1 ]; then
    echo "Usage : $0 passwd"
else
    PASSWD=$1
    pwlen=${#PASSWD}
    if [ $pwlen -ge 8 ]; then
        echo "$PASSWD" | grep -qv "[[:blank:][:cntrl:][:space:]]"
        if [ $? -eq 0 ]; then
            echo "$PASSWD" | grep -q "[[:digit:]]"
            if [ $? -eq 0 ]; then
                echo "$PASSWD" | grep -q "[[:upper:]]"
                if [ $? -eq 0 ]; then
                   	echo "$PASSWD" | grep -q "[[:punct:]]"
			if [ $? -eq 0 ]; then
				ret_code=0 
			else
				echo "Fail - password must contain special character"
			fi
                else
                    echo "Fail - password must contain uppercase"
                fi
            else
                echo "Fail - password must contain number"
            fi
        else
            echo "Fail - password must not contain blank and control character"
        fi
    else
        echo "Fail - password must longer than 8 charactor"
    fi
fi
exit $ret_code
