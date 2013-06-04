#!/bin/bash

extension=${1##*.}
result="${1##*/}"
js_result="$result"
result="${result%%.coffee}.js"

if [[ "$extension" == "js" ]]; then
  echo "Processing javascript"
  cp $1 googlified/$js_result
  sed -e '/module.exports/d' -i '' googlified/$js_result
elif [[ "$extension" == "coffee" ]]; then
  preproc=".preproc.${1}"
  echo Preprocessing....
  sed '/require/d' $1 > $preproc
  echo Making coffee...
  coffee -c $preproc
  echo Setting variables
  sed -e "2s/^/var ${1%%.coffee} = /" -i '' ${preproc%%.coffee}.js
  echo Replacing exports
  sed -e "s/module.exports = /return /" -i '' ${preproc%%.coffee}.js
  echo Moving around
  mv ${preproc%%.coffee}.js googlified/$result
else
  echo "Don't understand file type"
fi

