#!/usr/bin/env bash

DATA_FOLDER=../data/
PROC_FOLDER=../proc/
MODELS_FOLDER=../models/
TMP_FOLDER=../tmp/
RESULTS_FOLDER=../results/

TRAINING_SET=${DATA_FOLDER}NLSPARQL.train.feats.pos.txt
TEST_SET=${DATA_FOLDER}NLSPARQL.test.feats.pos.txt

# NOTE: change these files if we want to use cutoff
#LEXICON=${MODELS_FOLDER}lexicon.lex
#POS_TAGGER=pos-tagger.fst
LEXICON=${MODELS_FOLDER}lexicon_cutoff.lex
POS_TAGGER=pos-tagger_cutoff.fst

# Take as argument the size of the n-gram of the language model
# and the kind of smoothing applied.
N_GRAM_MODEL=$1
SMOOTHING=$2

echo "run with parameters: n_gram=${N_GRAM_MODEL} smoothing=${SMOOTHING}"

# create tmp folder to store intermediate files
mkdir ${TMP_FOLDER}

# convert training data set from token-per-line format to sentence-per-line (using tokens)
cat ${TRAINING_SET} | cut -f2 | sed -e 's/^ *$/#/g' |\
 tr '\n' ' ' | tr '#' '\n' | sed -e 's/^ *//' -e 's/ *$//' > ${TMP_FOLDER}sentence_per_line_train.data

# use the new training data format to train the N-Gram Language model
farcompilestrings --symbols=${LEXICON} --unknown_symbol='<unk>' ${TMP_FOLDER}sentence_per_line_train.data > ${TMP_FOLDER}data.far
ngramcount --order=${N_GRAM_MODEL} --require_symbols=false ${TMP_FOLDER}data.far > ${TMP_FOLDER}pos.cnt
ngrammake --method=${SMOOTHING} ${TMP_FOLDER}pos.cnt > ${MODELS_FOLDER}pos_${N_GRAM_MODEL}_${SMOOTHING}.lm

# now compose the transducer with the language model
fstcompose ${MODELS_FOLDER}${POS_TAGGER} ${MODELS_FOLDER}pos_${N_GRAM_MODEL}_${SMOOTHING}.lm > ${MODELS_FOLDER}word2tag.fst

# change the format to sentence-per-line also for test data (using words)
cat ${TEST_SET} | cut -f1 | sed -e 's/^ *$/#/g' |\
 tr '\n' ' ' | tr '#' '\n' | sed -e 's/^ *//' -e 's/ *$//' > ${TMP_FOLDER}sentence_per_line_test.data

# predict the tags for each test sentence
while read -r sentence
do
    echo ${sentence} | farcompilestrings --symbols=${LEXICON} --unknown_symbol='<unk>' --generate_keys=1 --keep_symbols |\
     farextract --filename_suffix='.fst' --filename_prefix='sentence'
    fstcompose sentence1.fst ${MODELS_FOLDER}word2tag.fst | fstshortestpath | fstrmepsilon | fsttopsort |\
     fstprint --isymbols=${LEXICON} --osymbols=${LEXICON} | cut -f 3,4 >> ${TMP_FOLDER}prediction.data
    # remove temporary file created by farextract utility
    rm sentence1.fst
done < ${TMP_FOLDER}sentence_per_line_test.data

# create a file <word> <original_tag> <predicted_tag>
cut -f2 ${TMP_FOLDER}prediction.data | paste ${TEST_SET} - > ${TMP_FOLDER}evaluation.data
# evaluate the performance of the model
./conlleval.pl -d '\t' < ${TMP_FOLDER}evaluation.data > ${RESULTS_FOLDER}${N_GRAM_MODEL}_${SMOOTHING}.result

# remove all temporary files
rm -rf ${TMP_FOLDER}

