import sys
import argparse
import re
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

class Image():
    def __init__(self, img_name):
        match = img_re.search(img_name)
        if match:
            self._match = match
            for k, v in match.groupdict():
                setattr(self, k, v)
            self._hsv_img = cv2.cvtColor(cv2.imread(img_name),
                                         cv2.COLOR_BGR2HSV)
        else:
            raise RuntimeError("Image object requires a filename like"
                               "{character}_{color}_{stage}_"
                               "{left/right}_bg_{on/off}_{number}.jpg"
                               "\n\n"
                               f"Received {img_name}")

    @staticmethod
    def index_names():
        return [img_re.groupindex.keys()]

    @staticmethod
    def hist_names():
        return [f'H{i:03d}' for i in range(hue_max)]

    def simple_mask(self, hsv_min=np.array([0, 50, 50]),
                    hsv_max=np.array([179, 255, 255])):
        return cv2.inRange(self._hsv_img, hsv_min, hsv_max)

    def index(self):
        return self._match.groupdict().values()

    def hist(self, hsv_min=np.array([0, 50, 50]),
             hsv_max=np.array([179, 255, 255])):
        hsv_img = self._hsv_img
        hsv_mask = self.simple_mask(hsv_min, hsv_max)
        raw_hist = cv2.calcHist([hsv_img], [hue_chan], hsv_mask,
                                [hue_max], [hue_min, hue_max])
        flat_hist = raw_hist.astype(int).flatten()
        return flat_hist

    def back_proj_mask(self, back_proj_hist, thresh, blur_size=11):
        h_img = self._hsv_img[:, :, hue_chan]
        back_proj = back_proj_hist[h_img.ravel()].reshape(h_img.shape)
        back_proj &= self.simple_mask()

        _, thresh_img = cv2.threshold(back_proj, thresh, int8_max,
                                      cv2.THRESH_BINARY)
        blur_img = cv2.GaussianBlur(thresh_img, (blur_size, blur_size),
                                    0)
        _, contours, _ = cv2.findContours(blur_img, cv2.RETR_EXTERNAL,
                                          cv2.CHAIN_APPROX_SIMPLE)
        contours = sorted(contours, key=cv2.contourArea, reverse=True)

        if contours:
            large_contour = contours[0]
            x, y, w, h = cv2.boundingRect(large_contour)
            final_mask = cv2.rectangle(np.zeros(blur_img.shape,
                                                dtype=np.uint8),
                                       (x, y), (x + w, y + h),
                                       int8_max, thickness=cv2.FILLED)
            final_mask &= blur_img
        else:
            final_mask = np.zeros(blur_img.shape)

        return final_mask


class Aggregator():

    def __init__(self, images):
        self._images = images
        column_names = Image.index_names() + Image.hist_names()


    @classmethod
    def from_img_list(cls, img_list):
        return cls([Image(img) for img in img_list])

# this is so broken it's awful
# def hist_from_img(img_name, agg_df):
#     target_hist = agg_df.loc[character, color].values.reshape(180, 1)
#     norm_hist = cv2.normalize(target_hist, target_hist, 0, 255,
#                             cv2.NORM_MINMAX, cv2.CV_8U)
#     return norm_hist


def main(argv=None):
    if argv is None:
        argv = sys.argv

    description = ('Process images to masks.')
    parser = argparse.ArgumentParser(description=description,
                                     fromfile_prefix_chars='@')
    parser.add_argument('image', nargs='*', help='images to process')

    args = parser.parse_args(argv[1:])

    image_lst = args.image

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
