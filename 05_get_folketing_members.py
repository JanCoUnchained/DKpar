#!/usr/bin/env python3

# create some lists of folketing members etc
# download from ft.dk and wikipedia.org
# party names and ministers hardcoded below

import urllib.request
from bs4 import BeautifulSoup
import re

out_file = "data/folketing_members.csv"
        
# scrape wikipedia for members of folketinget (and their party at the time)
wiki_links = [# 'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_1990',
              # 'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_1994',
              # 'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_1998',
              # 'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_2001',
              # 'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_2005',
              'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_2007',
              'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_2011',
              'https://da.wikipedia.org/wiki/Folketingsmedlemmer_valgt_i_2015']

# sort out some dates in this data
datetime_re = re.compile("\d{4}|([123]?\d\.?\s*(januar|februar|marts|april|maj|juni|juli|august|september|oktober|november|december)\s*)",
                         re.IGNORECASE)
# extract the parti
parti_re = re.compile("\w+")
parti = ""

# load and parse each of the above wiki links
# and add the members to the member list
with open(out_file, "w") as f:
    for link in wiki_links:
        year = link[-4:]
        print("[scraping] " + link)
        with urllib.request.urlopen(link) as resp:
            s = BeautifulSoup(resp, "html.parser")
            potentials = s.select("div.mw-parser-output ul li")
            for p in potentials:
                try:
                    a = p.find("a")
                    if a.text in a.attrs.get('title', None) and \
                       len(a.text) > 2:
                        if not datetime_re.search(a.text):
                            children = [i for i in p.children]
                            if len(children) > 2: continue # probably not a name
                            try:
                                parti = children[1]
                                parti = parti_re.search(parti)
                            except:
                                parti = ""
                            if parti: parti = parti.group(0)
                            f.write(a.text + ";" + parti + ";" + year + "\n")
                except:
                    pass



                                

                
