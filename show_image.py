#!/usr/bin/python

# Import required modules
from omni_epd import displayfactory
from prepare_image import Processor
from argparse import ArgumentParser

# Handle argument parsing
parser = ArgumentParser()
parser.add_argument("image_file_path", help = "Path to the image to display")
parser.add_argument("--message", "-m", help = "Banner text do overlay on top of the image")
args = parser.parse_args()

# Instantiate the display
epd = displayfactory.load_display_driver("waveshare_epd.it8951")
epd.prepare()
print("show_image.py: Prepared display.")

# Prepare the image
proc = Processor(img_path = args.image_file_path,
                 display_width = epd.width,
                 display_height = epd.height,
                 textmsg = args.message)
proc.process()
print("show_image.py: Prepared image.")

# Show the image and close out the display
epd.display(proc.img)
epd.close()
print("show_image.py: Updated display & exiting.")
