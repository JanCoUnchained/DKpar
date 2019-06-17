library(tidyverse)
library(multidplyr)
library(stopwords)

# load data from udpipe, do the last processing, then pass it on to vowpal wabbit

data = read_csv("data/tidy_text.csv", col_types = cols())


cluster <- create_cluster(4) %>%
    cluster_library("tidyverse") %>%
    cluster_assign_value("data", data)

cat("[ ] parsing udpipe output\n")

lemma = data %>%
    select(.groups, doc_id) %>%
    #filter(.groups %in% 1:8) %>%
    partition(.groups, cluster = cluster) %>%
    group_by(.groups) %>%
    do({#print(unique(.$.groups))
        mutate(., lemma =
                      str_c("data/from_udpipe/", unique(.$.groups)) %>%
                      read_file() %>%
                      str_split("# sent_id = \\d+\n", simplify = TRUE) %>%
                      `[`(-1) %>%
                      map(read_tsv, skip = 1,
                          col_names = c("lemma", "type"),
                          col_types = "__cc______") %>%
                      map(filter, type != "PUNCT") ) %>%
            unnest(lemma) %>%
            select(doc_id, lemma) %>%
            mutate(lemma = str_extract(lemma, "\\w+")) %>% 
            return()
    }) %>%
    collect() %>%
    ungroup() %>%
    select(-.groups) %>%
    arrange(as.numeric(doc_id))

parallel::stopCluster(cluster)



# stopwords:
# names of members of folketinget
# titles of folketinget
# stopwords::stopwords("da")
# some custom, short ones


##################
cat("[ ] Stopwords\n")
ft_members = read_delim("data/folketing_members.csv", ";", col_names = FALSE,
                        col_types = cols())[[1]]
ft_titler = read_lines("folketing_titler.txt")


custom_stopwords = str_split(ft_members, " ") %>%
    c(ft_titler, str_c(ft_titler, "en")) %>%
    c(stopwords("da", source = "stopwords-iso")) %>%
    c("l", "m", "nr", "tak", "hr", "fm", "a", "t", "f", "á", "à", "ab", "hristian", "½") %>%
    unlist() %>%
    str_to_lower() %>%
    data_frame(word = .)

lemma2 = anti_join(lemma, custom_stopwords, by = c("lemma" = "word")) %>%
    filter(!str_detect(lemma, "\\d+"),
           nchar(lemma) > 0)



##########
# select top n words
topn = count(lemma2, lemma) %>%
    arrange(desc(n)) %>%
    head(10000)

lemma3 = filter(lemma2, lemma %in% topn$lemma)

######
# write out tidy data the the record
lemma3 %>%
    group_by(doc_id) %>%
    summarise(text = str_c(lemma, collapse = " ")) %>%
    write_csv("data/tidy_lemmas.csv")

#####
# prep vw file
cat("[ ] Writing files ready for vw\n")
out = count(lemma3, doc_id, lemma) %>%
    ungroup() %>%
    mutate(hash = as.integer(as.factor(lemma))) %>%
    arrange(as.numeric(doc_id), desc(n))

# write hash table for later lookup
out %>%
    distinct(hash, lemma) %>%
    arrange(hash) %>%
    #tail(100) %>% View()
    write_csv("data/lemma_hash.csv")

out2 = unite(out, "freq", hash, n, sep = ":", remove = FALSE)

out3 = split(out2, out2$doc_id) %>%
    map_chr(~str_c(.$freq, collapse = " ")) %>%
    str_c("| ", .)

write_lines(out3, "models/hashed_lda_ip.vw")

out2$doc_id %>%
    unique() %>%
    write_lines("models/doc_id")
