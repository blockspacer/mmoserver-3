#pragma once
#ifndef _COMMON_DEFINE_H_
#include <string>
#include <stdint.h>
#include <map>
#include <string>
#include <set>
#include <memory>
#include <assert.h>

enum SCENE_TYPE
{
	SCENE_TYPE_INVALID = 0,
	SCENE_TYPE_CITY = 1,  //主城，不进行战斗，人多，同步不用很严格
	SCENE_TYPE_FIELD = 2, //野外，人多，同步压力大
	SCENE_TYPE_DUNGEON = 3, //副本，人少，可以直接广播
	SCENE_TYPE_MAX = 4
};

typedef std::string   ENTITYID;
typedef uint32_t   PROXYID;


#define  MAX_LIBEVENT_CONNECTION  8000 

#define	SAFE_DELETE(p)		{if(p){delete (p); (p) = nullptr;}}
#define SAFE_DELARR(p)		{if(p){delete[] (p); (p) = nullptr;}}

#endif

