#############################################################
#                                                           #
#                Makefile for gate                          #
#                Edit by hou 2016.12.19                     #
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
COMPILE_DIR = $(shell pwd |sed 's/^\(.*\)[/]//' )

SRCDIR=$(PATH_SRC)/$(COMPILE_DIR)/
OBJDIR=$(PATH_OBJ)/$(COMPILE_DIR)/
OBJ_DIR_EXIST = $(shell if [ -d $(OBJ_DIR) ]; then echo "exist"; else echo "notexist"; fi;)

ifeq ($(OBJ_DIR_EXIST), notexist)
	$(warning start make obj dir $(OBJ_DIR))
	$(shell mkdir $(OBJ_DIR))
endif


DIRS=$(shell ls $(SRC_DIR))

MODULE=$(addprefix $(SRC_DIR),$(DIRS))
VPATH=$(MODULE)

SOURCE=$(wildcard *.cpp)
SOURCE+=$(foreach subdir, ${MODULE}, $(wildcard ${subdir}/*.cpp))
SOURCE+=$(wildcard *.c)
SOURCE+=$(foreach subdir, ${MODULE}, $(wildcard ${subdir}/*.c))
SRC=$(notdir $(SOURCE))
SRCOBJ=$(patsubst %.c,%.o,$(patsubst %.cpp,%.o,$(SRC)))
OBJS=$(addprefix $(OBJ_DIR), $(SRCOBJ))

INC+=-I./ -I$(INC_COMM) $(INC_LIBEVENT) $(INC_LUA) $(INC_PROTOBUF) $(INC_INCLUDE) $(INC_MESSAGE)
LIB+= $(LIB_COMM) $(LIB_LIBEVENT) $(LIB_LUA)  $(LIB_MESSAGE) $(LIB_PROTOBUF) $(LIB_DETOUR) $(LIB_REDIS)
TARGET=$(PATH_BIN)/$(COMPILE_DIR)

all:$(OBJS)

$(OBJ_DIR)%.o: %.cpp
	@$(CXX) $(INC) $(CXX_FLAGS) -c $< -o $@
	@echo compile   $@
$(OBJ_DIR)%.o: %.c
	@$(CC) $(INC) $(C_FLAGS) -c $< -o $@
	@echo compile   $@
$(TARGET): $(OBJS)
	@$(CXX) $(CXX_FLAGS)  $^ -o $@ $(LIB) -Wl,-Bstatic  -Wl,-Bdynamic -ldl  -lrt -lz
	@echo -e "Create $@"
	@echo $(CXX) $(CXX_FLAGS)  $^ -o $@ $(LIB) -Wl,-Bstatic   -Wl,-Bdynamic -ldl  -lrt -lz

debug:all
release:all
all: $(TARGET)

clean:
	@rm -f $(TARGET) $(OBJS)
	@echo rm *.o  $(TARGET)

.PHONY:all clean debug release
