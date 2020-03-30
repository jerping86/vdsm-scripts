#!/bin/bash

end_with_slash(){
	dummy=$1
	if [[ $1 != */ ]]
	then
		dummy=$dummy"/"
	fi
	echo $dummy
}

read -e -p "Entering working dir for storing temp stuffs: " wd
wd=${wd/#~/$HOME}
while [ ! -d $wd ]
do
	read -e -p $wd" doesn't exist, please input some real folder: " wd
	wd=${wd/#~/$HOME}
done

echo "cd...ing..."
sleep 2s
cd $wd
echo "***Working dir***: `pwd`"
wd=$(end_with_slash $wd)


read -p "Entering git repo address: " gitrepo
git clone $gitrepo

proj=${gitrepo##*/}
cd $proj

ls
read -p "Which version do your work applied on: " version

read -e -p "Where is the main code repo: " vdsm
vdsm=${vdsm/#~/$HOME}
vdsm=$(end_with_slash $vdsm)
echo $vdsm

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

file_changed=($(awk '//{print $1}' position.txt))
temp_vdsmdir=($(awk '//{print $2}' position.txt))

i=0
for var in ${temp_vdsmdir[@]}
do
	file_vdsmdir[i]=$(end_with_slash $var)
	echo ${file_vdsmdir[i]}
	let i=i+1
done

mkdir bak
makechanges="no"
applied_cnt=0
for((i=0;i<${#file_changed[@]};i++))
do
	read -p "cp ${file_changed[i]} to $vdsm${file_vdsmdir[i]}?[(y)apply,()skip]:" action
	case $action in
		[yY]*)
			if [ -f $vdsm${file_vdsmdir[i]}${file_changed[i]} ]
			then
				cp $vdsm${file_vdsmdir[i]}${file_changed[i]} bak/
				echo ${file_changed[i]}"   "$vdsm${file_vdsmdir[i]}"   c" >> bak/position.txt
			else
				echo ${file_changed[i]}"   "$vdsm${file_vdsmdir[i]}"   d" >> bak/position.txt
			fi
			cp ${file_changed[i]} -f $vdsm${file_vdsmdir[i]}
			let applied_cnt=applied_cnt+1
			makechanges="yes"
			echo "ok";;
		*)
			echo "skip";;
	esac 
done

echo "*****"$applied_cnt" changes."

echo "cd...ing..."
sleep 2s
cd $vdsm
echo "***Currently in: `pwd`"
git status


read -p "Stash changes?[(y)apply,(r)reset]: " commit
case $commit in
	[yY]*)
		git add .
		echo "ok";;
	[rR]*)
		if [ $makechanges == "yes" ]
		then
			cd $wd$proj"/vdsm-"$version"/bak/"
			file_applied=($(awk '//{print $1}' position.txt))
			temp_dir=($(awk '//{print $2}' position.txt))
			file_moveact=($(awk '//{print $3}' position.txt))

			i=0
			for var in ${temp_dir[@]}
			do
				file_dir[i]=$(end_with_slash $var)
				let i=i+1
			done
			
			for((i=0;i<${#file_applied[@]};i++))
			do
				if [ ${file_moveact[i]} == "c" ]
				then
					echo "*****restore file: "${file_applied[i]}" in "${file_dir[i]}
					cp ${file_applied[i]} -f ${file_dir[i]}
				else
					echo "*****delete file: "${file_applied[i]}" in "${file_dir[i]}
					rm -f ${file_dir[i]}${file_applied[i]}
				fi
			done
		fi	

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

make_rpm(){
	git clean -xfd
	./autogen.sh --system
	make

	rm -rf /root/rpmbuild/RPMS/*/vdsm*.rpm
	make rpm
}

make_rpm

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
rpm=$(end_with_slash $rpm)

tar czvf $rpm"v"$version".tar.gz" rpmbuild/RPMS/


cd $wd
echo "we are in `pwd`"
echo "removing vdsm..."
rm -rf $proj
echo "we are done..."
