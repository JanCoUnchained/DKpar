#!/usr/bin/env python3


# use the python package textract
# to extract the text from all the pdfs we downloaded

import textract
import glob, os

files = glob.glob("data/pdf/*.pdf")
    
for f in files:
    try:
        t = textract.process(f).decode("utf-8")
        basename = os.path.splitext(f)[0]
        basename = os.path.basename(basename)
        with open(os.path.join("data/txt", basename + ".txt"), "w") as f2:
            f2.write(t)
        print("[converted to txt] " + f)
    except textract.exceptions.ShellError:
        with open("textract_errors.log", "a") as f3:
            f3.write(f + "\n")
