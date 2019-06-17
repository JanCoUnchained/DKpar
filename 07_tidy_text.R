library(tidyverse)
library(lubridate)
library(udpipe)
library(stopwords)
library(multidplyr)
library(fuzzyjoin)

# reshape the segmented data
# dl <- udpipe_download_model(language = "danish")

title_re_paren = "(?<=\\().*(?=\\))"
title_re_noparen = ".*"
name_re = "[\\w\\s-\\.]+"



tidy_text <- function(filename) {
    d = read_delim(filename, delim = ";", col_types = cols()) %>%
        filter(complete.cases(reason))

    if (nrow(d) < 3) return(NA)
    if (!any(str_detect(d$reason, "name"))) return (NA)

    d = d %>%
        filter(split > 0) %>%
        mutate(value = case_when(
                   reason == "title_name" ~ ifelse(
                                 str_detect(value, "\\(|\\)"),
                                 str_extract(value, title_re_paren),
                                 str_extract(value, title_re_noparen)),
                   reason == "name_party" ~ str_extract(value, name_re),
                   reason == "Time" ~ value),
               reason = ifelse(reason == "Time", "Time", "Name"),
               value = trimws(value)) %>%
        spread(reason, value) %>%
        select(-split) %>%
        fill(Time, Name) %>%
        filter(complete.cases(.)) %>%
        mutate(Time = hm(Time))

    f = str_replace(filename, "segmented", "tidy")
    ## print(f)

    write_delim(d, f, delim = ";")
}


files = list.files("data/segmented", "*.txt", full.names = TRUE)
fl = length(files)

for (i in 1:fl) {
    f = files[i]
    cat(paste0("[tidying] ", i, " / ", fl, " ", f, "\n"))
    tidy_text(f)
}



# Next, combine with the metadata
meta = read_delim("data/metadata.csv", ";", col_types = cols()) %>%
    mutate(id = tools::file_path_sans_ext(basename(PDF)))
files = list.files("data/tidy", "*.txt", full.names = TRUE)


do_read_tidy <- function(f) {
    # load a file and keep the metadata stored in the filename along with it
    read_delim(f, ";", col_types = cols()) %>%
        mutate(id = tools::file_path_sans_ext(basename(f)))
}


data = files %>%
    map_df(do_read_tidy) %>%
    bind_rows() %>%
    right_join(meta, by = "id") %>%
    mutate(Date = parse_date_time(str_c(Dato, Time, sep = " "),
                                  orders = c("dmy HMS", "dmy MS", "dmy S")))

data = data %>%
    arrange(Date) %>%
    mutate(speaker_id = ifelse(lag(Name) != Name, 1, 0) %>%
               coalesce(0) %>%
               cumsum()) %>%
    group_by(Name, id, Samling, Dokumenttype, Nr, Titel, Dato, speaker_id) %>%
    summarise(text = str_c(text, collapse = " "),
              Date = min(Date)) %>% ungroup() %>%
    mutate(doc_id = as.character(as.integer(as.factor(str_c(speaker_id, Name, Date))))) %>%
    ungroup()



###################
# handle titles like "Anden næstformand"
titles = read_csv2("data/folketing_formand.csv", comment = "#", col_types = cols()) %>%
    mutate(from = dmy(from),
           to = dmy(to),
           dur = interval(from,to))


find_name_from_title = function(name, date) {
    # formand | formanden
    d = titles[name == titles$Title | name == str_c(titles$Title, "en"),]
    # correct date range (the title switches hands)
    d = d[date %within% d$dur,]
    n = d$Name
    p = d$Parti

    if (identical(n, character(0))) {

        n = name
        p = NA
        }
    return(data.frame(Title = name, Name = n, Parti = p, stringsAsFactors = FALSE))
}


title_subset = data %>%
    #sample_n(10) %>%
    distinct(Name, Dato) %>%
    mutate(Dato2 = dmy(Dato))  %>%
    mutate(Name = map2(Name, Dato2, find_name_from_title)) %>% unnest(Name) %>%
    select(Dato, Name, Title, Parti)

data2 = left_join(data, title_subset, by = c("Name" = "Title", "Dato")) %>%
    rename(Title = Name, Name = Name.y)


#################
# load in data on who's in which party
cat("[ ] Combining with party data\n")
ft_members = read_delim("data/folketing_members.csv", ";", col_names =FALSE, col_types = cols())
names(ft_members) = c("Name", "Parti", "Year")
ft_members = ft_members %>%
    mutate(Parti = str_extract(Parti, "\\w+") ) %>%
    group_by(Name, Parti) %>%
    summarise(Year = min(Year)) %>% ungroup()

ft_members = ft_members %>%
    expand(Name, Year = min(Year):max(max(Year), 2018)) %>%
    left_join(ft_members, by = c("Name", "Year")) %>%
    arrange(Name, Year) %>%
    fill(Parti) %>%
    filter(complete.cases(Parti))


data3 = data2 %>%
    mutate(Year = year(Date)) %>%
    left_join(ft_members, by = c("Name", "Year")) %>%
    mutate(Parti = ifelse(is.na(Parti.x), Parti.y, Parti.x)) %>%
    select(-Parti.x, -Parti.y)


#################
cat("[ ] pre-preprocessing text\n")
data3$text = data3$text %>%
    str_replace_all("\\b[:alpha:] [:digit:]+", " ") %>% # lovforslag
    str_to_lower(locale = "da") %>%
    str_replace_all(str_c("[,;:.–_/()\\s'»$&+", '"', "]+"), " ")

data3 = filter(data3, str_detect(text, "\\S"), nchar(text) > 20)


## data3 %>%
##     sample_n(10) %>%
##     select(text) %>% pluck(1) %>%
##     write_lines("models/for_udpipe")

rm(data)
rm(data2)

data3 %>%
    select(-text, -speaker_id) %>%
    write_csv("data/tidy_text.csv")


#################
cat("[ ] Udpipe\n")
# ud = udpipe_load_model(file = list.files(pattern = "danish-ud.*udpipe"))

# d = sample_n(data3, 5000)
# d = data3

# parallel processing
## cluster <- create_cluster(4) %>%
##     cluster_library("tidyverse") %>%
##     cluster_library("udpipe")

lemma = data3 %>%
    arrange(doc_id) %>%
    groupdata2::group(100)


lemma %>%
    select(-text, -speaker_id) %>%
    write_csv("data/tidy_text.csv")



lemma %>%
    split(.$.groups) %>%
    walk(~(write_lines(.$text, str_c("data/to_udpipe/", unique(.$.groups)))))
# it works!
# dapipe/udpipe.lin64 --tokenize --tag dapipe/danish-ud-2.0-170801.udpipe data/to_udpipe/1 --outfile=data/from_udpipe/1


##############

