IFS=_ read char color stage orientation ignore bg rest <<<"$1"

echo $char

if [ "$bg" == 'on' ]
then echo 'hud-off'
else echo 'background-off'
fi

if [ "$orientation" == 'left' ]
then echo 'turn-around'
fi
