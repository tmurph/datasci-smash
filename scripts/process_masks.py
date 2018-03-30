import os
import sys
import argparse
import re
from itertools import groupby

import numpy as np
import pandas as pd
import cv2

int8_max = 255

hue_chan = 0
hue_min = 0
hue_max = 180

img_re = re.compile('(?:[^/]*/)*'
                    '(?P<character>[^_]*)_'
                    '(?P<color>[^_]*)_'
                    '(?P<stage>[^_]*)_'
                    '(?P<orientation>[^_]*)_'
                    'bg_(?P<background>[^_]*)_'
                    '(?P<number>[0-9]{3})'
                    '.jpg')


def writeable_dir(prospective_dir):
    if not os.path.isdir(prospective_dir):
        raise Exception(f"{prospective_dir} is not a valid path")
    if not os.access(prospective_dir, os.W_OK):
        raise Exception(f"{prospective_dir} is not a writeable dir")
    return prospective_dir


class CharacterColorHistogram():


    def __init__(self, master_hist):
        # Reduce the master hue histogram to character/color averages
        cha_col_df = master_hist.drop(
            ['stage', 'orientation', 'number'], axis=1)
        h_cols = cha_col_df.columns.str.contains('H')
        h_total = cha_col_df.iloc[:, h_cols].sum(axis=1)

        cha_col_df = cha_col_df.loc[h_total > 0]
        h_total = h_total.loc[h_total > 0]

        cha_col_df.iloc[:, h_cols] = cha_col_df.iloc[:, h_cols].divide(
            h_total, axis='index')
        agg_df = cha_col_df.groupby(['character', 'color']).agg(np.mean)

        self._aggregate_df = agg_df


    def histogram(self, character, color):
        float_hist = self._aggregate_df.loc[character, color].values
        float_hist = float_hist.reshape(len(float_hist), 1)
        back_proj_hist = cv2.normalize(float_hist, float_hist,
                                       alpha=0, beta=int8_max,
                                       norm_type=cv2.NORM_MINMAX,
                                       dtype=cv2.CV_8U)
        back_proj_hist = back_proj_hist.reshape(len(back_proj_hist))
        return back_proj_hist


def cutoff_thresh(hist, percentage=0.55):
    "Determine a threshold to select the top percentage of HIST."
    total_area = hist.sum()
    result = 0
    for x in range(hist.max(), 0, -1):
        cutoff_area = sum(map(lambda e: max(e - x, 0), hist))
        if cutoff_area > total_area * percentage:
            result = x
            break
    return result


def mask_from_image(hsv_img, back_proj_hist, thresh,
                    hsv_min=np.array([0, 50, 50]),
                    hsv_max=np.array([179, 255, 255]),
                    blur_size=11):
    """Calculate a greyscale ROI mask from HSV_IMG.

Backproject the hues of HSV_IMG according to BACK_PROJ_HIST and cut off
the backprojection at THRESH.  In case multiple regions survive the
cutoff, select the region with the largest area.

    """
    # backproject hues, but mask out pixels with little saturation/value
    hsv_mask = cv2.inRange(hsv_img, hsv_min, hsv_max)
    h_img = hsv_img[:, :, hue_chan]
    back_proj = back_proj_hist[h_img.ravel()].reshape(h_img.shape)
    back_proj &= hsv_mask

    # theshold and select largest region
    _, thresh_img = cv2.threshold(back_proj, thresh, int8_max,
                                  cv2.THRESH_BINARY)
    blur_img = cv2.GaussianBlur(thresh_img, (blur_size, blur_size),
                                cv2.BORDER_CONSTANT)
    _, contours, _ = cv2.findContours(blur_img, cv2.RETR_EXTERNAL,
                                      cv2.CHAIN_APPROX_SIMPLE)
    contours = sorted(contours, key=cv2.contourArea, reverse=True)

    # calculate greyscale mask
    if contours:
        large_contour = contours[0]
        final_mask = cv2.drawContours(np.zeros(blur_img.shape,
                                               dtype=np.uint8),
                                      contours,
                                      contourIdx=0,
                                      color=int8_max,
                                      thickness=cv2.FILLED)
        final_mask &= blur_img
    else:
        final_mask = np.zeros(blur_img.shape)

    return final_mask


def main(argv=None):
    if argv is None:
        argv = sys.argv

    description = ('Process images to masks.')
    parser = argparse.ArgumentParser(description=description,
                                     fromfile_prefix_chars='@')
    parser.add_argument('outdir', type=writeable_dir,
                        help='directory to place mask images')
    parser.add_argument('hist', type=argparse.FileType(),
                        help='CSV of backprojection hue histograms')
    parser.add_argument('image', nargs='+', help='images to process')

    args = parser.parse_args(argv[1:])

    image_name_lst = args.image
    outdir = args.outdir
    master_hist_df = pd.read_csv(args.hist)

    character_colors = CharacterColorHistogram(master_hist_df)

    for image_name in image_name_lst:
        match = re.search(img_re, image_name)
        if match:
            character = match.group('character')
            color = int(match.group('color'))

            hsv_img = cv2.cvtColor(cv2.imread(image_name),
                                   cv2.COLOR_BGR2HSV)
            back_proj_hist = character_colors.histogram(character, color)
            optimal_thresh = cutoff_thresh(back_proj_hist)

            mask_image = mask_from_image(hsv_img,
                                         back_proj_hist,
                                         optimal_thresh)
            mask_image_name = ('{character}_'
                               '{color}_'
                               '{stage}_'
                               '{orientation}_'
                               'bg_{background}_'
                               '{number}_'
                               'mask.jpg').format(**match.groupdict())
            cv2.imwrite(os.path.join(outdir, mask_image_name), mask_image)


if __name__ == '__main__':
    sys.exit(main())
