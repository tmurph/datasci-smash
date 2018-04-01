filename=$(basename "$1")
IFS=_ read char color stage orientation ignore bg rest <<<"$filename"

setup_dir="$(dirname $0)/setup_files"
echo "${setup_dir}/10_to_debug.txt"
echo "${setup_dir}/11_to_dairantou.txt"
echo "${setup_dir}/20_char_select_${char}.txt"
echo "${setup_dir}/21_scale_select.txt"
echo "${setup_dir}/22_kind_select.txt"
echo "${setup_dir}/23_color_select_${color}.txt"
echo "${setup_dir}/24_subcolor_to_stage.txt"
echo "${setup_dir}/25_stage_select_${stage}.txt"
echo "${setup_dir}/26_meleekind_to_exit.txt"
echo "${setup_dir}/27_exit_to_go.txt"
