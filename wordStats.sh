#! /usr/bin/env bash

# Verificar se o comando existe
which pdftotext

MODO=$1;
FILE=$2;
LANG=$3;


CONTENT="";

if [ $# -ne 2 ] && [ $# -ne 3 ]; then
    echo "[ERROR] insufficient parameters"
    echo "./word_stats.sh Cc|Pp|Tt INPUT [iso3166]"
    exit
elif [[ ! "$MODO" =~ ^(c|C|p|P|t|T)$ ]]; then
    echo "[ERROR] unknown command '$MODO'"
    exit
elif [[ ! -f "$FILE" ]]; then
    echo "[ERROR] can't find file '$FILE'"
    exit
fi

# Verificacao do parametro opcional
# pt e en
if [[ -z $LANG ]]; then
    LANG="en"
elif [[ ! "$LANG" =~ ^(pt|en)$ ]]; then
    echo "[ERROR] '$LANG' language not recognized"
    exit
fi

if [[ $(file "$FILE" | cut -d':' -f 2 | grep -i text) ]]; then
CONTENT=$(cat $FILE)
elif [[ $(file "$FILE" | cut -d':' -f 2 | grep -i pdf) ]]; then
CONTENT=$(pdftotext $FILE)
else
echo "o arquivo nao é text nem pdf"
fi




