.mode csv
.import dtm_inputs_no_orientation.csv no_orientation
.import dtm_inputs_yes_orientation.csv yes_orientation

.headers on
.output dtm_inputs.csv

select Move, "left" as Orientation, Step, DTM
from no_orientation
union all
select Move, "right" as Orientation, Step, DTM
from no_orientation
union all
select Move, Orientation, Step, DTM
from yes_orientation
;
