import pandas as pd
from math import log

# files needed to run this script:
# - proc/TOK_POS.counts > the counts of the couples word-tag
# - proc/POS.counts > the counts of the tags
# - models/lexicon_cutoff.lex > the cutoff lexicon

wt = pd.read_csv('../proc/TOK_POS.counts', sep=' ', names=['word_tag_count', 'word', 'tag'])
t = pd.read_csv('../proc/POS.counts', sep=' ', names=['tag_count', 'tag'])


# iterate over all entries in the DataFrame containing the couples <word, tag>
# and divide the count of each couple by the corresponding tag count
probs = []
for val in wt.values:
    # take the corresponding tag count
    tag_count = t.loc[t['tag'] == val[2]]['tag_count'].values[0]
    # compute the probability
    prob = val[0] / tag_count
    # compute the -log cost to be used in the transducer
    log_cost = -log(prob)
    # append to result [word, tag, prob(w|t), -log(prob)]
    probs.append([val[1], val[2], prob, log_cost])

# we also have to take care of unknown words when creating the
# transducer file
# Each entry will be P(<unk>|t_i) = 1/C(t), so these probs are equally probable
# for every tag.
unk_prob = 1 / t.shape[0]
unk_cost = -log(unk_prob)

# write to file
# TOK_POS.probs file: <word, tag, prob(w|t), log_cost>
# TOK_POS.transducer: <0, 0, word, tag, log_cost>
with open('../proc/TOK_POS.probs', 'w') as f, open('../proc/TOK_POS.transducer', 'w') as g:
    for val in probs:
        f.write("{} {} {} {}\n".format(val[0], val[1], val[2], val[3]))
        g.write("0 0 {} {} {}\n".format(val[0], val[1], val[3]))
    for i in range(0, t.shape[0]):
        g.write("0 0 <unk> {} {}\n".format(t.loc[i]['tag'], unk_cost))
    g.write("0")

# -------

# here we try to build a transducer that does not contain words that have been cutoff

lexicon_cutoff = pd.read_csv('../models/lexicon_cutoff.lex', sep='\t', names=['word', 'num'])
lexicon_cutoff['word'].str.contains('producer').any()

# so we load the transducer and delete the rows that we do not want
with open('../proc/TOK_POS.transducer', 'r') as trs, open('../proc/TOK_POS_cutoff.transducer', 'w') as trs_cutoff:
    lines = trs.readlines()
    for l in lines:
        spl = l.split(' ')
        if len(spl) > 3:
            if spl[2] != '<unk>':
                # if the word is in the cutoff lexicon, in this way we do not consider
                # words that have been cutoff
                if lexicon_cutoff['word'].str.match('^' + spl[2] + '$').any():
                    trs_cutoff.write(l)
    # handle unknown words
    for i in range(0, t.shape[0]):
        trs_cutoff.write("0 0 <unk> {} {}\n".format(t.loc[i]['tag'], unk_cost))
    trs_cutoff.write("0")

