#! /usr/bin/env bash

# Requirement check
# Command pdftotext availability
if [[ -z "$(which pdftotext)" ]]; then
    echo "[ERROR] pdftotext: command not found"
    exit 1
fi

lang_file="en.stop_words.txt"
lang_opt="en" #not mix with the global lang
mode=$1
file=$2
content=""

if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo "[ERROR] insufficient parameters"
    echo "./word_stats.sh Cc|Pp|Tt INPUT [iso3166]"
    exit 1
elif [[ ! "$mode" =~ ^(c|C|p|P|t|T)$ ]]; then
    echo "[ERROR] unknown command '$mode'"
    exit 1
elif [[ ! -f "$file" ]]; then
    echo "[ERROR] can't find file '$file'"
    exit 1
fi

# Optional parameter (language) check
# pt or en (only)
if [[ $# -eq 3 ]]; then
    lang_opt=$(echo $3 | tr "A-Z" "a-z")
fi
if [[ ! "$lang_opt" =~ ^(pt|en)$ ]]; then
    echo "[ERROR] '$lang_opt' language not recognized"
    echo "Choose 'en' or 'pt'"
    exit 1
fi

# Check if stop words file exists for chosen language
if [[ "$mode" =~ [cpt] && $lang_opt != 'en' ]]; then
    lang_file=$lang_opt".stop_words.txt"
    if [ ! -f $lang_file ]; then
        echo "[ERROR] Can not find related stop words file for selected language"
        exit 1
    fi
fi

# Check file type
# pdf to text conversion
if [[ $(file "$file" | cut -d':' -f 2 | grep -i text) ]]; then
    content=$(cat $file)
    echo "'$file': TEXT file"
elif [[ $(file "$file" | cut -d':' -f 2 | grep -i pdf) ]]; then
    content=$(pdftotext -nopgbrk $file -)
    echo "'$file': PDF file"
else
    echo "[ERROR] '$file' file type not supported"
    exit 1
fi
echo "[INFO] Processing '$file'"

# Remove numbers, punctuation, symbols and empty lines
# https://web.fe.up.pt/~ee96100/projecto/Tabela%20ascii.htm
# iconv //IGNORE garante que o file mantém UTF-8 depois do tr
content=$(echo "$content" | tr "[:digit:]" " ")
content=$(echo "$content" | tr "[:punct:]" " ")
content=$(echo "$content" | tr -c "[A-Za-zÇ-Üá-ÑÁ-Àã-ÃÊ-ÏÓ-Ý]" " ")
content=$(echo "$content" | tr "[:upper:]" "[:lower:]")
content=$(echo "$content" | iconv -c -t UTF-8//IGNORE) #UTF-8 standardize
content=$(echo "$content" | tr -s ' ' '\n')

# Remove stop words
if [[ "$mode" =~ [cpt] ]]; then
    stop_words_content=$(cat "$lang_file" | xargs -0 -n1)
    stop_words_content=$(echo "$stop_words_content" | tr -s '\n' '|')
    stop_words_content=$(echo "${stop_words_content::-1}")

    content=$(echo "$content" | grep -Evi "^($stop_words_content)$")
    echo "StopWords file '$lang_opt': 'StopWords/$lang_file' ($(wc -w $lang_file | cut -d' ' -f1) words)"
    echo "STOP WORDS will be filtered out"
else
    echo "STOP WORDS will be counted"
fi

# Sort and count ocurrencies on content
content=$(echo "$content" | sort | uniq -c | sort -nr)

#
# OUTPUTS
#

if [[ "$mode" =~ [c|C] ]]; then
    result="results---"${file::-4}".txt"

    # save content output on a file
    echo "$content" >$result

    echo "COUNT MODE"
    head $result

    lines=$(wc -l $result | cut -d' ' -f1)

    if [[ $lines -gt 10 ]]; then
        echo "(...)"
    else
        echo ""
    fi

    echo "RESULTS: '$result'"
    echo $(ls -l $result)

    echo $(wc -w $result | cut -d' ' -f1) "distinct words"
fi

if [[ "$mode" =~ [p|P] ]]; then
    if [ -z $word_stats_top ]; then
       word_stats_top=10        
    # !! https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
    elif [[ $word_stats_top =~ ^[1-9]+[0]*$ ]]; then
        word_stats_top=$word_stats_top
    fi
    #https://stackoverflow.com/questions/22869025/gnuplot-change-value-of-x-axis
    result="results---"${file::-4}
    content=$(echo "$content" | head -n $word_stats_top)
    echo "$content">$result".dat"
    date=$(TZ=Europe/Lisbon date +'%Y.%m.%d-%Hh%M:%S')
        
    if [[ $mode == 'p' ]]; then
        title="Top words for '$file'\nCreated: $date\n('$lang_opt' stop words removed)"
    else
        title="Top words for '$file'\nCreated: $date\n('$lang_opt' stop words counted)"
    fi

    gnuplot << EOF
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

    html="<!DOCTYPE html><html lang=\"en\"><head> <meta charset=\"UTF-8\"> <meta http-equiv=\"X-UA-Compatible\" content=\"IE=edge\"> <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\"> <title>Top Words</title></head><body> <h1>Top $word_stats_top Words - '${file}' </h1> <img src=\"$result.png\" alt=\"Top $word_stats_top words chart\"><p>Authors: Estudante 2200723, Estudante 2203845<br>Created: $date</p></body></html>"
    echo $html>$result".html"
    echo $(ls -l $result".dat")
    echo $(ls -l $result".png")
    echo $(ls -l $result".html")
    display $result".png"
fi

if [[ "$mode" =~ [t|T] ]]; then

    if [ -z $word_stats_top ]; then
        echo "Environment variable 'word_stats_top' is empty (using default 10)"
        word_stats_top=10
    # !! https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
    elif [[ $word_stats_top =~ ^[1-9]+[0]*$ ]]; then
        echo "word_stats_top=$word_stats_top"
    else
        echo "'$word_stats_top' not a number (using default 10)"
        word_stats_top=10
    fi

    content=$(echo "$content" | head -n $word_stats_top)

    result="results---"${file::-3}"txt"
    # save content output on a file
    echo "$content" >$result
    echo $(ls -l $result)~12
    echo "-------------------------------------"
    echo "# TOP $word_stats_top elements"
    cat -n $result
    echo "-------------------------------------"
fi
