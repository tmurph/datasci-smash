.SECONDEXPANSION :

BASH := bash
PYTHON := python3
TEXT2DTM := text2dtm
FFMPEG := ffmpeg
DOLPHIN := dolphin-emu
SQLITE := sqlite3

SCRIPTDIR := scripts
SETUPFILESDIR := $(SCRIPTDIR)/setup_files
COMPILEMOVESDIR := $(SCRIPTDIR)/compile_moves
RECORDAVIDIR := $(SCRIPTDIR)/record_avi

DATADIR := data
IMAGEDIR := $(DATADIR)/images
HISTDIR := $(DATADIR)/hist
MASKDIR := $(DATADIR)/masks
KERASDIR := $(DATADIR)/keras

MAKEABLE_DIRS := $(IMAGEDIR) $(HISTDIR) $(MASKDIR) $(KERASDIR)

CHARACTERS := falco falcon fox jigglypuff marth peach samus sheik
COLORS := 0 1 2 3 4
STAGES := battlefield dreamland final fountain stadium story
ORIENTATIONS := left right

MOVES_LIST := moves_list

dtm_setup_roots := 10_to_debug 11_to_dairantou \
		   $(addprefix 20_char_select_,$(CHARACTERS)) \
		   21_scale_select 22_kind_select \
		   $(addprefix 23_color_select_,$(COLORS)) \
		   24_subcolor_to_stage \
		   $(addprefix 25_stage_select_,$(STAGES)) \
		   26_meleekind_to_exit 27_exit_to_go
dtm_setup_files := $(addprefix $(SETUPFILESDIR)/,\
		     $(addsuffix .txt,\
		       $(dtm_setup_roots)))

stem_roots := $(foreach char,$(CHARACTERS),\
		$(foreach col,$(COLORS),\
		  $(foreach st,$(STAGES),\
		    $(foreach ori,$(ORIENTATIONS),\
		      $(char)_$(col)_$(st)_$(ori)))))

bg_stems := $(addsuffix _bg_on,$(stem_roots))
bg_images := $(addprefix $(IMAGEDIR)/,\
		$(addsuffix _image_list,\
		  $(bg_stems)))
bg_avis := $(addprefix $(IMAGEDIR)/,\
	     $(addsuffix .avi,\
	       $(bg_stems)))

mask_stems := $(addsuffix _bg_off,$(stem_roots))
mask_avis := $(addprefix $(MASKDIR)/,\
	       $(addsuffix .avi,\
		 $(mask_stems)))
mask_images := $(addprefix $(MASKDIR)/,\
		 $(addsuffix _image_list,\
		   $(mask_stems)))
mask_masks := $(addprefix $(MASKDIR)/,\
	   	  $(addsuffix _mask_list,\
	     	    $(mask_stems)))

hist_stems := $(mask_stems)
hist_avis := $(addprefix $(HISTDIR)/,\
	       $(addsuffix .avi,\
		 $(hist_stems)))
hist_images := $(addprefix $(HISTDIR)/,\
		 $(addsuffix _image_list,\
		   $(hist_stems)))
hist_csvs := $(addprefix $(HISTDIR)/,\
		  $(addsuffix _hist.csv,\
		    $(hist_stems)))

char_name_from_stem = $(firstword $(subst _, ,$(notdir $(1))))

usage : # this happens when make is called with no arguments
	@echo "Usage:"
	@echo "    make hist"
	@echo "    make images"
	@echo "    make masks"
	@echo "    make keras"
	@echo ""
	@echo "Set the optional arguments CHARACTERS, COLORS, STAGES,"
	@echo "  and ORIENTATIONS to limit the scope of make."
	@echo ""
	@echo "Set the optional arguments HISTDIR, IMAGEDIR, and MASKDIR"
	@echo "  to change the destination of results."
	@echo ""
	@echo "Current directories are:"
	@echo "  HISTDIR="$(HISTDIR)
	@echo "  IMAGEDIR="$(IMAGEDIR)
	@echo "  MASKDIR="$(MASKDIR)
	@echo ""
	@echo "Current scope is:"
	@echo "  CHARACTERS="$(CHARACTERS)
	@echo "  COLORS="$(COLORS)
	@echo "  STAGES="$(STAGES)
	@echo "  ORIENTATIONS="$(ORIENTATIONS)

$(MAKEABLE_DIRS) :
	mkdir -p $@

dirs : $(MAKEABLE_DIRS)

# avi stuff

$(SCRIPTDIR)/setup_files_logic.sh : $(dtm_setup_files) | $(SETUPFILESDIR)
	touch $@

%_setup_files_list : $(SCRIPTDIR)/setup_files_logic.sh
	$(BASH) $< $@ >$@

%_setup_moves_list : $(SCRIPTDIR)/setup_moves_logic.sh
	$(BASH) $< $@ >$@

%_files_prefix_count : %_setup_files_list
	cat $< | xargs grep -v '^#' | wc -l >$@

$(COMPILEMOVESDIR)/%_frames_specific.csv :
	$(error ERROR: you must place $(call char_name_from_stem,$*) \
		specific frame data in $(@F) and place it in $(@D) to \
		proceed)

$(COMPILEMOVESDIR)/%_frames.csv : $(COMPILEMOVESDIR)/character_frames_compile.sql \
				  $(COMPILEMOVESDIR)/character_frames_universal.csv \
				  $(COMPILEMOVESDIR)/%_frames_specific.csv
	{ echo ".mode csv" ; \
	  echo ".headers on" ; \
	  echo ".import $(word 2,$^) universal_frames" ; \
	  echo ".import $(word 3,$^) specific_frames" ; \
	  cat $< ; } | $(SQLITE) >$@

$(COMPILEMOVESDIR)/dtm_inputs.csv : $(COMPILEMOVESDIR)/dtm_inputs_compile.sql \
				    $(COMPILEMOVESDIR)/dtm_inputs_yes_orientation.csv \
				    $(COMPILEMOVESDIR)/dtm_inputs_no_orientation.csv
	{ echo ".mode csv" ; \
	  echo ".headers on" ; \
	  echo ".import $(word 2,$^) yes_orientation" ; \
	  echo ".import $(word 3,$^) no_orientation" ; \
	  cat $< ; } | $(SQLITE) >$@

%_moves_prefix_count : $(SCRIPTDIR)/compile_moves.py \
		       $(COMPILEMOVESDIR)/$$(call char_name_from_stem,$$*)_frames.csv \
		       $(COMPILEMOVESDIR)/dtm_inputs.csv \
		       %_setup_moves_list
	$(PYTHON) $< $(wordlist 2,3,$^) @$(word 4,$^) | wc -l >$@

%_total_moves_count : $(SCRIPTDIR)/compile_moves.py \
		      $(COMPILEMOVESDIR)/$$(call char_name_from_stem,$$*)_frames.csv \
		      $(COMPILEMOVESDIR)/dtm_inputs.csv \
		      %_setup_moves_list \
		      $(MOVES_LIST) $(MOVES_LIST)
	$(PYTHON) $< $(wordlist 2,3,$+) \
		     $(patsubst %,@%,$(wordlist 4,6,$+)) | wc -l >$@

%_prefix_sec : $(SCRIPTDIR)/time_arithmetic.sh %_files_prefix_count \
	       %_moves_prefix_count
	$(BASH) $< $(wordlist 2,$(words $^),$^) >$@

%_recording_sec : $(SCRIPTDIR)/time_arithmetic.sh %_files_prefix_count \
		  %_moves_prefix_count %_total_moves_count
	DENOM=120 $(BASH) $< $(wordlist 2,$(words $^),$^) >$@

%.dtm : %_setup_files_list $(SCRIPTDIR)/compile_moves.py \
	$(COMPILEMOVESDIR)/$$(call char_name_from_stem,$$*)_frames.csv \
	$(COMPILEMOVESDIR)/dtm_inputs.csv \
	%_setup_moves_list $(MOVES_LIST) $(MOVES_LIST) \
	$(RECORDAVIDIR)/melee_header
	{ cat $(word 1,$+) | xargs cat ; \
	  $(PYTHON) $(word 2,$+) $(wordlist 3,4,$+) \
	    $(patsubst %,@%,$(wordlist 5,7,$+)); \
	} | $(TEXT2DTM) $@ $(word 8,$+) -

$(RECORDAVIDIR)/Super_Smash_Bros._Melee_(v1.02).iso :
	$(error ERROR: you must legally obtain a copy of $(@F) and place \
		it in $(@D) to proceed)

# This should be a static pattern rule, instead of just an implicit rule.
# That way, if Make fails because it can't find the iso, then it will
# give the iso error message, instead of giving the "no rule to make
# target" message used when it can't find a chain of implicit rules.
$(bg_avis) $(mask_avis) $(hist_avis) : %.avi : \
	$(SCRIPTDIR)/record_avi.sh \
	$(RECORDAVIDIR)/Super_Smash_Bros._Melee_(v1.02).iso \
	%.dtm \
	%_recording_sec
	$(BASH) $< $@ $(DOLPHIN) "$(word 2,$^)" $(word 3,$^) $$(cat $(word 4,$^))

# Making the previous implicit rule into a static pattern rule also
# tells Make to treat %.dtm and %_recording_sec as non-intermediate.
# Unfortunately, this doesn't work:
# .INTERMEDIATE : %.dtm %_recording_sec
# Instead we have to explicitly specify the intermediate targets.
bg_dtms := $(addprefix $(IMAGEDIR)/,\
	     $(addsuffix .dtm,\
	       $(bg_stems)))
bg_recs := $(addprefix $(IMAGEDIR)/,\
	     $(addsuffix _recording_sec,\
	       $(bg_stems)))
.INTERMEDIATE : $(bg_dtms) $(bg_recs)

mask_dtms := $(addprefix $(MASKDIR)/,\
	       $(addsuffix .dtm,\
		 $(mask_stems)))
mask_recs := $(addprefix $(MASKDIR)/,\
	       $(addsuffix _recording_sec,\
		 $(mask_stems)))
.INTERMEDIATE : $(mask_dtms) $(mask_recs)

hist_dtms := $(addprefix $(HISTDIR)/,\
	       $(addsuffix .dtm,\
		 $(hist_stems)))
hist_recs := $(addprefix $(HISTDIR)/,\
	       $(addsuffix _recording_sec,\
		 $(hist_stems)))
.INTERMEDIATE : $(hist_dtms) $(hist_recs)

image_movies : $(bg_avis)
mask_movies : $(mask_avis)
hist_movies : $(hist_avis)

# image stuff

.PRECIOUS : %_001.jpg

%_001.jpg : %_prefix_sec %.avi
	find $(@D) -iname $(*F)_[0-9][0-9][0-9].jpg -exec rm '{}' +
	$(FFMPEG) -nostats -hide_banner -loglevel panic \
	  -ss $$(cat $(word 1,$^)) \
	  -i $(word 2,$^) \
	  -vf framestep=step=10 \
	  $(@D)/$(*F)_%03d.jpg

%_image_list : %_001.jpg
	find $(abspath $(@D)) -iname $(*F)_[0-9][0-9][0-9].jpg >$@

$(IMAGEDIR)/image_list : $(bg_images) | $(IMAGEDIR)
	cat $+ >$@

images : $(IMAGEDIR)/image_list

# histogram stuff

$(HISTDIR)/hist_header.csv : $(SCRIPTDIR)/process_images.py | $(HISTDIR)
	$(PYTHON) $< --header >$@

.PRECIOUS : %_hist.csv

%_hist.csv : $(HISTDIR)/hist_header.csv \
	     $(SCRIPTDIR)/process_images.py \
	     %_image_list
	cat $< >$@
	$(PYTHON) $(word 2,$^) @$(word 3,$^) >>$@

$(HISTDIR)/hist.csv : $(HISTDIR)/hist_header.csv $(hist_csvs) | $(HISTDIR)
	cat $< >$@
	printf "%s\n" $(wordlist 2,$(words $^),$^) | \
	  xargs -L 1 sed -e '1 d' >>$@

hist : $(HISTDIR)/hist.csv

# mask stuff

.PRECIOUS : $(MASKDIR)/%_001_mask.jpg

$(MASKDIR)/%_001_mask.jpg : $(SCRIPTDIR)/process_masks.py \
			    $(HISTDIR)/%_hist.csv \
			    $(MASKDIR)/%_image_list \
			    | $(MASKDIR)
	find $(@D) -iname $(*F)_[0-9][0-9][0-9]_mask.jpg -exec rm '{}' +
	$(PYTHON) $(word 1,$^) $(@D) $(word 2,$^) @$(word 3,$^)

%_mask_list : %_001_mask.jpg
	find $(abspath $(@D)) -iname $(*F)_[0-9][0-9][0-9]_mask.jpg >$@

$(MASKDIR)/mask_list : $(mask_masks) | $(MASKDIR)
	cat $+ >$@

masks : $(MASKDIR)/mask_list

# keras folder stuff

$(KERASDIR)/labelled_image_list : $(IMAGEDIR)/image_list | $(KERASDIR)
	sed -e 's|.*/\(.*\).jpg|\1 &|' -e 's/_bg_on//' <$< >$@

$(KERASDIR)/labelled_mask_list : $(MASKDIR)/mask_list | $(KERASDIR)
	sed -e 's|.*/\(.*\)_mask.jpg|\1 &|' -e 's/_bg_off//' <$< >$@

$(KERASDIR)/labelled_image_mask_list : $(KERASDIR)/labelled_image_list \
			      	       $(KERASDIR)/labelled_mask_list \
			      	       | $(KERASDIR)
	join $+ >$@

$(KERASDIR)/shuffled_image_mask_list : $(SCRIPTDIR)/random_shuffle.sh \
				       $(KERASDIR)/labelled_image_mask_list \
				       | $(KERASDIR)
	$(BASH) $< $(word 2,$^) | cut -d' ' -f 2- >$@

keras_folder_lists := $(addprefix \
			$(KERASDIR)/shuffled_image_mask_list_,\
			  train test valid)
$(keras_folder_lists) : $(SCRIPTDIR)/split_into_percentages.sh \
			$(KERASDIR)/shuffled_image_mask_list
	$(BASH) $< $(word 2,$^) test 10 valid 20 train

$(KERASDIR)/%_done : $(KERASDIR)/shuffled_image_mask_list_%
	rm -rf $(@D)/$*
	mkdir -p $(@D)/$*/images/dummy $(@D)/$*/masks/dummy
	cut -d' ' -f 1 $< | xargs ln -s -t $(@D)/$*/images/dummy
	cut -d' ' -f 2 $< | xargs ln -s -t $(@D)/$*/masks/dummy
	touch $@

$(KERASDIR)/folders_done : $(KERASDIR)/train_done \
			   $(KERASDIR)/test_done \
			   $(KERASDIR)/valid_done
	touch $@

keras : $(KERASDIR)/folders_done
