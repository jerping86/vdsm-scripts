#!/bin/bash

read -p "Entering working dir:" wd
cd $wd
echo "working dir: `pwd`"

read -p "Entering git repo address:" gitrepo
git clone $gitrepo

proj=${gitrepo##*/}
cd $proj
ls
read -p "What version do you work:" version
cd vdsm-$version
echo "we are in `pwd`"

#b=$(cat position.txt | awk '//{cmd="mv -f "$1" ~/tmp/"$1;system(cmd)}{print $2$1}')

file_replaced=$(cat position.txt | awk '//{print $1}')
file_location=$(cat position.txt | awk '//{print $2}')

i=0
for var in ${file_replaced[@]}
do
	arr[i]=$var
	let i=i+1
done

i=0
for var in ${file_location[@]}
do
	loc[i]=$var
	if [[ ${loc[i]} != */ ]]
	then
		loc[i]=${loc[i]}"/"
	fi
	let i=i+1
done

read -p "Where is the vdsm:" vdsm
if [[ $vdsm != */ ]]
then
	vdsm=$vdsm"/"
fi

read -p "Entering branch prefix: " bpre

cd $vdsm
git checkout "v"$version -b $bpre$version
cd $wd"/"$proj"/vdsm-"$version 

for((i=0;i<${#arr[@]};i++))
do
	read -p "cp ${arr[i]} to $vdsm${loc[i]}?:" action
	case $action in
		[yY]*)
			cp ${arr[i]} -f $vdsm${loc[i]}
			echo "ok";;
		*)
			echo "skip";;
	esac 
done

cd $vdsm
echo "we are in `pwd`"
git status

for((i=0;i<${#arr[@]};i++))
do
	read -p "git add ${loc[i]}${arr[i]}? " action
	case $action in
		[yY]*)
			git add ${loc[i]}${arr[i]}
			echo "ok";;
		*)
			echo "skip";;
	esac 
done

read -p "commit changes?:" commit

case $commit in
	[yY]*)
		echo "ok";;
	[sS]*)
		echo "exit"
		exit;;
esac

read -p "commit messages: " cmtmsg
git commit -m $cmtmsg

while true
do
	read -p "add git ver number? " gitnum
	case $gitnum in
		[yY]*)
			echo "hello,world" >> rpmmake.txt
			git add rpmmake.txt
			git commit -m "add git num";;
		*)
			break;;
	esac
done

read -p "confirm git commit: " dummy
git clean -xfd
./autogen.sh --system
make

rm -rf /root/rpmbuild/RPMS/*/vdsm*.rpm
make rpm

git checkout master
#git branch -D "tmp"$version 

cd /root
read -p "where to put .tar.gz?: " rpm
if [[ $rpm != */ ]]
then
	rpm=$rpm"/"
fi

tar czvf $rpm"v"$version".tar.gz" rpmbuild/RPMS/


cd $wd
echo "we are in `pwd`"
echo "removing vdsm..."
rm -rf $proj
echo "we are done..."
