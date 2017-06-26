# =====================================
# makefile for whole project
# =====================================

MODULES = common gate game gamemanager dbproxy 

debug:all
release:all
all:
	@for dir in $(MODULES); do\
	( $(MAKE) -C $$dir $(MAKECMDGOALS) ) done


clean:
	@for dir in $(MODULES); do\
	( $(MAKE) -C $$dir clean ) done
	
.PHONY: all clean debug release
