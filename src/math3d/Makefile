#############################################################
#                                                           #
#                Makefile for math3d.a                     #
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

SRCDIR=$(PATH_SRC)/math3dlinux/
OBJDIR=$(PATH_OBJ)/math3dlinux/

SOURCE=$(wildcard *.cpp)
SRC=$(notdir $(SOURCE))

SRCOBJ=$(patsubst %.c,%.o,$(patsubst %.cpp,%.o,$(SRC)))
OBJ=$(addprefix $(OBJDIR), $(SRCOBJ))

OUTPUT=$(LIB_MATH3D)

INC += ./

debug:all
release:all
all:$(OBJ)
	@$(AR) cr $(OUTPUT) $(OBJ)
	@echo Create $(BUILD)  $(OUTPUT)

$(OBJDIR)%.o:%.cpp
	@$(CXX) $(CXX_FLAGS) -c -o $@ $< $(INC)
	@echo compile $(BUILD)  $@

clean:
	@rm -rf $(OBJ)
	@echo delete all .o file
	rm -rf $(OUTPUT)

.PHONY: all clean
