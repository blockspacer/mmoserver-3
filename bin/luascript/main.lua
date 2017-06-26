--------------------------------------------------------------------
-- 文件名:	scene.lua
-- 版  权:	(C) 华风软件
-- 创建人:	hou(houontherun@gmail.com)
-- 日  期:	2016/08/08
-- 描  述:	C++调用的入口文件
--------------------------------------------------------------------
-- 添加好require路径管理
GRunOnClient = false



package.path = package.path .. ";./luascript/?.lua;"
package.cpath = package.cpath .. ";./luascript/?.dll;./luascript/?.so"

math.randomseed(os.clock())

-- Common
require "tolua"

--data
require "data/common_char_chinese"
require "data/common_item"
require "data/challenge_main_dungeon"

--basic
require "basic/formula"
require "basic/tlby_table"
require "basic/chinese"
require "basic/scheme"
require "basic/net"
require "basic/fix_string"
require "basic/log"
require "basic/timer"

------------------
require "game_event"
require "configs/scheme_config"
require "entities/avatar"
require "entities/fight_avatar"
require "entities/pet"
require "entities/arena_dummy"
require "entities/items/item"
require "entities/items/inventory"
require "entities/entity_members/imp_assets"
require "entities/entity_members/imp_dungeon"
require "entities/entity_members/imp_property"
require "entities/entity_members/imp_pet"

md5.core.sum("214323423")

-- data
commonFightBase = require "data/common_fight_base"
scene_manager = require "scene/scene_manager"

