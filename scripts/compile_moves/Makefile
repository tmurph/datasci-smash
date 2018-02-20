all: dtm_inputs.csv character_frames.csv

dtm_inputs.csv: dtm_inputs_no_orientation.csv dtm_inputs_yes_orientation.csv
	sqlite3 <dtm_inputs_compile.sql

character_frames.csv: character_frames_specific.csv character_frames_universal.csv
	sqlite3 <character_frames_compile.sql
