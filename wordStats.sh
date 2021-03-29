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
elif [[ $(file "$FILE" | cut -d':' -f 2 | grep -i pdf) ]]; then
    CONTENT=$(pdftotext -nopgbrk $FILE -) # -enc 'ASCII7'
else
    echo "[ERROR] '$FILE' file type not supported"
fi

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

# if [[ "$MODO" =~ [p|P] ]]; then

# fi

# if [[ "$MODO" =~ [t|T] ]]; then

# fi

#echo "$CONTENT"
