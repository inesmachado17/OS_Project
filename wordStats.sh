#! /usr/bin/env bash

# Verify requirements
# command pdftotext availability
if [[ -z "$(which pdftotext)" ]]; then
    echo "[ERROR] pdftotext: command not found"
    exit
fi

LANG_FILE="en.stop_words.txt"
LANG_OPT="en"
MODO=$1
FILE=$2
CONTENT=""

if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo "[ERROR] insufficient parameters"
    echo "./word_stats.sh Cc|Pp|Tt INPUT [iso3166]"
    exit 1
elif [[ ! "$MODO" =~ ^(c|C|p|P|t|T)$ ]]; then
    echo "[ERROR] unknown command '$MODO'"
    exit 1
elif [[ ! -f "$FILE" ]]; then
    echo "[ERROR] can't find file '$FILE'"
    exit 1
fi

# Verify optional parameter (language)
# pt or en (only)
if [[ $# -eq 3 ]]; then
    LANG_OPT=$(echo $3 | tr "A-Z" "a-z")
fi

if [[ ! "$LANG_OPT" =~ ^(pt|en|es)$ ]]; then
    echo "[ERROR] '$LANG_OPT' language not recognized"
    echo "Choose 'en' or 'pt'"
    exit 1
fi

# Verify if stop words file exists for chosen language
if [[ "$MODO" =~ [cpt] && $LANG_OPT != 'en' ]]; then
    LANG_FILE=$LANG_OPT".stop_words.txt"
    if [ ! -f $LANG_FILE ]; then
        echo "[ERROR] Can not find related stop wors file for selected language"
        exit 1
    fi
fi

# Verify file type, pdf or text, and converts pdf to text
if [[ $(file "$FILE" | cut -d':' -f 2 | grep -i text) ]]; then
    CONTENT=$(cat $FILE)
    echo "'$FILE': TEXT file"
elif [[ $(file "$FILE" | cut -d':' -f 2 | grep -i pdf) ]]; then
    CONTENT=$(pdftotext -nopgbrk $FILE -) # -enc 'ASCII7'
    echo "'$FILE': PDF file"
else
    echo "[ERROR] '$FILE' file type not supported"
    exit 1
fi
echo "[INFO] Processing '$FILE'"

# Remove numbers, punctuation, symbols and empty lines
# https://web.fe.up.pt/~ee96100/projecto/Tabela%20ascii.htm
# !! TODO check ascii table
CONTENT=$(echo "$CONTENT" | tr "[:digit:]" " ")
CONTENT=$(echo "$CONTENT" | tr "[:punct:]" " ")
CONTENT=$(echo "$CONTENT" | tr -c "[A-Za-zÇ-Üá-ÑÁ-Àã-ÃÊ-ÏÓ-Ý]" " ")
CONTENT=$(echo "$CONTENT" | tr "[:upper:]" "[:lower:]")

CONTENT=$(echo "$CONTENT" | tr -s ' ' '\n')

# Remove stop words
if [[ "$MODO" =~ [cpt] ]]; then
    STOP_WORDS_CONTENT=$(cat "$LANG_FILE" | xargs -n1)
    STOP_WORDS_CONTENT=$(echo "$STOP_WORDS_CONTENT" | tr -s '\n' '|')
    STOP_WORDS_CONTENT=$(echo "${STOP_WORDS_CONTENT::-1}")

    CONTENT=$(echo "$CONTENT" | grep -Evi "^($STOP_WORDS_CONTENT)$")
    echo "StopWords file '$LANG_OPT': 'StopWords/$LANG_FILE' ($(wc -w $LANG_FILE | cut -d' ' -f1) words)"
    echo "STOP WORDS will be filtered out"
else
    echo "STOP WORDS will be counted"
fi

# Sort and count ocurrencies on CONTENT
CONTENT=$(echo "$CONTENT" | sort | uniq -c | sort -nr)

#
# OUTPUTS
#

if [[ "$MODO" =~ [c|C] ]]; then
    RESULT="results---"${FILE::-3}"txt"

    # save content output on a file
    echo "$CONTENT" >$RESULT

    echo "COUNT MODE"
    head $RESULT

    LINES=$(wc -l $RESULT | cut -d' ' -f1)

    if [[ $LINES -gt 10 ]]; then
        echo "(...)"
    else
        echo ""
    fi

    echo "RESULTS: '$RESULT'"
    echo $(ls -l $RESULT)

    echo $(wc -w $RESULT | cut -d' ' -f1) "distinct words"
fi

if [[ "$MODO" =~ [p|P] ]]; then
    #https://stackoverflow.com/questions/22869025/gnuplot-change-value-of-x-axis
    RESULT="results---"${FILE::-3}"dat"
    echo "$CONTENT" >>$RESULT

    if [[ $MODO == 'p' ]]; then
        TITLE="Top words for '$FILE'\nCreated: xxx.xx.xxhxx:xx\n('$LANG_OPT' stop words removed)"
    else
        TITLE="Top words for '$FILE'\nCreated: xxx.xx.xxhxx:xx\n(without remove stop words)"
    fi

    gnuplot <<-EOF
        set xlabel "words"
        set ylabel "number of occurences"
        set title "${TITLE}"
        set term png
        set output "teste.png"
        set yrange[0:]
        set xrange[0:7]
        set xtics nomirror rotate by -45 scale 0
        set boxwidth 0.5
        set style fill solid 0.25
        set xtics 1.0 border
        plot "${RESULT}" using 1:xticlabels(2) with boxes title "# occurrences" lc rgb "green", \\
            ''          using 0:1:1 with labels center offset 0,1 boxed notitle
EOF

fi

if [[ "$MODO" =~ [t|T] ]]; then

    if [ -z $WORD_STATS_TOP ]; then
        echo "Environment variable 'WORD_STATS_TOP' is empty (using default 10)"
        WORD_STATS_TOP=10
    # !! https://stackoverflow.com/questions/806906/how-do-i-test-if-a-variable-is-a-number-in-bash
    elif [[ $WORD_STATS_TOP =~ ^[1-9]+[0]*$ ]]; then
        echo "WORD_STATS_TOP=$WORD_STATS_TOP"
    else
        echo "'$WORD_STATS_TOP' not a number (using default 10)"
        WORD_STATS_TOP=10
    fi

    CONTENT=$(echo "$CONTENT" | head -n $WORD_STATS_TOP)

    RESULT="results---"${FILE::-3}"txt"
    # save content output on a file
    echo "$CONTENT" >$RESULT
    echo $(ls -l $RESULT)
    echo "-------------------------------------"
    echo "# TOP $WORD_STATS_TOP elements"
    cat -n $RESULT
    echo "-------------------------------------"
fi
