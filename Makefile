# I've been using the following to get specialty histograms
# make hist MOVES_LIST=reference_moves_list
# make images masks
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
bg_targets := $(addprefix $(IMAGEDIR)/,\
		$(addsuffix _images,\
		  $(bg_stems)))

nobg_stems := $(addsuffix _bg_off,$(stem_roots))
nobg_targets := $(addprefix $(NOBG_IMAGEDIR)/,\
		  $(addsuffix _images,\
		    $(nobg_stems)))

hist_stems := $(nobg_stems)
hist_targets := $(addprefix $(HISTDIR)/,\
		  $(addsuffix _hist.csv,\
		    $(hist_stems)))

mask_stems := $(nobg_stems)
mask_targets := $(addprefix $(MASKDIR)/,\
	   	  $(addsuffix _masks,\
	     	    $(mask_stems)))

usage : # this happens when make is called with no arguments
	@echo "Usage:"
	@echo "    make hist"
	@echo "    make images"
	@echo "    make masks"
	@echo "    make all (alias for the previous three)"
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

$(IMAGEDIR) $(NOBG_IMAGEDIR) $(HISTDIR) $(MASKDIR) :
	mkdir -p $@

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

$(HISTDIR)/hist_header.csv : $(SCRIPTDIR)/process_images.py | $(HISTDIR)
	$(PYTHON) $< --header >$@

.PRECIOUS : $(HISTDIR)/%_hist.csv

%_hist.csv : $(HISTDIR)/hist_header.csv \
	     $(SCRIPTDIR)/process_images.py \
	     %_images \
	     | $(HISTDIR)
	cat $< >$@
	$(PYTHON) $(word 2,$^) @$(word 3,$^) >>$@

%_001.jpg : %_prefix_sec %.avi
	find $(@D) -iname $(*F)_\*.jpg -exec rm '{}' +
	$(FFMPEG) -nostats -hide_banner -loglevel panic \
	  -ss $$(cat $(word 1,$^)) \
	  -i $(word 2,$^) \
	  -vf framestep=step=10 \
	  $(@D)/$(*F)_%03d.jpg

.PRECIOUS : %_images

$(bg_targets) $(nobg_targets) : %_images : %_001.jpg
	find $(@D) -iname $(*F)_\*.jpg >$@

.PRECIOUS : $(HISTDIR)/%_images

$(HISTDIR)/%_images : $(NOBG_IMAGEDIR)/%_images
	find $(<D) -iname $(*F)_\*.jpg >$@

$(MASKDIR)/%_001_mask.jpg : $(SCRIPTDIR)/process_masks.py \
			    $(HISTDIR)/%_hist.csv \
			    $(NOBG_IMAGEDIR)/%_images \
			    | $(MASKDIR)
	find $(@D) -iname $(*F)_\*.jpg -exec rm '{}' +
	$(PYTHON) $(word 1,$^) $(@D) $(word 2,$^) @$(word 3,$^)

.PRECIOUS : %_masks

%_masks : %_001_mask.jpg
	find $(@D) -iname $(*F)_\*.jpg >$@

$(HISTDIR)/hist.csv : $(HISTDIR)/hist_header.csv $(hist_targets) \
		      | $(HISTDIR)
	cat $< >$@
	printf "%s\n" $(wordlist 2,$(words $^),$^) | \
	  xargs -L 1 sed -e '1 d' >>$@

$(IMAGEDIR)/images : $(bg_targets) | $(IMAGEDIR)
	cat $+ >$@

$(NOBG_IMAGEDIR)/images : $(nobg_targets) | $(NOBG_IMAGEDIR)
	cat $+ >$@

$(MASKDIR)/masks : $(mask_targets) | $(MASKDIR)
	cat $+ >$@

hist : $(HISTDIR)/hist.csv

images : $(IMAGEDIR)/images

masks : $(MASKDIR)/masks

all : hist images masks
