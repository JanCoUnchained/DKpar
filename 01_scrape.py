#!/usr/bin/env python3

# scrapes folketingstidende.dk for pdfs of meeting summaries + their metadata

from selenium import webdriver
from selenium.webdriver.firefox.options import Options
import re, string

# indgangsportal:
# http://www.folketingstidende.dk/Folketingstidende.aspx

out_filename = "data/pdf_list.txt"
metadata_filename = "data/metadata.csv"
done_filename = ".state/visited.txt"
sessions = ["20171", "20161", "20151", "20141", "20142", "20131", "20121", "20111","20101", "20102", "20091"]
doc_types = ["6"]
base_url = "http://www.folketingstidende.dk"
url = "http://www.folketingstidende.dk/Folketingstidende/Folketingstidende.aspx?" \
       "session={}" \
       "&startDate="\
       "&endDate="\
       "&eftDocType={}"\
       "&showPublicationDate=0"\
       "&sortColumn="\
       "&sortOrder="\
       "&startRecord="\
       "&numberOfRecords="\
       "&totalNumberOfRecords="\
       "&pageSize=100"\
       "&pageNr={}"


# regexes for parsing the page
id_re = re.compile("([A-Z]+ \d+)")
pdf_re = re.compile("(\S+\.pdf)")
date_re = re.compile("(\d{2}-\d{2}-\d{4})")
row_re = re.compile("([A-Z]+ \d+)?(.*?)(\d{2}-\d{2}-\d{4})")


# visited pages
with open(done_filename, "r") as done_file:
    pages_scraped = done_file.read().splitlines()
    print("n of previously scraped pages: " + str(len(pages_scraped)))

print("Initializing browser engine")
options = Options()
options.set_headless(headless = True)
driver = webdriver.Firefox(executable_path="./geckodriver", firefox_options = options)

# write header of output file
with open(metadata_filename, "w") as metadata:
    metadata.write("Samling;Dokumenttype;Nr;Titel;Dato;PDF;\n")

# now loop through the combinations we want to scrape
for s in sessions:
    for d in doc_types:
        for i in range(1,100): # try up to 100 pages
            this_url = url.format(s,d,i)
            if this_url in pages_scraped:
                print("[Skipping] " + this_url)
                continue
            else:
                print("[Scraping] " + this_url)
            
            driver.get(this_url)
            documents = driver.find_elements_by_css_selector("table.journalAppendix tbody tr")
            if len(documents) < 2:
                # empty page, switch to some different parameters
                break
            
            with open(out_filename, "a") as document_file:
                with open(metadata_filename, "a") as metadata:
                    for row in documents[1:]:
                        # for each row in the table on the page
                        # do some regexes to find out what info we have available
                        t = row.text
                        pdf = pdf_re.search(row.text)
                        if pdf: pdf = pdf.group(1)
                        else: pdf = ""
                        idx, title, date = row_re.match(row.text).group(1,2,3)
                        if not idx: idx = ""
                        if not title: title = ""
                        if not date: date = ""
                        
                        document_file.write(base_url + pdf + "\n")
                        metadata.write(';'.join([s, d, idx, title, date, pdf]) + ";\n")
                        
            with open(done_filename, "a") as  done:
                done.write(this_url + "\n")


driver.close()
