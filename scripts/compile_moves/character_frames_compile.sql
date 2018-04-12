with distinct_characters as (
    select distinct Character
    from specific_frames
)

, all_universal_frames as (
    select d.Character, u.Move, u.Frames
    from distinct_characters as d
    left join universal_frames as u
)

select Character, Move, Frames
from specific_frames
union all
select Character, Move, Frames
from all_universal_frames
;
