#!/bin/bash

read -p "Entering working dir for storing temp stuffs: " wd
cd $wd
echo "***Working dir***: `pwd`"

read -p "Entering git repo address: " gitrepo
git clone $gitrepo

proj=${gitrepo##*/}
cd $proj

ls
read -p "Which version do your work applied on: " version
cd vdsm-$version
echo "***Currently in: `pwd`"

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

read -p "Where is the git code repo: " vdsm
if [[ $vdsm != */ ]]
then
	vdsm=$vdsm"/"
fi


cd $vdsm
#just checkout or create branch?
git branch -a
read -p "Create or just checkout branch[(c)checkout,(b)create]?: " bran
case $bran in
	[cC]*)
		read -p "Enter branch name to be checkout: " bname
		if [[ !$bname ]];
		then
			echo "*****using current branch********"
		else
			git checkout $bname
		fi
		;;
	[bB]*)
		read -p "Entering branch prefix: " bpre
		git checkout "v"$version -b $bpre$version
		;;
esac


cd $wd"/"$proj"/vdsm-"$version 

for((i=0;i<${#arr[@]};i++))
do
	read -p "cp ${arr[i]} to $vdsm${loc[i]}?[(y)apply,()skip]:" action
	case $action in
		[yY]*)
			cp ${arr[i]} -f $vdsm${loc[i]}
			echo "ok";;
		*)
			echo "skip";;
	esac 
done

cd $vdsm
echo "***Currently in: `pwd`"
git status

for((i=0;i<${#arr[@]};i++))
do
	read -p "git add ${loc[i]}${arr[i]}?[(y)apply,()skip] " action
	case $action in
		[yY]*)
			git add ${loc[i]}${arr[i]}
			echo "ok";;
		*)
			echo "skip";;
	esac 
done

read -p "Commit changes?[(y)apply,()skip]: " commit

case $commit in
	[yY]*)
		echo "ok";;
	*)
		echo "exit"
		exit;;
esac

read -p "commit messages[one word]: " cmtmsg
git commit -m $cmtmsg

while true
do
	read -p "Add git ver number?[(y)apply,()skip]: " gitnum
	case $gitnum in
		[yY]*)
			echo "hello,world" >> rpmmake.txt
			git add rpmmake.txt
			git commit -m "add git num";;
		*)
			break;;
	esac
done

git clean -xfd
./autogen.sh --system
make

rm -rf /root/rpmbuild/RPMS/*/vdsm*.rpm
make rpm

git checkout master
#git branch -D "tmp"$version 

cd /root
read -p "Where to put .tar.gz?: " rpm
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
