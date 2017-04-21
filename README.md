## LUS MidTerm Project - POS Tagging

- We want to do sequence labeling: assignment of a categorical label to a new observation based on the categories on the training data.
- The simple approach is to treat independently each member of the sequence (word), but performance clearly improves when we consider dependency with nearby elements.
- Using a Markov Model we can say that we estimate the sequence of tags from a sequence of words as the sequence of tags that **maximizes** the probability of the tags given the words.
- Using an independence assumption we can rewrite the full join distribution as the product of the probability of a certain word given its tag *times* the probability of a tag given the previous one, for all the sequence.
- These two probabilities can be estimated using the counts on the training set.


#### Processing

The scripts to process and evaluate the data are under the `/src` folder. The `process_data.sh` script will take the training corpus and produce some files used to build the models:

- a lexicon, which contains all unique words and tags present in the training set
- a cutoff lexicon, which removes words form the standard lexicon that appear only once or more that one hundred times in the training set
- a `POS.counts` file which stores the unique counts of the tags present in the training set
- a `TOK_POS.counts` file which stores the unique counts the couples word-tag present in the training set
- Then it uses `compute_probabilities.py` to compute the actual $P(w_i | t_i)$ from the counts. This scripts will generate two files:
	- `TOK_POS.prob`: which contains \<word, tag, prob, log_cost\>
	- `TOK_POS.transducer`: which is the file to use to crate the transducer (with a single state). In this file we already take care of the unknown words we could find in the test set. See the source file for additional comments on this.
- The last step produces the transducers `pos-tagger.fst` and `pos-tagger_cutoff.fst`, which are just the compiled version of the transducers computed before

#### Evaluation

Once we have all the needed files, we have start to evaluate the models on the test set.

The script `evaluate_test_set.sh` take care of:

- converting training and test sets from a token-per-line format to a sentence-per-line format.
- then it computes an n-gram language model based on the specified gram size and smoothing method and composes it with the pos-tagger created previously
- it iterates over all sentences of the test data and predicts the labels
- finally it evaluates the prediction using `conlleval.pl`

The various models are run using the `run_models.sh` script which iterated over all desired parameters and gives them to `evalute_test_set.sh`.