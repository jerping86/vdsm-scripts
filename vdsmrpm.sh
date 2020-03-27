#!/bin/bash


read -p "Entering working dir for storing temp stuffs: " wd
while [ ! -d $wd ]
do
	read -p $wd" doesn't exist, please input some real folder: " wd
done

cd $wd
echo "***Working dir***: `pwd`"
if [[ $wd != */ ]]
then
	wd=$wd"/"
fi


read -p "Entering git repo address: " gitrepo
git clone $gitrepo

proj=${gitrepo##*/}
cd $proj

ls
read -p "Which version do your work applied on: " version
cd vdsm-$version
echo "***Currently in: `pwd`"


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

read -p "Where is the main code repo: " vdsm
if [[ $vdsm != */ ]]
then
	vdsm=$vdsm"/"
fi


cd $vdsm

git branch -a
#record current branch
gbaline=$(git branch -a | awk '/^[*]/{print $0}')
oldbranch=${gbaline#\* }
echo "*****Current branch: "$oldbranch

crtbranch="no"
chkbranch="no"
#just checkout or create branch?
read -p "Create or just checkout branch[(c)checkout,(b)create]?: " bran
case $bran in
	[cC]*)
		read -p "Enter branch name to be checkout: " bname
		if [[ !$bname ]];
		then
			echo "*****using current branch********"
		else
			git checkout $bname
			chkbranch="yes"
		fi
		;;
	[bB]*)
		read -p "Entering branch prefix: " bpre
		git checkout "v"$version -b $bpre$version
		crtbranch="yes"
		chkbranch="yes"
		;;
esac


cd $wd$proj"/vdsm-"$version 
mkdir bak
for((i=0;i<${#arr[@]};i++))
do
	read -p "cp ${arr[i]} to $vdsm${loc[i]}?[(y)apply,()skip]:" action
	case $action in
		[yY]*)
			if [ -f $vdsm${loc[i]}${arr[i]} ]
			then
				cp $vdsm${loc[i]}${arr[i]} bak/
				echo ${arr[i]}"   "$vdsm${loc[i]}"   c" >> bak/position.txt
			else
				echo ${arr[i]}"   "$vdsm${loc[i]}"   d" >> bak/position.txt
			fi
			cp ${arr[i]} -f $vdsm${loc[i]}
			echo "ok";;
		*)
			echo "skip";;
	esac 
done

cd $vdsm
echo "***Currently in: `pwd`"
git status


read -p "Stash changes?[(y)apply,(r)reset]: " commit
case $commit in
	[yY]*)
		git add .
		echo "ok";;
	[rR]*)
		cd $wd$proj"/vdsm-"$version"/bak/"
		file_changed=$(cat position.txt | awk '//{print $1}')
		file_locs=$(cat position.txt | awk '//{print $2}')
		file_act=$(cat position.txt | awk '//{print $3}')
		i=0
		for var in ${file_changed[@]}
		do
			ano[i]=$var
			let i=i+1
		done

		i=0
		for var in ${file_locs[@]}
		do
			floc[i]=$var
			if [[ $var != */ ]]
			then
				floc[i]=$var"/"
			fi
			let i=i+1
		done
		
		i=0
		for var in ${file_act[@]}
		do
			fact[i]=$var
			let i=i+1
		done
		
		for((i=0;i<${#ano[@]};i++))
		do
			if [ ${fact[i]} == "c" ]
			then
				echo "*****restore file: "${ano[i]}" in "${floc[i]}
				cp ${ano[i]} -f ${floc[i]}
			else
				echo "*****delete file: "${ano[i]}" in "${floc[i]}
				rm -f ${floc[i]}${ano[i]}
			fi
		done
		
		cd $vdsm
		if [ $chkbranch == "yes" ]
		then
			git checkout $oldbranch
		fi
		if [ $crtbranch == "yes" ]
		then
			git branch -D $bpre$version	
		fi
		cd $wd
		echo "we are in `pwd`"
		echo "removing vdsm..."
		rm -rf $proj
		echo "we are done..."
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

rm -f build-aux/config.guess
rm -f build-aux/config.sub

if [ $chkbranch == "yes" ]
then
	git checkout $oldbranch
fi

if [ $crtbranch == "yes" ]
then
	git branch -D $bpre$version	
fi



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
