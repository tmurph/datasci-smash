import sys
import argparse

import cv2

non_zero = 1
int8_max = 255

def within_proportions_p(mask, min_prop=0, max_prop=1):
    "Return True if the white space of MASK is at least MIN_PROP and at most MAX_PROP of the image."
    result = False
    non_zero = 1

    _, thresh_img = cv2.threshold(mask, non_zero, int8_max,
                                  cv2.THRESH_BINARY)
    _, contours, _ = cv2.findContours(thresh_img, cv2.RETR_EXTERNAL,
                                      cv2.CHAIN_APPROX_SIMPLE)
    if contours:
        roi_area = max(cv2.contourArea(c) for c in contours)


    return result

def main(argv=None):
    if argv is None:
        argv = sys.argv

    description = ('Remove mask filenames that meet criteria.')
    parser = argparse.ArgumentParser(description=description,
                                     fromfile_prefix_chars='@')
    parser.add_argument('--min-proportion', type=float, default=0.01,
                        metavar="FLOAT",
                        help=('minimum proportion of the image that the'
                              ' mask must occupy (default 0.01)'))
    parser.add_argument('--max-proportion', type=float, default=0.07,
                        metavar="FLOAT",
                        help=('maximum proportion of the image that the'
                              ' mask may occupy (default 0.07)'))
    parser.add_argument('--max-rectangle', type=float, default=3,
                        metavar="FLOAT",
                        help=('maximum bounding box rectangular ratio'
                              ' (larger of h/w and w/h) that the mask'
                              ' must fit into (default 3)'))
    parser.add_argument('mask', nargs='+', help='masks to filter')

    args = parser.parse_args(argv[1:])

    mask_name_lst = args.mask

    for mask_name in mask_name_lst:
        tests = []
        mask_img = cv2.cvtColor(cv2.imread(mask_name), cv2.COLOR_BGR2GRAY)

        _, thresh_img = cv2.threshold(mask_img, non_zero, int8_max,
                                      cv2.THRESH_BINARY)
        _, contours, _ = cv2.findContours(thresh_img, cv2.RETR_EXTERNAL,
                                          cv2.CHAIN_APPROX_SIMPLE)
        tests.append(contours)  # false if no contours

        if contours:
            biggest_contour = sorted(contours, key=cv2.contourArea,
                                     reverse=True)[0]
            roi_area = cv2.contourArea(biggest_contour)
            mask_area = mask_img.shape[0] * mask_img.shape[1]
            prop_area = roi_area / mask_area
            tests.append(args.min_proportion <= prop_area)
            tests.append(prop_area <= args.max_proportion)

            _, _, w, h = cv2.boundingRect(biggest_contour)
            rect_ratio = w / h if w > h else h / w
            tests.append(rect_ratio <= args.max_rectangle)

        if all(tests):
            print(mask_name)

if __name__ == '__main__':
    sys.exit(main())
