#!/usr/bin/env bash

SMOOTHING=('witten_bell' 'absolute' 'katz' 'kneser_ney')

for gram_size in {2..4}
do
    for smoothing in ${SMOOTHING[@]}
        do
            ./evaluate_test_set.sh ${gram_size} ${smoothing}
        done
done
