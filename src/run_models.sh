#!/usr/bin/env bash

for gram_size in {2..4}
do
    for smoothing in 'unsmoothed' 'witten_bell' 'absolute' 'katz' 'kneser_ney'
        do
            ./evaluate_test_set.sh ${gram_size} ${smoothing}
        done
done


for gram_size in {2..4}
do
    ./evaluate_test_set.sh ${gram_size} 'unsmoothed'
done