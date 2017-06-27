cd ../../git_stable/bin
git pull
rsync -avz ./luascript shangyz@10.0.253.11:~/bin
ssh shangyz@10.0.253.11 "cd bin; ./kill.sh;sleep 2; ./start.sh"