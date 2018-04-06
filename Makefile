BASH := /bin/bash
PYTHON := ../bin/python3
TEXT2DTM := text2dtm
FFMPEG := ffmpeg

SCRIPTDIR := scripts
SETUPFILESDIR := $(SCRIPTDIR)/setup_files
COMPILEMOVESDIR := $(SCRIPTDIR)/compile_moves
RECORDAVIDIR := $(SCRIPTDIR)/record_avi

DATADIR := data
IMAGEDIR := $(DATADIR)/images
NOBG_IMAGEDIR := $(DATADIR)/images_nobg
HISTDIR := $(DATADIR)/hist
MASKDIR := $(DATADIR)/masks
KERASDIR := $(DATADIR)/keras

MAKEABLE_DIRS := $(IMAGEDIR) $(NOBG_IMAGEDIR) $(HISTDIR) $(MASKDIR) \
		 $(KERASDIR)

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

nobg_stems := $(addsuffix _bg_off,$(stem_roots))
nobg_images := $(addprefix $(NOBG_IMAGEDIR)/,\
		  $(addsuffix _image_list,\
		    $(nobg_stems)))

hist_stems := $(nobg_stems)
hist_images := $(addprefix $(HISTDIR)/,\
		 $(addsuffix _image_list,\
		   $(hist_stems)))
hist_csvs := $(addprefix $(HISTDIR)/,\
		  $(addsuffix _hist.csv,\
		    $(hist_stems)))

mask_stems := $(nobg_stems)
mask_masks := $(addprefix $(MASKDIR)/,\
	   	  $(addsuffix _mask_list,\
	     	    $(mask_stems)))

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
	@echo "Set the optional argument NOBG_IMAGEDIR to change the"
	@echo "  location of intermediate, no-background images. This"
	@echo "  option affects where \`make hist' and \`make masks'"
	@echo "  look for no-background images to process."
	@echo ""
	@echo "Current directories are:"
	@echo "  HISTDIR="$(HISTDIR)
	@echo "  IMAGEDIR="$(IMAGEDIR)
	@echo "  MASKDIR="$(MASKDIR)
	@echo "  NOBG_IMAGEDIR="$(NOBG_IMAGEDIR)
	@echo ""
	@echo "Current scope is:"
	@echo "  CHARACTERS="$(CHARACTERS)
	@echo "  COLORS="$(COLORS)
	@echo "  STAGES="$(STAGES)
	@echo "  ORIENTATIONS="$(ORIENTATIONS)

$(MAKEABLE_DIRS) :
	mkdir -p $@

# avi stuff

$(SCRIPTDIR)/setup_files_logic.sh : $(dtm_setup_files) | $(SETUPFILESDIR)

%_setup_files_list : $(SCRIPTDIR)/setup_files_logic.sh
	$< $@ >$@

%_setup_moves_list : $(SCRIPTDIR)/setup_moves_logic.sh
	$< $@ >$@

%_files_prefix_count : %_setup_files_list
	cat $< | xargs grep -v '^#' | wc -l >$@

$(SCRIPTDIR)/compile_moves.py : $(COMPILEMOVESDIR)/character_frames.csv \
				$(COMPILEMOVESDIR)/dtm_inputs.csv

%_moves_prefix_count : $(SCRIPTDIR)/compile_moves.py %_setup_moves_list
	$(PYTHON) $(word 1,$^) @$(word 2,$^) | wc -l >$@

%_total_moves_count : $(SCRIPTDIR)/compile_moves.py %_setup_moves_list \
		      $(MOVES_LIST) $(MOVES_LIST)
	$(PYTHON) $(word 1,$+) \
	  $(patsubst %,@%,$(wordlist 2,$(words $+),$+)) | wc -l >$@

%_prefix_sec : $(SCRIPTDIR)/time_arithmetic.sh %_files_prefix_count \
	       %_moves_prefix_count
	$< $(wordlist 2,$(words $^),$^) >$@

%_recording_sec : $(SCRIPTDIR)/time_arithmetic.sh %_files_prefix_count \
		  %_moves_prefix_count %_total_moves_count
	DENOM=120 $< $(wordlist 2,$(words $^),$^) >$@

%.dtm : %_setup_files_list $(SCRIPTDIR)/compile_moves.py \
	%_setup_moves_list $(MOVES_LIST) $(MOVES_LIST) \
	$(RECORDAVIDIR)/melee_header
	{ cat $(word 1,$+) | xargs cat ; \
	  $(PYTHON) $(word 2,$+) $(patsubst %,@%,$(wordlist 3,5,$+)); \
	} | $(TEXT2DTM) $@ $(word 6,$+) -

# sure would be nice to list the dolphin dependencies somehow
$(SCRIPTDIR)/record_avi.sh : $(RECORDAVIDIR)/Super\ Smash\ Bros.\ Melee\ (v1.02).iso

%.avi : $(SCRIPTDIR)/record_avi.sh %.dtm %_recording_sec
	$< $@ $(word 2,$^) $$(cat $(word 3,$^))

# image stuff

.PRECIOUS : %_001.jpg

%_001.jpg : %_prefix_sec %.avi
	find $(@D) -iname $(*F)_\*.jpg -exec rm '{}' +
	$(FFMPEG) -nostats -hide_banner -loglevel panic \
	  -ss $$(cat $(word 1,$^)) \
	  -i $(word 2,$^) \
	  -vf framestep=step=10 \
	  $(@D)/$(*F)_%03d.jpg

$(bg_images) $(nobg_images) : %_image_list : %_001.jpg
	find $(abspath $(@D)) -iname $(*F)_\*.jpg >$@

$(IMAGEDIR)/image_list : $(bg_images) | $(IMAGEDIR)
	cat $+ >$@

$(NOBG_IMAGEDIR)/image_list : $(nobg_images) | $(NOBG_IMAGEDIR)
	cat $+ >$@

images : $(IMAGEDIR)/image_list

# histogram stuff

$(HISTDIR)/hist_header.csv : $(SCRIPTDIR)/process_images.py | $(HISTDIR)
	$(PYTHON) $< --header >$@

$(HISTDIR)/%_001.jpg : $(NOBG_IMAGEDIR)/%_001.jpg
	find $(abspath $(<D)) -iname $(*F)_\*.jpg -exec ln -s -t $(@D) '{}' ';'

$(hist_images) : %_image_list : %_001.jpg
	find $(abspath $(@D)) -iname $(*F)_\*.jpg >$@

.PRECIOUS : $(HISTDIR)/%_hist.csv

%_hist.csv : $(HISTDIR)/hist_header.csv \
	     $(SCRIPTDIR)/process_images.py \
	     %_image_list \
	     | $(HISTDIR)
	cat $< >$@
	$(PYTHON) $(word 2,$^) @$(word 3,$^) >>$@

$(HISTDIR)/hist.csv : $(HISTDIR)/hist_header.csv $(hist_csvs) \
		      | $(HISTDIR)
	cat $< >$@
	printf "%s\n" $(wordlist 2,$(words $^),$^) | \
	  xargs -L 1 sed -e '1 d' >>$@

hist : $(HISTDIR)/hist.csv

# mask stuff

.PRECIOUS : $(MASKDIR)/%_001_mask.jpg

$(MASKDIR)/%_001_mask.jpg : $(SCRIPTDIR)/process_masks.py \
			    $(HISTDIR)/%_hist.csv \
			    $(NOBG_IMAGEDIR)/%_image_list \
			    | $(MASKDIR)
	find $(@D) -iname $(*F)_\*.jpg -exec rm '{}' +
	$(PYTHON) $(word 1,$^) $(@D) $(word 2,$^) @$(word 3,$^)

%_mask_list : %_001_mask.jpg
	find $(abspath $(@D)) -iname $(*F)_\*.jpg >$@

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
	$(BASH) $(word 1,$^) $(word 2,$^) | cut -d' ' -f 2- >$@

keras_folder_lists := $(addprefix \
			$(KERASDIR)/shuffled_image_mask_list_,\
			  train test valid)
$(keras_folder_lists) : $(SCRIPTDIR)/split_into_percentages.sh \
			$(KERASDIR)/shuffled_image_mask_list
	./$< $(word 2,$^) test 10 valid 20 train

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
