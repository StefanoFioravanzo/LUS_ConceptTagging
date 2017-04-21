#!/usr/bin/env bash

# files needed to run this file:
# - data/NLSPARQL.train.data
# and the following folders:
# - proc/
# - models/

DATA_FOLDER=../data/
PROC_FOLDER=../proc/
MODELS_FOLDER=../models/
TMP_FOLDER=../tmp/

TRAIN_DATA=${DATA_FOLDER}NLSPARQL.train.data
TMP=${TMP_FOLDER}tmp
LEXICON=${MODELS_FOLDER}'lexicon.lex'
LEXICON_CUTOFF=${MODELS_FOLDER}'lexicon_cutoff.lex'

mkdir ${TMP_FOLDER}

# create standard lexicon
echo '<epsilon>' > ${TMP}
# add all unique words present in the training data
tr -s ' ' '\n' < ${TRAIN_DATA} | cut -f1 | sort | uniq >> ${TMP}
# Add all unique tags present in the training data
tr -s ' ' '\n' < ${TRAIN_DATA} | cut -f2 | sort | uniq >> ${TMP}
echo '<unk>' >> ${TMP}
count=0; while read line; do echo -e ${line}'\t'${count}; ((count++)); done < ${TMP} > ${MODELS_FOLDER}${LEXICON}
rm ${TMP}

# now create the lexicon with the cutoff
echo "<epsilon>" > ${TMP}
# cutoff all words which appear only once or 100+ times
tr -s ' ' '\n' < ${TRAIN_DATA} | cut -f1 | sort | uniq -c | sort -gr |\
 sed '/^ *[0-9]\{3,\}/d'| sed '/^ *1 */d' | sed 's/^ *//' | cut -d' ' -f2 >> ${TMP}
tr -s ' ' '\n' < ${TRAIN_DATA} | cut -f2 | sort | uniq >> ${TMP}
echo "<unk>" >> ${TMP}
count=0; while read line; do echo -e ${line}'\t'${count}; ((count++)); done < ${TMP} > ${MODELS_FOLDER}${LEXICON_CUTOFF}
rm ${TMP}

# counts of the tags
tr -s ' ' '\n' < ${TRAIN_DATA} | cut -f2 | sort | uniq -c | sed -e 's/^ *//' > ${PROC_FOLDER}POS.counts

# counts of couples word-tag
tr -s ' ' '\n' < ${TRAIN_DATA} | sort | uniq -c | sed -e 's/^ *//' | tr '\t' ' ' > ${PROC_FOLDER}TOK_POS.counts

# compute probabilities and costs for the transducer
python3 compute_probabilities.py

fstcompile  --isymbols=${LEXICON} --osymbols=${LEXICON} ${PROC_FOLDER}TOK_POS.transducer >${MODELS_FOLDER}pos-tagger.fst
fstcompile  --isymbols=${LEXICON_CUTOFF} --osymbols=${LEXICON_CUTOFF} ${PROC_FOLDER}TOK_POS_cutoff.transducer >${MODELS_FOLDER}pos-tagger_cutoff.fst

rm -rf ${TMP_FOLDER}
