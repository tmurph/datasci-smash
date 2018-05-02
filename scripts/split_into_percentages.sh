filename="$1"
line_count=$(cat "$filename" | wc -l)
shift

i=0
args=()
prev_linum=1
while [ "$#" -gt 1 ]
do
    suffix="$1"
    percentage="$2"
    next_linum=$(expr "$prev_linum" + "$line_count" \* "$percentage" / 100)
    shift
    shift

    args[$i]="-e"
    ((++i))
    args[$i]="${prev_linum},${next_linum} w ${filename}_${suffix}"
    ((++i))

    prev_linum=$(expr "$next_linum" + 1)
done

if [ "$#" -gt 0 ]; then
    suffix="$1"
    args[$i]="-e"
    ((++i))
    args[$i]="${prev_linum},\$ w ${filename}_${suffix}"
fi

sed -n "${args[@]}" <"$filename"
