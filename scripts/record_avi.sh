avi_filename="$1"
dtm_filename="$2"
total_sec=$(printf "%.0f" "$3")

avi_dir="$(dirname $0)/record_avi"
melee_iso="${avi_dir}/Super Smash Bros. Melee (v1.02).iso"

dolphin=/usr/games/dolphin-emu
user_dir="${avi_dir}/dolphin-user"

frame_dir="${user_dir}/Dump/Frames"
dolphin_video="${frame_dir}/framedump0.avi"

rm -f "$dolphin_video"

# On my Mac OSX, Dolphin --batch still requires user input to shut down
# when the movie finishes :(.  Let's try to hack around it with dumb
# sleeping mechanisms.
"$dolphin" -u "$user_dir" -e "$melee_iso" -b -m "$dtm_filename" &
dolphin_pid=$!
read -p "Sleep for: $total_sec" -t $total_sec
kill -TERM $dolphin_pid

mv "$dolphin_video" "$avi_filename"
