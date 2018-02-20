PYTHON := python3
TEXT2DTM := text2dtm
FFMPEG := ffmpeg

SCRIPTDIR := scripts
SETUPFILESDIR := $(SCRIPTDIR)/setup_files
COMPILEMOVESDIR := $(SCRIPTDIR)/compile_moves
RECORDAVIDIR := $(SCRIPTDIR)/record_avi
IMAGEDIR := images
DATADIR := data

CHARACTERS := falco falcon fox jigglypuff marth peach samus sheik
COLORS := 0 1 2 3 4
STAGES := final fountain stadium story battlefield dreamland
ORIENTATIONS := left right
BACKGROUNDS := on off

targets := $(foreach char,$(CHARACTERS),\
	    $(foreach col,$(COLORS),\
		$(foreach st,$(STAGES),\
		    $(foreach ori,$(ORIENTATIONS),\
			$(foreach bg,$(BACKGROUNDS),\
			    $(char)_$(col)_$(st)_$(ori)_bg_$(bg))))))

all : $(DATADIR)/hist.csv

$(IMAGEDIR) $(DATADIR) :
	mkdir $@

# need to list the setup files
# to get the right error message if they dont exist
$(SCRIPTDIR)/setup_files_logic.sh : | $(SETUPFILESDIR)

%_setup_files_list : $(SCRIPTDIR)/setup_files_logic.sh
	$< $@ >$@

%_setup_moves_list : $(SCRIPTDIR)/setup_moves_logic.sh
	$< $@ >$@

%_files_prefix_count : %_setup_files_list
	cat $< | xargs grep -v '^#' | wc -l >$@

$(SCRIPTDIR)/compile_moves.py : $(COMPILEMOVESDIR)/character_frames.csv
$(SCRIPTDIR)/compile_moves.py : $(COMPILEMOVESDIR)/dtm_inputs.csv

%_moves_prefix_count : $(SCRIPTDIR)/compile_moves.py %_setup_moves_list
	$(PYTHON) $(word 1,$^) @$(word 2,$^) | wc -l >$@

%_total_moves_count : $(SCRIPTDIR)/compile_moves.py %_setup_moves_list moves_list moves_list
	$(PYTHON) $(word 1,$+) \
	  $(patsubst %,@%,$(wordlist 2,$(words $+),$+)) | wc -l >$@

%_prefix_sec : $(SCRIPTDIR)/time_arithmetic.sh %_files_prefix_count %_moves_prefix_count
	$< $(wordlist 2,$(words $^),$^) >$@

%_recording_sec : $(SCRIPTDIR)/time_arithmetic.sh %_files_prefix_count %_moves_prefix_count %_total_moves_count
	DENOM=120 $< $(wordlist 2,$(words $^),$^) >$@

%.dtm : %_setup_files_list $(SCRIPTDIR)/compile_moves.py %_setup_moves_list moves_list moves_list melee_header
	{ cat $(word 1,$+) | xargs cat ; \
	  $(PYTHON) $(word 2,$+) $(patsubst %,@%,$(wordlist 3,5,$+)); \
	} | $(TEXT2DTM) $@ $(word 6,$+) -

# sure would be nice to list the dolphin dependencies somehow
$(SCRIPTDIR)/record_avi.sh : $(RECORDAVIDIR)/Super\ Smash\ Bros.\ Melee\ (v1.02).iso

%.avi : $(SCRIPTDIR)/record_avi.sh %.dtm %_recording_sec
	$< $@ $(word 2,$^) $$(cat $(word 3,$^))

.PRECIOUS : $(IMAGEDIR)/%_images

$(IMAGEDIR)/%_images : %_prefix_sec %.avi | $(IMAGEDIR)
	find $(@D) -iname $(*F)_\*.jpg -exec rm '{}' +
	$(FFMPEG) -nostats -hide_banner -loglevel panic \
	  -ss $$(cat $(word 1,$^)) \
	  -i $(word 2,$^) \
	  -vf framestep=step=10 \
	  $*_%03d.jpg
	find $(@D) -iname $(*F)_\*.jpg >$@

$(DATADIR)/hist_header.csv : $(SCRIPTDIR)/process_images.py | $(DATADIR)
	$(PYTHON) $< --header >$@

$(DATADIR)/%_hist.csv : $(SCRIPTDIR)/process_images.py $(IMAGEDIR)/%_images | $(DATADIR)
	$(PYTHON) $(word 1,$^) @$(word 2,$^) >$@

histograms := $(addprefix $(DATADIR)/,$(addsuffix _hist.csv,$(targets)))
$(DATADIR)/hist.csv : $(DATADIR)/hist_header.csv $(histograms) | $(DATADIR)
	cat $+ >$@
