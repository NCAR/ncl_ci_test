#!/bin/bash

verbose=true

declare -a ncl_fail
declare -a identical
declare -a similar
declare -a different

for dir in */; do
    unset dir_ncl_fail
    unset dir_identical
    unset dir_similar
    unset dir_different
    declare -a dir_ncl_fail
    declare -a dir_identical
    declare -a dir_similar
    declare -a dir_different

    dir=${dir%%/} # remove trailing /
    cd $dir
    mkdir -p bad
    for s in *.ncl; do
        png=${s%%.ncl}.png

        ncl -Q $s >/dev/null
        ncl_ret=$?
        if [[ $ncl_ret -ne 0 ]]; then
            dir_ncl_fail+=( $png )
        fi

        cmp images/$png $png 2>/dev/null
        cmp_ret=$?
        if [[ $cmp_ret -eq 0 ]]; then
            rm $png
            dir_identical+=( $png )
            continue
        fi

        mv $png bad/.
        compare -metric DSSIM images/$png bad/$png null 2>/dev/null
        compare_ret=$?

        if [[ $compare_ret -eq 0 ]]; then
            dir_similar+=( $png )
        else
            dir_different+=( $png )
        fi
    done
    cd ..

    ncl_fail+=( ${dir_ncl_fail[@]} )
    identical+=( ${dir_identical[@]} )
    similar+=( ${dir_similar[@]} )
    different+=( ${dir_different[@]} )

    echo $dir:
    if $verbose; then
        echo -e "    identical: ${#dir_identical[@]}"
        echo -e "    similar: ${#dir_similar[@]}"
        echo -e "    different: ${#dir_different[@]}"
        if [[ ${#dir_different[@]} -gt 0 ]]; then
            echo -e "        ${dir_different[@]}"
        fi
        echo -e "    NCL failure: ${#dir_ncl_fail[@]}"
        if [[ ${#dir_ncl_fail[@]} -gt 0 ]]; then
            echo -e "        ${dir_ncl_fail[@]}"
        fi
        echo
    else
        echo -e "    pass: $(( ${#dir_identical[@]} + ${#dir_similar[@]} ))"
        echo -e "    fail: $(( ${#dir_different[@]} + ${#dir_ncl_fail[@]} ))"
        if [[ $(( ${#dir_different[@]} + ${#dir_ncl_fail[@]} )) -gt 0 ]]; then
            echo -e "        ${dir_ncl_fail[@]} ${dir_different[@]}"
        fi
        echo
    fi
done


echo total:
if $verbose; then
    echo ${#identical[@]} identical
    echo ${#similar[@]} similar
    echo ${#different[@]} different
    echo ${#ncl_fail[@]} NCL failures
else
    echo $(( ${#dir_identical[@]} + ${#dir_similar[@]} )) pass
    echo $(( ${#dir_different[@]} + ${#dir_ncl_fail[@]} )) fail
fi

if [[ $(( ${#dir_different[@]} + ${#dir_ncl_fail[@]} )) -gt 0 ]]; then
    exit 1
fi
