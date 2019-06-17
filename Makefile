
analysis: LDA 11_analysis.html
LDA: DATA data/nov_tra_res.csv
DATA: models/hashed_lda_ip.vw

###########
# data processing

### 01
data/pdf_list.txt: 01_scrape.py
	python3 01_scrape.py
data/metadata.csv: data/pdf_list.txt

### 02
.state/download_state: 02_download_pdf.sh data/pdf_list.txt
	sh 02_download_pdf.sh; touch .state/download_state

### 03
.state/txt_state: 03_extract.py .state/download_state
	python3 03_extract.py; touch .state/txt_state

### 04
data/folketing_formand.csv: 04_folketing_titles.py
	python3 04_folketing_titles.py

### 05
data/folketing_members.csv: 05_get_folketing_members.py
	python3 05_get_folketing_members.py
## 06
.state/segmented_state: 06_txt_speaker_time.py .state/txt_state data/folketing_members.csv
	python3 06_txt_speaker_time.py; touch .state/segmented_state

## 07
data/tidy_text.csv: 07_tidy_text.R .state/segmented_state data/metadata.csv data/folketing_formand.csv
	rm data/to_udpipe/*; Rscript 07_tidy_text.R

## 08
.state/udpipe: data/tidy_text.csv
	rm data/from_udpipe/*; /bin/ls data/to_udpipe | parallel -j4 --bar "./08_tokenize.sh data/to_udpipe/{} data/from_udpipe/{}"; touch .state/udpipe

## 09
models/hashed_lda_ip.vw: .state/udpipe data/tidy_text.csv 09_stopwords.R
	Rscript 09_stopwords.R

models/doc_topic.model: models/hashed_lda_ip.vw
	vw -k -d models/hashed_lda_ip.vw -b 14 --lda 100 --lda_alpha 0.1 --lda_epsilon 0.1 --lda_rho 0.1 -p models/doc_topic.model --readable_model models/word_topic.model --passes 10 --cache_file models/vw.cache --power_t 0.5 --decay_learning_rate 0.5 --holdout_off --minibatch 256 --lda_D `wc -l < models/hashed_lda_ip.vw`

## 10
data/nov_tra_res.csv: models/doc_topic.model 10_parse_vw_lda.R
	Rscript 10_parse_vw_lda.R

#######
# analysis
11_analysis.html: 11_analysis.Rmd data/nov_tra_res.csv
	Rscript -e 'rmarkdown::render("11_analysis.Rmd", "html_document")'

######
# clean up
clean:
	rm -rf data; rm -rf .state; rm -rf models/; rm textract_errors.log; mkdir data; mkdir data/pdf; mkdir data/txt; mkdir data/segmented; mkdir data/tidy; mkdir data/vw; mkdir models; mkdir .state; touch .state/visited.txt
