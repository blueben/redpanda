#!/bin/sh

# Expect a file directory as input

red='\E[0;31m'
green='\E[0;32m'
bold='\E[1m'
blink='\E[5m'
reset='\E(B\E[m'
result_cursor='\E[80D'

echo -ne "\nSynchronizing git repositories\n\n"

for i in `ls -d -1 $1*`; do
  REPO=$(basename $i)
  echo -ne "\t\t${bold}$i${reset}${result_cursor}"
  cd $i
  result=`git status 2>&1 &&\
  git pull upstream master 2>&1 &&\
  git push --all origin 2>&1 &&\
  git push --all github 2>&1`

  if [ $? = 0 ]; then
    echo -ne "${green}Sync Success${reset}\n"
  else
    echo -ne "${red}Sync Failure${reset}\n\n"
    echo -ne "$result\n\n"
  fi
done

echo -ne "\nSynchronization complete\n"
