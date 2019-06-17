#!/usr/bin/env python3

import pandas as pd
import urllib.request
from bs4 import BeautifulSoup
# import re



## get folketinget's leaders
link = "https://da.wikipedia.org/wiki/Folketingets_formand"
data = []
with urllib.request.urlopen(link) as resp:
    s = BeautifulSoup(resp, "html.parser")
    tbody = s.find("table", attrs = {'class': 'wikitable'}).find("tbody")
    rows = tbody.find_all('tr')
    for row in rows[1:]:
        cols = row.find_all('td')
        cols = [ele.text.strip() for ele in cols]
        data.append([ele for ele in cols if ele])

folketing_leaders = pd.DataFrame(data)
folketing_leaders.columns = ["fra", "til", "formand", "parti", "levetid"]
folketing_leaders.to_csv("data/folketing_leaders.csv", ";", index = False)
