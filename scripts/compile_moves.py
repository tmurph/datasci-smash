import signal
import os
import sys
import argparse

import pandas as pd


# This script writes to stdout.  If I pipe to a program that doesn't
# read all the input, the script stops with a BrokenPipeError.  Per a
# stackoverflow answer, this results from normal pipe behavior plus
# Python's picky handling of the situation.  Solve by ignoring the
# error.

# https://stackoverflow.com/questions/14207708/ioerror-errno-32-broken-pipe-python
signal.signal(signal.SIGPIPE, signal.SIG_DFL)

inputs_per_frame = 4
input_padding = '0:0:0:0:0:0:0:0:0:0:0:0:0:0:128:128:128:128'
turnaround_moves = ['roll-forward', 'turn-around']

def get_input_frame(inputs, orientation):
    return inputs.xs(orientation, level='Orientation')['DTM']


def special_case_move_maybe(character, move):
    "Fix some special cases."
    # this is awful
    # a better solution will come to me later
    if character == 'samus' and move == 'neutral-b':
        move = 'charge-shot'
    elif character == 'peach' and move == 'down-b':
        move = 'turnip-throw'
    elif character == 'sheik' and move == 'down-b':
        move = 'stand-10'
    return move


def read_moves(character, move_list, frames, inputs,
               initial_orientation='right'):
    "Compile a list of moves to DTM text format."
    frame_series = frames.loc[character]['Frames']
    orientation = initial_orientation
    input_frame = get_input_frame(inputs, orientation)
    result = []
    for move in move_list:
        move = special_case_move_maybe(character, move)
        input_series = input_frame.loc[move]
        if move in turnaround_moves:
            orientation = 'left' if orientation == 'right' else 'right'
            input_frame = get_input_frame(inputs, orientation)
        frame_duration = frame_series.loc[move]
        for input_string in input_series:
            result.extend([input_string] * inputs_per_frame)
            frame_duration -= 1
        result.extend([input_padding] * inputs_per_frame * frame_duration)
    return '\n'.join(result)


def main(argv=None):
    if argv is None:
        argv = sys.argv

    description = ('Compile a list of character moves to plain text'
                   ' input data.')
    parser = argparse.ArgumentParser(description=description,
                                     fromfile_prefix_chars='@')
    parser.add_argument('frames', metavar='frame_data',
                        help='csv of Character,Move,Frames')
    parser.add_argument('inputs', metavar='dtm_inputs',
                        help='csv of Move,Orientation,Step,DTM')
    parser.add_argument('character', metavar='character')
    parser.add_argument('moves', metavar='move', nargs='+',
                        help='one move to compile;'
                        ' prefix with @ to use a from-file')

    args = parser.parse_args(argv[1:])

    # index on character, move
    character_frames = pd.read_csv(args.frames, index_col=[0, 1])
    # index on move, orientation, step number
    dtm_inputs = pd.read_csv(args.inputs, index_col=[0, 1, 2])


    print(read_moves(args.character, args.moves, character_frames,
                     dtm_inputs))

    return 0


if __name__ == '__main__':
    sys.exit(main())
