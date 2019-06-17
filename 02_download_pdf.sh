#!/bin/bash

cd data/pdf
# download each pdf from the urls in data/pdf_list
# do it with 10 connections in parallel
sort ../pdf_list.txt | uniq -u | parallel --gnu -j 10 "wget -nc"
