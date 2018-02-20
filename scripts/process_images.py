import sys
import argparse
import re
import numpy as np

import cv2


def main(argv=None):
    if argv is None:
        argv = sys.argv

    description = ('Process images to CSV.')
    parser = argparse.ArgumentParser(description=description,
                                     fromfile_prefix_chars='@')
    parser.add_argument('image', nargs='*', help='images to process')
    parser.add_argument('--header', action='store_true',
                        help='include header line')

    args = parser.parse_args(argv[1:])

    image_lst = args.image

    if args.header:
        titles = ['character', 'color', 'stage', 'orientation', 'number']
        titles += [f'H{i:03d}' for i in range(180)]
        print(*titles, sep=',')

    img_re = ('(?:[^/]*/)*'
              '(?P<character>[^_]*)_'
              '(?P<color>[^_]*)_'
              '(?P<stage>[^_]*)_'
              '(?P<orientation>[^_]*)_'
              'bg_off_'
              '(?P<number>[0-9]{3})'
              '.jpg')
    for image in image_lst:
        match = re.search(img_re, image)
        if match:
            hsv_img = cv2.cvtColor(cv2.imread(image),
                                   cv2.COLOR_BGR2HSV)
            # filter out stuff near the "origin"
            # a/k/a black, white, and some gray
            min_hsv = np.array([0, 10, 10])
            max_hsv = np.array([179, 255, 255])
            hsv_mask = cv2.inRange(hsv_img, min_hsv, max_hsv)
            # calculate histogram of hues (channel 0 in the HSV image)
            hist = cv2.calcHist([hsv_img], [0], hsv_mask, [180], [0, 180])
            flat_hist = hist.astype(int).flatten()
            print(*match.groups(), *flat_hist, sep=',')

    return 0


if __name__ == '__main__':
    sys.exit(main())
