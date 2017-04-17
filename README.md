## Project1 - POS Tagging

- We want to do sequence labeling: assignment of a categorical label to a new observation based on the categories on the training data.
- The simple approach is to treat independently each member of the sequence (word), but performance clearly improves when we consider dependency with nearby elements.
- Using a Markov Model we can say that we estimate the sequence of tags from a sequence of words as the sequence of tags that **maximizes** the probability of the tags given the words.
- Using an independence assumption we can rewrite the full join distribution as the product of the probability of a certain word given its tag *times* the probability of a tag given the previous one, for all the sequence.
- These two probabilities can be estimated using the counts on the training set.


#### Procedure

- First we have to create the lexicon, we include both all the **words** present in the training data as well as all the **tags**:

```bash
echo "<epsilon>" > tmp
# Add all unique words present in the training data
tr -s ' ' '\n' < data/train.pos.txt | cut -f1 | sort | uniq >> tmp
# Add all unique tags present in the training data
tr -s ' ' '\n' < data/NLSPARQL.train.data | cut -f2 | sort | uniq >> tmp
echo "<unk>" >> tmp
count=0; while read line; do echo $line'\t'$count; ((count++)); done < tmp > lexicon.lex
rm tmp
```

We create also a lexicon with **cutoff**, so we remove the most frequent and least frequent words in the corpus:

```bash
echo "<epsilon>" > tmp
tr -s ' ' '\n' < data/NLSPARQL.train.data | cut -f1 | sort | uniq -c | sort -gr | sed '/^ *[0-9]\{3,\}/d'| sed '/^ *1 */d' | sed 's/^ *//' | cut -d' ' -f2 >> tmp
tr -s ' ' '\n' < data/NLSPARQL.train.data | cut -f2 | sort | uniq >> tmp
echo "<unk>" >> tmp
count=0; while read line; do echo $line'\t'$count; ((count++)); done < tmp > lexicon_cutoff.lex
rm tmp
```

- Next step is to compute $P(w_i | t_i)=\frac{C(t_i, w_i)}{C(t_i)}$, we do this by first computing the counts of the tags:

```bash
tr -s ' ' '\n' < data/NLSPARQL.train.data | cut -f2 | sort | uniq -c | sed -e 's/^ *//' > POS.counts
```

- Then we calculate the counts of the couples word-tag:

```bash
tr -s ' ' '\n' < data/NLSPARQL.train.data  | sort | uniq -c | sed -e 's/^ *//' | tr '\t' ' ' > TOK_POS.counts
```

- Then we can use `compute_probabilities.py` to compute the actual $P(w_i | t_i)$ from the counts. This scripts will generate two files:
	- `TOK_POS.prob`: which contains \<word, tag, prob, log_cost\>
	- `TOK_POS.transducer`: which is the file to use to crate the transducer (with one 0 state). In this file we already take care of the unknown words we could find in the test set. See the source file for additional comments on this.

- Now we have to compute the second term: $P(t_i | t_{i-1})$. To do this we first convert the training data from a *token-per-line* format into a *sentence-per-line* format. After this conversion, we can compute the bigram language model with the tool provided by the libraries.

```bash
# convert training data from token-per-line to sentence-per-line (considering just the tags of course)
cat ../data/NLSPARQL.train.data | cut -f2 | sed -e 's/^ *$/#/g' | tr '\n' ' ' | tr '#' '\n' | sed -e 's/^ *//' -e 's/ *$//' > sentence_per_line.data
# now train the language model on this data
farcompilestrings --symbols=./lexicon.lex --unknown_symbol='<unk>' sentence_per_line.data > data.far
ngramcount --order=2 --require_symbols=false data.far > pos.cnt
ngrammake --method=witten_bell pos.cnt > pos.lm
```

#### Create the transducer

Now, with the data created so far, we can compute and exploit the following:

1. the transducer created from the probability $P(w_i | t_i)$ (with the handling of unknown words
2. the language (bigram) model ($P(t_i | t_{i-1})$)

We can compose these two to get the final transducer:

```bash
fstcompile  --isymbols=lexicon.lex --osymbols=lexicon.lex TOK_POS.transducer >transducers/pos-tagger.fst
fstdraw --isymbols=../lexicon.lex --osymbols=../lexicon.lex pos-tagger.fst | dot -Teps > A.eps; open A.eps
fstcompose pos-tagger.fst ../pos.lm
```

#### Processing and test

So now that we have a pos-tagger transducer and a language model we can evaluate the test set. To do this, we have to first parse the test data file, take just the words and transpose the sentences in order to have one sentence per line.

```bash
cat NLSPARQL.test.feats.txt| cut -f1 | sed -e 's/^ *$/#/g' | tr '\n' ' ' | tr '#' '\n' | sed -e 's/^ *//' -e 's/ *$//' > test_sentences.data
```

Now we have to iterate over these sentences and predict the labels using the transducer + language model we have computed above.

```bash
# Create the transducer of the test sentence
head -1 ../data/test_sentences.data | farcompilestrings --symbols=../proc/lexicon.lex --unknown_symbol='<unk>' --generate_keys=1 --keep_symbols | farextract --filename_suffix='.fst' --filename_prefix='sentence'
# Predict the tags of the sentence
fstcompose sentence1.fst ../proc/transducers/pos-tagger_lm.fst | fstshortestpath | fstrmepsilon | fsttopsort | fstprint --isymbols=../proc/lexicon.lex --osymbols=../proc/lexicon.lex | cut -f 3,4
# see script for looping over all sentences to crate a complete prediction set.
```