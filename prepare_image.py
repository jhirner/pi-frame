#!/usr/bin/python

# Import the required libraries
from PIL import Image
from PIL import ImageFont
from PIL import ImageDraw 

class Processor():
    def __init__(self, img_path = None, display_width = None, display_height = None, textmsg = None, padding_color = (0, 0, 0)):
        self.img = Image.open(img_path)
        self.display_width = display_width
        self.display_height = display_height
        self.textmsg = textmsg
        self.padding_color = padding_color

    def process(self):
        # Manages the overall preparation of the image, from scaling, overlaying
        # an optional text warning, and flipping the image horizontally.
        # Note that in the absence of a flip, the image & optional text are displayed
        # mirrored backwards.
        self.img = self.scale(self.img)
        self.img = self.center(self.img)
        if self.textmsg is not None and len(self.textmsg) > 1:
            self.img = self.add_text(self.img)
        self.img = self.img.transpose(method=Image.Transpose.FLIP_LEFT_RIGHT)

    def scale(self, img):
        # Resizes the image to fit the display without distorting the original aspect ratio
        # For portrait orientation images, scale to the screen height.
        # Otherwise, scale to the screen width.
        if self.display_width / self.display_height > img.width / img.height:
            new_width = img.width * self.display_height / img.height
            new_height = self.display_height
        else:
            new_width = self.display_width
            new_height = img.height * self.display_width / img.width

        img = img.resize((int(new_width),
                          int(new_height)))

        return img

    def add_text(self, img):
        font = ImageFont.truetype("Pillow/Tests/fonts/FreeMono.ttf", 36)
        draw = ImageDraw.Draw(img)
        draw.rectangle([(0,0), (img.width,75)],
                       fill = 0,
                       outline = None)
        draw.text((10, 30), self.textmsg, font=font, fill=(255, 255, 255))

        return img

    def center(self, img):
        # Center the image in the display, as not all images will fill it.
        padded = Image.new(img.mode, (self.display_width, self.display_height), self.padding_color)
        x_offset = int((self.display_width - img.width) / 2)
        y_offset = int((self.display_height - img.height) / 2)
        padded.paste(img, (x_offset, y_offset))

        return padded
