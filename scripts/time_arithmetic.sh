# Add file contents and divide by DENOM.  Default 240
# If there's an OFFSET variable, add that too.  Default -420

inputs=${OFFSET=-420}
denom=${DENOM=240}
for filename in "$@"; do
    (( inputs += $(cat "$filename") ))
done
echo "$inputs / $denom" | bc -l
