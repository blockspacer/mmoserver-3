#############################################################
#                                                           #
#                Makefile for libmessage.a                     #
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

SRCDIR=$(PATH_SRC)/message/
OBJDIR=$(PATH_OBJ)/message/

SOURCE=$(wildcard *.cc)
SRC=$(notdir $(SOURCE))

SRCOBJ=$(patsubst %.c,%.o,$(patsubst %.cc,%.o,$(SRC)))
OBJ=$(addprefix $(OBJDIR), $(SRCOBJ))

OUTPUT=$(LIB_MESSAGE)

INC += -I./ $(PATH_SRC)//depslinux/protobuf-3.2.0/src
LIB += $(LIB_PROTOBUF)

debug:all
release:all
all:$(OBJ)
	@$(AR) cr $(OUTPUT) $(OBJ)
	@echo Create $(BUILD)  $(OUTPUT)

$(OBJDIR)%.o:%.cc
	@$(CXX) $(CXX_FLAGS) -c -o $@ $< $(INC) -I./include/event
	@echo compile $(BUILD)  $@

#@$(CXX) $(CXX_FLAGS)  $^ -o $@ $(LIB) -Wl,-Bstatic  -Wl,-Bdynamic -ldl  -lrt -lz
$(OBJDIR)%.o:%.c
	@$(CXX) $(CXX_FLAGS) -c -o $@ $(LIB) $< $(INC) -I./include/event
	@echo compile $(BUILD)  $@

clean:
	@rm -rf $(OBJ)
	@echo delete all .o file
	rm -rf $(OUTPUT)

.PHONY: all clean
