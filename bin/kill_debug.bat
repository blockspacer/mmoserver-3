cd /d E:\tlby\server_new\Bin

@echo �ر�������Ϸ��(ָ��)
python close_server.py 4050

@echo �ر�����DB��
@taskkill /f /im dbproxy2.exe

@echo �ر��������ط�
@taskkill /f /im gate2.exe


@echo �ر�������Ϸ����ǿ�ƣ�
@taskkill /f /im game2.exe

@echo �ر�������Ϸ����ǿ�ƣ�
@taskkill /f /im gamemanager2.exe