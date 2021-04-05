#! /usr/bin/env bash

#
# Functions
#

# message display
function display_error_msg_and_exit() {
    echo -e "[ERROR] $1"
    exit 1
}
function display_info_msg() {
    echo -e "[INFO] $1"
}
function display_msg() {
    echo -e "$1"
}

# requirement check
function check_word_stats_top() {
    if [ -z $WORD_STATS_TOP ]; then
        display_msg "Environment variable 'WORD_STATS_TOP' is empty (using default 10)"
        WORD_STATS_TOP=10
    elif [[ $WORD_STATS_TOP =~ ^[1-9]+[0-9]*$ ]]; then
        display_msg "WORD_STATS_TOP=$WORD_STATS_TOP"
    else
        display_msg "WORD_STATS_TOP: '$WORD_STATS_TOP' not a number (using default 10)"
        WORD_STATS_TOP=10
    fi
}
function check_language() {

    lang_opt=$(echo $1 | tr "A-Z" "a-z")

    if [[ ! "$lang_opt" =~ ^(pt|en)$ ]]; then
        display_error_msg_and_exit "'$lang_opt' language not recognized\nChoose 'en' or 'pt'"
    fi
}
function check_stop_words_file() {
    if [[ $lang_opt != 'en' ]]; then
        lang_file=$lang_opt".stop_words.txt"

        if [ ! -f $lang_file ]; then
            display_error_msg_and_exit "Can not find related stop words file for selected language"
        fi
    fi
}

# Global variables
lang_file="en.stop_words.txt"
lang_opt="en" # not override the global lang variable
mode=$1
file=$2
content=""

# Command pdftotext availability
if [[ -z "$(which pdftotext)" ]]; then
    display_error_msg_and_exit "pdftotext: command not found"
fi

# Parameter check
if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    displayErrorMsg "insufficient parameters\n./word_stats.sh Cc|Pp|Tt INPUT [iso3166]"
elif [[ ! "$mode" =~ ^(c|C|p|P|t|T)$ ]]; then
    display_error_msg_and_exit "unknown command '$mode'"
elif [[ ! -f "$file" ]]; then
    display_error_msg_and_exit "can't find file '$file'"
fi

# Check file type and content read
if [[ $(file "$file" | cut -d':' -f 2 | grep -i text) ]]; then
    content=$(cat $file)
    display_msg "'$file': TEXT file"
elif [[ $(file "$file" | cut -d':' -f 2 | grep -i pdf) ]]; then
    content=$(pdftotext -nopgbrk $file -)
    display_msg "'$file': PDF file"
else
    display_error_msg_and_exit "'$file' file type not supported"
fi

display_info_msg "Processing '$file'"

# Remove numbers, punctuation, symbols and empty lines
# iconv //IGNORE ensures the file is UTF-8 encoded after tr command
content=$(echo "$content" |
    tr "[:digit:]" " " |
    tr "[:punct:]" " " |
    tr -c "[A-Za-zÇ-Üá-ÑÁ-Àã-ÃÊ-ÏÓ-Ý]" " " |
    tr "[:upper:]" "[:lower:]" |
    iconv -c -t UTF-8//IGNORE |
    tr -s ' ' '\n')

# Remove stop words mode
if [[ "$mode" =~ [cpt] ]]; then

    check_language "$3"

    check_stop_words_file

    stop_words_content=$(cat "$lang_file" | xargs -0 -n1 | tr -s '\n' '|')
    stop_words_content=$(echo "${stop_words_content::-1}")

    content=$(echo "$content" | grep -Evi "^($stop_words_content)$")

    display_msg "StopWords file '$lang_opt': 'StopWords/$lang_file' ($(wc -w $lang_file | cut -d' ' -f1) words)"
    display_msg "STOP WORDS will be filtered out"
else
    display_msg "STOP WORDS will be counted"
fi

# Sort and count ocurrences on content
content=$(echo "$content" | sort | uniq -c | sort -nr)

#
# OUTPUTS
#

if [[ "$mode" =~ [c|C] ]]; then
    result="results---"${file::-4}".txt"

    # save content output on a file
    echo "$content" >$result

    display_msg "COUNT MODE"
    head $result

    lines=$(wc -l $result | cut -d' ' -f1)

    if [[ $lines -gt 10 ]]; then
        display_msg "(...)"
    else
        display_msg ""
    fi

    display_msg "RESULTS: '$result'"
    display_msg "$(ls -l $result)"

    display_msg "$(wc -w $result | cut -d' ' -f1) distinct words"
fi

if [[ "$mode" =~ [p|P] ]]; then

    check_word_stats_top

    #https://stackoverflow.com/questions/22869025/gnuplot-change-value-of-x-axis
    result="results---"${file::-4}
    content=$(echo "$content" | head -n $WORD_STATS_TOP)

    # save content output on a file
    echo "$content" >$result".dat"

    today=$(TZ=Europe/Lisbon date +'%Y.%m.%d-%Hh%M:%S')

    if [[ $mode == 'p' ]]; then
        title="Top words for '$file'\nCreated: $today\n('$lang_opt' stop words removed)"
    else
        title="Top words for '$file'\nCreated: $today\n('$lang_opt' stop words counted)"
    fi

    gnuplot <<EOF
        set xlabel "words"
        set ylabel "number of occurences"
        set title "${title}"
        set grid
        set terminal png size 800,600
        set output "${result}.png"
        set yrange[0:*]
        set xtics nomirror rotate by -45 scale 0
        set boxwidth 0.5
        set style fill solid 1.0
        set style textbox opaque
        plot "${result}.dat" using 0:1:xtic(2) with boxes title "# occurrences" lc rgb "orange'0p+", \\
            ''          using 0:1:1 with labels center boxed notitle
EOF

    cat >$result".html" <<EOF
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta http-equiv="X-UA-Compatible" content="IE=edge">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>Top Words</title>
        </head>
        <body>
            <h1>Top ${WORD_STATS_TOP} Words - '${file}'</h1>
            <img src="${result}.png" alt="Top ${WORD_STATS_TOP} words chart">
            <p>Authors: Estudante 2200723, Estudante 2203845<br>Created: ${today}</p>
        </body>
EOF

    display_msg "$(ls -l $result".dat")"
    display_msg "$(ls -l $result".png")"
    display_msg "$(ls -l $result".html")"

    display $result".png"
fi

if [[ "$mode" =~ [t|T] ]]; then

    check_word_stats_top

    content=$(echo "$content" | head -n $WORD_STATS_TOP)

    result="results---"${file::-3}"txt"
    # save content output on a file
    echo "$content" >$result
    display_msg "$(ls -l $result)"
    display_msg "-------------------------------------"
    display_msg "# TOP $WORD_STATS_TOP elements"
    cat -n $result
    display_msg "-------------------------------------"
fi
