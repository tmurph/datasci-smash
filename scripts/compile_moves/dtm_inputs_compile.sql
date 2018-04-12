select Move, "left" as Orientation, Step, DTM
from no_orientation
union all
select Move, "right" as Orientation, Step, DTM
from no_orientation
union all
select Move, Orientation, Step, DTM
from yes_orientation
;
