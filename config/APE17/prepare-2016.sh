#!/usr/bin/env bash

# Summary of the task at: http://www.statmt.org/wmt16/ape-task.html
# interesting papers on the subject:
# https://arxiv.org/abs/1606.07481:   multi-source, no additional data, predicts a sequence of edits
# https://arxiv.org/abs/1605.04800:   merges two mono-source models, lots of additional (parallel data), creates
# synthetic PE data by using back-translation

raw_data=raw_data/APE17
data_dir=data/APE17

max_vocab_size=30000
max_char_vocab_size=200

rm -rf ${data_dir}
mkdir -p ${data_dir}




cp ${raw_data}/train.{mt,pe,src} ${data_dir}
cp ${raw_data}/{dev,test,500K}.{src,mt,pe} ${data_dir}

scripts/post_editing/extract-edits.py ${data_dir}/train.{mt,pe} > ${data_dir}/train.edits
scripts/post_editing/extract-edits.py ${data_dir}/dev.{mt,pe} > ${data_dir}/dev.edits
scripts/post_editing/extract-edits.py ${data_dir}/test.{mt,pe} > ${data_dir}/test.edits
scripts/post_editing/extract-edits.py ${data_dir}/500K.{mt,pe} > ${data_dir}/500K.edits

cp ${data_dir}/500K.mt ${data_dir}/train.concat.mt
cp ${data_dir}/500K.pe ${data_dir}/train.concat.pe
cp ${data_dir}/500K.src ${data_dir}/train.concat.src
cp ${data_dir}/500K.edits ${data_dir}/train.concat.edits

for i in {1..20}; do   # oversample PE data
    cat ${data_dir}/train.mt >> ${data_dir}/train.concat.mt
    cat ${data_dir}/train.pe >> ${data_dir}/train.concat.pe
    cat ${data_dir}/train.src >> ${data_dir}/train.concat.src
    cat ${data_dir}/train.edits >> ${data_dir}/train.concat.edits
done

cat ${data_dir}/train.{mt,pe} > ${data_dir}/train.de
cat ${data_dir}/train.concat.{mt,pe} > ${data_dir}/train.concat.de

# prepare subwords

scripts/learn_bpe.py -i ${data_dir}/train.de -o ${data_dir}/bpe.de -s ${max_vocab_size} --min-freq 5
scripts/learn_bpe.py -i ${data_dir}/train.src -o ${data_dir}/bpe.src -s ${max_vocab_size} --min-freq 5

scripts/apply_bpe.py -i ${data_dir}/train.de -o ${data_dir}/train.subwords.de -c ${data_dir}/bpe.de
for corpus in train dev test; do
    scripts/apply_bpe.py -i ${data_dir}/${corpus}.mt -o ${data_dir}/${corpus}.subwords.mt -c ${data_dir}/bpe.de
    scripts/apply_bpe.py -i ${data_dir}/${corpus}.pe -o ${data_dir}/${corpus}.subwords.pe -c ${data_dir}/bpe.de
    scripts/apply_bpe.py -i ${data_dir}/${corpus}.src -o ${data_dir}/${corpus}.subwords.src -c ${data_dir}/bpe.src
done

scripts/learn_bpe.py -i ${data_dir}/train.concat.de -o ${data_dir}/bpe.concat.de -s ${max_vocab_size} --min-freq 5
scripts/learn_bpe.py -i ${data_dir}/train.concat.src -o ${data_dir}/bpe.concat.src -s ${max_vocab_size} --min-freq 5

scripts/apply_bpe.py -i ${data_dir}/train.concat.de -o ${data_dir}/train.concat.subwords.de -c ${data_dir}/bpe.de
scripts/apply_bpe.py -i ${data_dir}/train.concat.mt -o ${data_dir}/train.concat.subwords.mt -c ${data_dir}/bpe.de
scripts/apply_bpe.py -i ${data_dir}/train.concat.pe -o ${data_dir}/train.concat.subwords.pe -c ${data_dir}/bpe.de
scripts/apply_bpe.py -i ${data_dir}/train.concat.src -o ${data_dir}/train.concat.subwords.src -c ${data_dir}/bpe.src
for corpus in dev test; do
    scripts/apply_bpe.py -i ${data_dir}/${corpus}.mt -o ${data_dir}/${corpus}.concat.subwords.mt -c ${data_dir}/bpe.de
    scripts/apply_bpe.py -i ${data_dir}/${corpus}.pe -o ${data_dir}/${corpus}.concat.subwords.pe -c ${data_dir}/bpe.de
    scripts/apply_bpe.py -i ${data_dir}/${corpus}.src -o ${data_dir}/${corpus}.concat.subwords.src -c ${data_dir}/bpe.src
done

# prepare vocabs

scripts/prepare-data.py ${data_dir}/train src de edits ${data_dir} --mode vocab --vocab-size 0
scripts/prepare-data.py ${data_dir}/train.concat src de edits ${data_dir} --mode vocab --vocab-prefix vocab.concat \
--vocab-size ${max_vocab_size}

scripts/prepare-data.py ${data_dir}/train src de ${data_dir} --mode vocab --vocab-size 0 --character-level \
--vocab-prefix vocab.char --vocab-size ${max_vocab_size}
scripts/prepare-data.py ${data_dir}/train.concat src de ${data_dir} --mode vocab --vocab-prefix vocab.concat \
--vocab-size ${max_char_vocab_size} --character-level --vocab-prefix vocab.concat.char

scripts/prepare-data.py ${data_dir}/train.subwords src de ${data_dir} --vocab-prefix vocab.subwords \
--no-tokenize --vocab-size 0 --mode vocab

scripts/prepare-data.py ${data_dir}/train.concat.subwords src de ${data_dir} --vocab-prefix vocab.concat.subwords \
--no-tokenize --vocab-size 0 --mode vocab

for vocab in vocab vocab.concat vocab.subwords vocab.concat.subwords vocab.char vocab.concat.char; do
    cp ${data_dir}/${vocab}.de ${data_dir}/${vocab}.mt
    cp ${data_dir}/${vocab}.de ${data_dir}/${vocab}.pe
done
