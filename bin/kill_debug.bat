cd /d E:\tlby\server_new\Bin

@echo 关闭所有游戏服(指令)
python close_server.py 4050

@echo 关闭所有DB服
@taskkill /f /im dbproxy2.exe

@echo 关闭所有网关服
@taskkill /f /im gate2.exe


@echo 关闭所有游戏服（强制）
@taskkill /f /im game2.exe

@echo 关闭所有游戏服（强制）
@taskkill /f /im gamemanager2.exe