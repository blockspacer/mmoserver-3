#############################################################
#                                                           #
#                Makefile for libdetour.a                     #
#                Edit by hou 2016.12.19               #
#############################################################

###################Parse Build Flag##########################
MAKECMDGOALS ?= debug

ifeq ($(MAKECMDGOALS),release)
BUILD = RELEASE
else
BUILD = DEBUG
endif
#############################################################

include ../makeinclude/makefile_comm

SRCDIR=$(PATH_SRC)/detourlinux/
OBJDIR=$(PATH_OBJ)/detourlinux/

SOURCE=$(wildcard *.cpp)
SRC=$(notdir $(SOURCE))

SRCOBJ=$(patsubst %.c,%.o,$(patsubst %.cpp,%.o,$(SRC)))
OBJ=$(addprefix $(OBJDIR), $(SRCOBJ))

OUTPUT=$(LIB_DETOUR)

INC += ./

debug:all
release:all
all:$(OBJ)
	@$(AR) cr $(OUTPUT) $(OBJ)
	@echo Create $(BUILD)  $(OUTPUT)

$(OBJDIR)%.o:%.cpp
	@$(CXX) $(CXX_FLAGS) -c -o $@ $< $(INC) -I./include/event
	@echo compile $(BUILD)  $@

$(OBJDIR)%.o:%.c
	@$(CXX) $(CXX_FLAGS) -c -o $@ $< $(INC) -I./include/event
	@echo compile $(BUILD)  $@

clean:
	@rm -rf $(OBJ)
	@echo delete all .o file
	rm -rf $(OUTPUT)

 .PHONY: all clean
