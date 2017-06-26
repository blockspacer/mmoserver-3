--------------------------------------------------------------------
-- 文件名:	constant.lua
-- 版  权:	(C) 华风软件
-- 创建人:	hou(houontherun@gmail.com)
-- 日  期:	2016/08/08
-- 描  述:	常量文件，存放各种常量
--------------------------------------------------------------------

return {
    -- 场景类型
    SCENE_TYPE_CASTLE = 1,
    SCENE_TYPE_FIELD = 2,

    -- 场景元素类别
    ENTITY_TYPE_PLAYER = 1,
    ENTITY_TYPE_NPC = 2,
    ENTITY_TYPE_MONSTER = 3,
    ENTITY_TYPE_PET = 4,
    ENTITY_TYPE_ARENA_DUMMY = 5,
    ENTITY_TYPE_FIGHT_AVATAR = 6,
    ENTITY_TYPE_DUNGEON_NPC = 7,                            --副本npc
    ENTITY_TYPE_WILD_PET = 10,                               --野外宠物
    ENTITY_TYPE_BIRTHDAY_POS = 11,
    ENTITY_TYPE_WAYOUT = 13,
    ENTITY_TYPE_POSITION = 14,
    ENTITY_TYPE_COUNTRY_MONSTER = 23,                       --阵营怪物
    ENTITY_TYPE_TRANSPORT_FLEET = 24,                       --运输车队
    ENTITY_TYPE_COUNTRY_BOSS = 25,                          --阵营Boss
    ENTITY_TYPE_COUNTRY_BOSS_LEADER = 26,                   --阵营总Boss
    ENTITY_TYPE_COUNTRY_ARCHER_TOWER = 27,                  --阵营箭塔
    ENTITY_TYPE_COUNTRY_GUARD_NPC = 28,                     --守卫npc
    ENTITY_TYPE_MONSTER_TRANSPORT_GATE = 29,                --怪物传送门

    -- 职业
    VOCATION_ID_TO_NAME = {
        [1] = "swordman",
        [2] = "boxer",
        [3] = "wizard",
        [4] = "bowman",
    },


    --副本编号
    DUNGEON_NOT_EXIST = -1,

    --网络消息
    MESSAGE_LUA_START = 100,               --消息索引开始，无此指令
    SC_MESSAGE_LUA_UPDATE = 101,           --更新状态
    CS_MESSAGE_LUA_LOGIN = 102,            --玩家登陆
    SC_MESSAGE_LUA_LOGIN = 103,            --玩家登陆的服务器反馈
    CS_MESSAGE_LUA_START_DUNGEON = 104,    --开始副本
    SC_MESSAGE_LUA_START_DUNGEON = 105,    --开始副本的服务器反馈
    CS_MESSAGE_LUA_END_DUNGEON = 106,      --结束副本
    SC_MESSAGE_LUA_END_DUNGEON = 107,      --结束副本的服务器反馈
    CS_MESSAGE_LUA_QUIT_DUNGEON = 108,     --强制退出副本
    SC_MESSAGE_LUA_QUIT_DUNGEON = 109,     --强制退出副本的服务器反馈
    SC_MESSAGE_LUA_REQUIRE = 110,          --获得奖励
    SC_MESSAGE_LUA_ERROR_MESSAGE = 111,    --服务器传给客户端的错误消息
    CS_MESSAGE_LUA_BAG_GET_ALL = 112,      --获取所有背包物品
    SC_MESSAGE_LUA_BAG_GET_ALL = 113,      --获取背包物品的服务器反馈
    CS_MESSAGE_LUA_ITEM_USE = 114,         --使用道具
    SC_MESSAGE_LUA_ITEM_USE = 115,         --使用道具的服务器反馈
    CS_MESSAGE_LUA_ITEM_SPLIT = 116,       --道具拆分
    SC_MESSAGE_LUA_ITEM_SPLIT = 117,       --道具拆分的服务器反馈
    CS_MESSAGE_LUA_ITEM_SELL = 118,        --道具出售
    SC_MESSAGE_LUA_ITEM_SELL = 119,        --道具出售的服务器反馈
    CS_MESSAGE_LUA_BAG_ARRANGE = 120,      --背包整理
    SC_MESSAGE_LUA_BAG_ARRANGE = 121,      --背包整理的服务器反馈
    CS_MESSAGE_LUA_START_CAPTURE_PET = 122,--开始抓宠
    SC_MESSAGE_LUA_START_CAPTURE_PET = 123,--开始抓宠的服务器反馈
    CS_MESSAGE_LUA_CAPTURE_RET = 124,      --抓宠结果
    SC_MESSAGE_LUA_CAPTURE_RET = 125,      --抓宠结果的服务器反馈
    CS_MESSAGE_LUA_CANCEL_CAPTURE = 126,   --取消抓宠
    SC_MESSAGE_LUA_CANCEL_CAPTURE = 127,   --取消抓宠的服务器反馈
    CS_MESSAGE_LUA_LOAD_EQUIPMENT = 128,   --装备加载
    SC_MESSAGE_LUA_LOAD_EQUIPMENT = 129,   --装备加载的服务器反馈
    CS_MESSAGE_LUA_UNLOAD_EQUIPMENT = 130, --装备卸载
    SC_MESSAGE_LUA_UNLOAD_EQUIPMENT = 131, --装备卸载的服务器反馈
    CS_MESSAGE_LUA_UNLOCK_CELL = 132,      --背包格子解锁
    SC_MESSAGE_LUA_UNLOCK_CELL = 133,      --背包格子解锁的服务器反馈
    CS_MESSAGE_LUA_GM = 134,               --gm指令
    SC_MESSAGE_LUA_GM = 135,               --gm指令的服务器反馈
    CS_MESSAGE_LUA_SEAL_UPGRADE = 136,     --宝印升级
    SC_MESSAGE_LUA_SEAL_UPGRADE = 137,     --宝印升级的服务器反馈
    CS_MESSAGE_LUA_PET_DEVOUR = 138,       --宠物吞噬
    SC_MESSAGE_LUA_PET_DEVOUR = 139,       --宠物吞噬的服务器反馈
    CS_MESSAGE_LUA_PET_MERGE = 140,        --宠物融合
    SC_MESSAGE_LUA_PET_MERGE = 141,        --宠物融合的服务器反馈
    CS_MESSAGE_LUA_STRENGTHEN_EQUIPMENT = 142,--装备强化
    SC_MESSAGE_LUA_STRENGTHEN_EQUIPMENT = 143,--装备强化的服务器反馈
    CS_MESSAGE_LUA_STAR_EQUIPMENT = 144,    --装备升星
    SC_MESSAGE_LUA_STAR_EQUIPMENT = 145,    --装备升星的服务器反馈
    CS_MESSAGE_LUA_REFINE_EQUIPMENT = 146,  --装备洗练
    SC_MESSAGE_LUA_REFINE_EQUIPMENT = 147,  --装备洗练的服务器反馈
    CS_MESSAGE_LUA_GET_SEAL_INFO = 148,     --获取宝印信息
    SC_MESSAGE_LUA_GET_SEAL_INFO = 149,     --获取宝印信息的服务器反馈
    CS_MESSAGE_LUA_PET_FREE = 150,          --宠物放生
    SC_MESSAGE_LUA_PET_FREE = 151,          --宠物放生的服务器反馈
    CS_MESSAGE_LUA_PET_ON_FIGHT = 152,         --宠物出战
    SC_MESSAGE_LUA_PET_ON_FIGHT = 153,         --宠物出战的服务器反馈
    CS_MESSAGE_LUA_PET_ON_REST = 154,          --宠物休息
    SC_MESSAGE_LUA_PET_ON_REST = 155,          --宠物休息的服务器反馈
    CS_MESSAGE_LUA_GROCERY_BUY = 156,          --杂货铺购买
    SC_MESSAGE_LUA_GROCERY_BUY = 157,          --杂货铺购买的服务器反馈
    CS_MESSAGE_LUA_WANDER_BUY = 158,           --云游商人购买
    SC_MESSAGE_LUA_WANDER_BUY = 159,           --云游商人购买的服务器反馈
    CS_MESSAGE_LUA_WANDER_HOLD = 160,          --云游商人开始购买
    SC_MESSAGE_LUA_WANDER_HOLD = 161,          --云游商人开始购买的服务器反馈
    CS_MESSAGE_LUA_WANDER_FREE = 162,          --云游商人结束购买
    SC_MESSAGE_LUA_WANDER_FREE = 163,          --云游商人结束购买的服务器反馈
    SC_MESSAGE_LUA_WANDER_APPEAR = 164,        --云游商人出现
    SC_MESSAGE_LUA_WANDER_DISAPPEAR = 165,     --云游商人消失
    SS_MESSAGE_LUA_USER_LOGOUT = 166,          --用户注销（服务器自身调用）
    CS_MESSAGE_LUA_FRIEND_GET = 168,           --获得好友列表
    SC_MESSAGE_LUA_FRIEND_GET = 169,           --获得好友列表服务器反馈
    CS_MESSAGE_LUA_FRIEND_SEARCH = 170,        --搜索好友
    SC_MESSAGE_LUA_FRIEND_SEARCH = 171,        --搜索好友服务器反馈
    CS_MESSAGE_LUA_FRIEND_APPLY = 172,         --申请添加好友
    SC_MESSAGE_LUA_FRIEND_APPLY = 173,         --申请添加好友服务器反馈
    CS_MESSAGE_LUA_FRIEND_ACCEPT = 174,        --通过好友申请
    SC_MESSAGE_LUA_FRIEND_ACCEPT = 175,        --通过好友申请服务器反馈
    CS_MESSAGE_LUA_FRIEND_DELETE = 176,        --删除好友
    SC_MESSAGE_LUA_FRIEND_DELETE = 177,        --删除好友服务器反馈
    SC_MESSAGE_LUA_FRIEND_ONLINE = 178,        --服务器推送，好友上下线提示
    CS_MESSAGE_LUA_BLACKLIST_ADD = 179,        --添加黑名单
    SC_MESSAGE_LUA_BLACKLIST_ADD = 180,        --添加黑名单反馈
    CS_MESSAGE_LUA_ENEMY_ADD = 181,            --添加仇人
    SC_MESSAGE_LUA_ENEMY_ADD = 182,            --添加仇人服务器反馈
    CS_MESSAGE_LUA_TILI_BUY = 183,             --体力购买
    SC_MESSAGE_LUA_TILI_BUY = 184,             --体力购买的服务器反馈
    CS_MESSAGE_LUA_CHAPTER_REWARD = 185,       --获取章节奖励
    SC_MESSAGE_LUA_CHAPTER_REWARD = 186,       --获取章节奖励的服务器反馈
    CS_MESSAGE_LUA_DUNGEON_SWEEP = 187,        --扫荡副本
    SC_MESSAGE_LUA_DUNGEON_SWEEP = 188,        --扫荡副本的服务器反馈
    CS_MESSAGE_LUA_BLACKLIST_DELETE = 189,     --删除黑名单
    SC_MESSAGE_LUA_BLACKLIST_DELETE = 190,     --删除黑名单服务器反馈
    CS_MESSAGE_LUA_ENEMY_DELETE = 191,         --删除仇人
    SC_MESSAGE_LUA_ENEMY_DELETE = 192,         --删除仇人服务器反馈
    SC_MESSAGE_LUA_FRIEND_ONLINE = 193,        --好友上下线提示
    CS_MESSAGE_LUA_FRIEND_CHAT = 194,           --好友聊天
    SC_MESSAGE_LUA_FRIEND_CHAT = 195,           --好友聊天服务器反馈
    SC_MESSAGE_LUA_HEGEMON_BROADCAST = 196,     --霸主榜广播
    CS_MESSAGE_LUA_GET_DUNGEON_HEGEMON = 197,   --获取副本霸主榜
    SC_MESSAGE_LUA_GET_DUNGEON_HEGEMON = 198,   --获取副本霸主榜服务器反馈
    CS_MESSAGE_LUA_CHAT = 199,                  --聊天
    SC_MESSAGE_LUA_CHAT = 200,                  --聊天服务器反馈
    SC_MESSAGE_LUA_CHAT_BROADCAST = 201,        --聊天广播
    SC_MESSAGE_LUA_SYSTEM_MESSAGE = 202,        --系统消息
    CS_MESSAGE_LUA_LEVEL_UP = 203,              --手动升级
    SC_MESSAGE_LUA_LEVEL_UP = 204,              --手动升级服务器反馈
    CS_MESSAGE_LUA_SKILL_UPGRADE = 205,              --技能升级
    SC_MESSAGE_LUA_SKILL_UPGRADE = 206,              --技能升级服务器反馈
    CS_MESSAGE_LUA_SKILL_CHANGE = 207,              --技能调整
    SC_MESSAGE_LUA_SKILL_CHANGE = 208,              --技能调整服务器反馈
    CS_MESSAGE_LUA_PLAN_SWITCH = 209,              --预设方案切换
    SC_MESSAGE_LUA_PLAN_SWITCH = 210,              --预设方案服务器反馈
    SC_MESSAGE_LUA_REDS = 211,                     --红点信息
    SC_MESSAGE_LUA_ERROR_INFO = 212,               --服务器错误推送
    CS_MESSAGE_LUA_PLAYER_DIE = 213,               --玩家死亡
    SC_MESSAGE_LUA_PLAYER_DIE = 214,               --玩家死亡服务器反馈
    CS_MESSAGE_LUA_PLAYER_REBIRTH = 215,               --玩家复活
    SC_MESSAGE_LUA_PLAYER_REBIRTH = 216,               --玩家复活服务器反馈
    CS_MESSAGE_LUA_ENTER_SCENE = 217,               --进入场景
    SC_MESSAGE_LUA_ENTER_SCENE = 218,               --进入场景反馈
    CS_MESSAGE_LUA_LOADED_SCENE = 219,               --场景场景加载完成
    SC_MESSAGE_LUA_LOADED_SCENE = 220,               --场景场景加载完成反馈
    CS_MESSAGE_LUA_GEM_OPEN_SLOT = 221,                   --宝石开孔
    SC_MESSAGE_LUA_GEM_OPEN_SLOT = 222,                   --宝石开孔反馈
    CS_MESSAGE_LUA_GEM_INLAY = 223,                   --宝石镶嵌
    SC_MESSAGE_LUA_GEM_INLAY = 224,                   --宝石镶嵌反馈
    CS_MESSAGE_LUA_GEM_REMOVE = 225,                   --宝石摘除
    SC_MESSAGE_LUA_GEM_REMOVE = 226,                   --宝石摘除反馈
    CS_MESSAGE_LUA_GEM_CARVE = 227,                   --宝石加工
    SC_MESSAGE_LUA_GEM_CARVE = 228,                   --宝石加工反馈
    CS_MESSAGE_LUA_GEM_IDENTIFY = 229,                   --宝石鉴定
    SC_MESSAGE_LUA_GEM_IDENTIFY = 230,                   --宝石鉴定反馈
    CS_MESSAGE_LUA_GEM_COMBINE = 231,                   --宝石合成
    SC_MESSAGE_LUA_GEM_COMBINE = 232,                   --宝石合成反馈
    CS_MESSAGE_LUA_PET_SKILL_UPGRADE = 233,             --宠物技能升级
    SC_MESSAGE_LUA_PET_SKILL_UPGRADE = 234,             --宠物技能升级反馈
    CS_MESSAGE_LUA_PET_FIELD_UNLOCK = 235,             --宠物技能栏位解锁
    SC_MESSAGE_LUA_PET_FIELD_UNLOCK = 236,             --宠物技能栏位解锁反馈
    SC_MESSAGE_LUA_SERVER_INFO = 237,                  --服务器通知
    GT_MESSAGE_LUA_GAME_RPC = 240,                      -- game服务器远程调用team服务器函数
    OG_MESSAGE_LUA_GAME_RPC = 241,                      -- 其他服务器远程调用game服务器的avatar函数
    CS_MESSAGE_LUA_GAME_RPC = 242,                      -- 客户端服务器远程调用game服务器的avatar函数
    SC_MESSAGE_LUA_GAME_RPC = 243,                      -- game服务器远程调用客户端函数
    AS_MESSAGE_LUA_ARENA_GAME_RPC = 246,                      -- 竞技场服务器远程调用game服务器的avatar函数
    SA_MESSAGE_LUA_GAME_ARENA_RPC = 247,                      -- game服务器远程调用竞技场函数
    CS_MESSAGE_LUA_ARENA_GET_RANK = 249,                    --获取竞技场排名
    SC_MESSAGE_LUA_ARENA_GET_RANK = 250,                    --获取竞技场排名服务器反馈
    CS_MESSAGE_LUA_ARENA_INFO = 251,                        --获取竞技场信息
    SC_MESSAGE_LUA_ARENA_INFO = 252,                        --获取竞技场信息服务器反馈
    CS_MESSAGE_LUA_ARENA_CHALLENGE = 253,                   --竞技场挑战
    SC_MESSAGE_LUA_ARENA_CHALLENGE = 254,                   --竞技场挑战服务器反馈
    CS_MESSAGE_LUA_ARENA_MATCHING = 255,                    --竞技场混战赛匹配
    SC_MESSAGE_LUA_ARENA_MATCHING = 256,                    --竞技场混战赛匹配服务器反馈
    CS_MESSAGE_LUA_ARENA_BUY_COUNT = 257,                   --竞技场排位赛购买次数
    SC_MESSAGE_LUA_ARENA_BUY_COUNT = 258,                   --竞技场排位赛购买次数服务器反馈
    CS_MESSAGE_LUA_ARENA_COOLING = 259,                     -- 竞技场排位赛冷却
    SC_MESSAGE_LUA_ARENA_COOLING = 260,                     --竞技场排位赛冷却服务器反馈
    CS_MESSAGE_LUA_ARENA_REFRESH = 261,                     --竞技场刷新可挑战玩家
    SC_MESSAGE_LUA_ARENA_REFRESH = 262,                     --竞技场刷新可挑战玩家反馈
    CS_MESSAGE_LUA_ARENA_PET_SETTING = 263,                 --竞技场宠物出场设置
    SC_MESSAGE_LUA_ARENA_PET_SETTING = 264,                 --竞技场宠物出场设置服务器反馈
    SC_MESSAGE_LUA_ARENA_RESULT = 265,                      --竞技场战斗结果推送
    CS_MESSAGE_LUA_QUERY_PLAYER = 266,                      --查询玩家信息
    SC_MESSAGE_LUA_QUERY_PLAYER = 267,                      --查询玩家信息服务器反馈
    GC_MESSAGE_LUA_GAME_RPC = 268,                      -- game服务器远程调用country服务器函数
    CS_MESSAGE_LUA_ARENA_QUALIFYING_FIGHT = 269,            --竞技场排位赛开打
    SC_MESSAGE_LUA_ARENA_QUALIFYING_FIGHT = 270,            --竞技场排位赛开打反馈
    CS_MESSAGE_LUA_ARENA_QUALIFYING_GIFHT_OVER = 271,       --竞技场排位赛战斗结束
    SC_MESSAGE_LUA_ARENA_QUALIFYING_GIFHT_OVER = 272,       --竞技场排位赛战斗结束反馈
    AS_MESSAGE_LUA_ARENA_FIGHT_RESULT = 273,                --竞技场战斗结果
    CS_MESSAGE_LUA_ARENA_QUALIFYING_GIFHT_QUIT = 274,       --竞技场排位赛放弃战斗
    SC_MESSAGE_LUA_ARENA_QUALIFYING_GIFHT_QUIT = 275,       --竞技场排位赛放弃战斗反馈
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_MATCHING_RESULT = 276,    --混战赛匹配结果推送
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_CREATE_SCENE = 277,       --混战赛场景创建推送
    CS_MESSAGE_LUA_ARENA_DOGFIGHT_ENTER_SCENE = 278,        --混战赛进入场景
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_ENTER_SCENE = 279,        --混战赛进入场景反馈
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_FIGHT_START = 280,        --混战赛开打
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_RESULT = 281,             --混战赛结果推送
    CS_MESSAGE_LUA_ARENA_DOGFIGHT_CANCEL_MATCHING = 282,    --混战赛取消匹配
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_CANCEL_MATCHING = 283,    --混战赛取消匹配服务器反馈
    CS_MESSAGE_LUA_ARENA_DOGFIGHT_FIGHT_OVER = 286,         --混战赛结束
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_FIGHT_OVER = 287,         --混战赛结束反馈
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_SCORE_AREA = 288,         --服务端推送竞技场积分点出现
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_OCCUPY_INFO = 289,        --服务器推送竞技场积分点占领者信息
    SC_MESSAGE_LUA_PLAYER_REBIRTH_INFO = 290,               --服务器推送玩家复活信息
    SC_MESSAGE_LUA_PLAYER_REBIRTH_AUTO = 291,               --服务器推送玩家自动复活信息
    CS_MESSAGE_LUA_ARENA_DOGFIGHT_QUIT_FIGHT = 292,         --竞技场混战赛放弃战斗
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_QUIT_FIGHT = 293,         --竞技场混战赛放弃战斗服务器反馈
    SC_MESSAGE_LUA_ARENA_DOGFIGHT_BUFF_LIST = 294,          --竞技场buff列表
    GD_MESSAGE_LUA_GAME_RPC = 295,                          -- game模块远程调用dungeon模块函数
    DC_MESSAGE_LUA_GAME_RPC = 296,                          -- dungeon模块远程调用client函数
    CD_MESSAGE_LUA_GAME_RPC = 297,                          -- client远程调用dungeon模块函数
    GR_MESSAGE_LUA_GAME_RPC = 298,                          -- game模块远程调用ranking模块函数
    OM_MESSAGE_LUA_GAME_RPC = 299,                          --其他模块调用邮件模块
    GS_MESSAGE_LUA_GAME_RPC = 300,                          -- game模块远程调用shop模块
    SG_MESSAGE_LUA_GAME_RPC = 301,                          -- shop模块远程调用game模块
    GF_MESSAGE_LUA_GAME_RPC = 302,                          -- game模块远程调用faction模块
    GG_MESSAGE_LUA_GAME_RPC = 303,                          --game模块远程调用global模块
    SG_MESSAGE_GAME_RPC_TRANSPORT = 304,               --通过global向game转发RPC消息
    SG_MESSAGE_CLIENT_RPC_TRANSPORT = 305,             --通过global向client转发RPC消息
    OG_MESSAGE_LUA_SYNC_SHOP_INFO = 306,                 --同步商店信息
    OG_MESSAGE_LUA_SYNC_SERVER_GLOBAL_DATA = 307,           -- 同步数据库全局数据
    CS_MESSAGE_LUA_PREPARE_CAPTURE_PET = 308,               -- 准备抓宠
    SC_MESSAGE_LUA_PREPARE_CAPTURE_PET = 309,               -- 结束抓宠
    GCA_MESSAGE_LUA_GAME_RPC = 310,                         --game服务器远程调用跨服竞技场匹配服务器
    OG_FORCE_KICK_PLAYER = 311,                             --强制踢玩家下线
    OG_CHANGE_USER_SESSION_ID = 312,                        --切换用户session id
    SL_MESSAGE_LUA_GAME_RPC = 313,                          --game服务器远程调用分线管理服务器
    OG_MODIFY_SERVER_TIME = 314,                            --修改当前时间
    OG_ADD_BUFF_TO_ALL_COUNTRY_PLAYER = 315,                --给阵营玩家加全体buff

    MESSAGE_LUA_END = 999,                 --消息索引结束，无此指令

    --login模块通信协议
    MESSAGE_LOGIN_START = 1000,                      --消息索引开始，无此指令
    CS_MESSAGE_LOGIN_LOGIN = 1001,                   --玩家登陆
    SC_MESSAGE_LOGIN_LOGIN = 1002,                   --玩家登陆的服务器反馈
    CS_MESSAGE_LOGIN_REGIST = 1003,                  --玩家注册
    SC_MESSAGE_LOGIN_REGIST = 1004,                  --玩家注册的服务器反馈
    CS_MESSAGE_LOGIN_CREATE_ACTOR = 1005,            --角色创建
    SC_MESSAGE_LOGIN_CREATE_ACTOR = 1006,            --角色创建的服务器反馈
    CS_MESSAGE_LOGIN_DELETE_ACTOR = 1007,            --删除角色
    SC_MESSAGE_LOGIN_DELETE_ACTOR = 1008,            --删除角色的服务器反馈
    CS_MESSAGE_LOGIN_SELECT_ACTOR = 1009,            --选择角色
    SC_MESSAGE_LOGIN_SELECT_ACTOR = 1010,            --选择角色的服务器反馈
    CS_MESSAGE_LOGIN_CLIENT_RECONNECT = 1011,        --客户端断线重连
    SC_MESSAGE_LOGIN_CLIENT_RECONNECT = 1012,        --客户端断线重连的服务器反馈
    MESSAGE_LOGIN_END = 1999,                      --消息索引结束，无此指令


    --背包
    RESOURCE_ID_TO_NAME =
    {
        [1001] = "coin",    --银币
        [1002] = "ingot",   --元宝
        [1003] = "tili",    --体力
        [1004] = "exp",     --经验值
        [1005] = "pvp_score", --竞技币
        [1006] = "silver",      --银元宝
        [1007] = "dungeon_score", --副本积分
        [1008] = "arena_score", --竞技场积分
        [1009] = "talent_coin", --天赋铜钱
        [1010] = "talent_exp",  --天赋经验
        [1011] = "faction_score",--帮贡
        [1012] = "bind_coin",   --绑定铜钱
        [1013] = "feats",       --功勋
        [1014] = "live_energy", --生活技能精力
        [1015] = "faction_fund",--帮会资金
        [1016] = "vote_num",    --选票
        [1017] = "country_fund", --阵营资金
    },

    RESOURCE_NAME_TO_ID =
    {
        coin = 1001,    --银币
        ingot = 1002,   --元宝
        tili = 1003,    --体力
        exp = 1004,     --经验值
        pvp_score = 1005, --竞技币
        silver = 1006,      --银元宝
        dungeon_score = 1007, --副本积分
        arena_score = 1008, --竞技场积分
        talent_coin = 1009, --天赋铜钱
        talent_exp = 1010,  --天赋经验
        faction_score = 1011,--帮贡
        bind_coin = 1012,   --绑定铜钱
        feats = 1013,       --功勋
        live_energy = 1014, --生活技能精力
        faction_fund = 1015,    --帮会资金
        vote_num = 1016,        --选票
        country_fund = 1017,    --阵营资金
    },

    --物品类型
    TYPE_RESOURCE = 100,    --资源类，不进入背包
    TYPE_CONSUME = 101,     --消耗类材料，被特定系统使用后直接扣除
    TYPE_EXP_PILL = 102,    --经验丹
    TYPE_EQUIP_STRENGTHEN = 103,--装备强化石
    TYPE_EQUIP_STAR_BLESS = 104,--装备升星祝福石
    TYPE_EQUIP_STRENGTHEN_BLESS = 105,--装备强化祝福石
    TYPE_CHAOS_STONE = 107,   --混沌石，可鉴定宝石
    TYPE_RECOVERY_DRUG = 108,   --恢复药品
    TYPE_TASK = 111,            --任务道具
    TYPE_FIX_PACKAGE = 201, --固定物品包
    TYPE_RAND_PACKAGE = 202,--随机物品包
    TYPE_AUTO_PACKAGE = 203,--自动打开包
    TYPE_ADD_BUFF = 204,    --buff药剂
    TYPE_SEAL_ENERGY = 205,  --宝印灵气
    TYPE_FRIEND_VALUE = 206,    --好友度道具

    TYPE_WEAPON = 301,      --武器类
    TYPE_NECKLACE = 302,    --项链类
    TYPE_RING = 303,        --戒指类
    TYPE_HELMET = 304,      --头盔类
    TYPE_ARMOR = 305,       --胸甲类
    TYPE_BELT = 306,        --腰带类
    TYPE_LEGGING = 307,       --裤腿类
    TYPE_BOOT = 308,       --靴子类
    TYPE_PET_EGG = 401,         --宠物蛋
    TYPE_PET_DEVOUR_STUFF = 402,    --宠物吞噬材料
    TYPE_SCALE_MODEL = 501,         --模型缩放
    TYPE_DISGUISE_MODEL = 502,        --改变模型
    TYPE_RANDOM_TRANSPORT_CHARACTER = 503,    --随机传送符
    TYPE_EFFECT_ITEM = 504,         --特效道具
    TYPE_TRANSPORT_BANNER = 505,    --导标旗
    TYPE_NIL_TRANSPORT_BANNER = 506,    --空导标旗
    TYPE_CHANGE_NAME = 507,         --改名道具
    TYPE_STEALTHY_CHARACTER = 508,            --隐身符
    TYPE_CLEAR_PK_VALUE = 509,      --清除pk值
    TYPE_GEM = 601,         --宝石类

    TYPE_HEAD_FASHION = 901,    --头像时装
    TYPE_CLOTH_FASHION = 902,   --衣服时装
    TYPE_WEAPON_FASHION = 903,  --武器时装
    TYPE_ORNAMENT_FASHION = 904,    --配饰时装


    COMMON_HEAD = 1,
    PACKAGE_HEAD = 2,
    EQUIPMENT_HEAD = 3,
    PET_HEAD = 4,

    --错误信息列表
    error_server_error = 1000,               --服务器内部错误
    error_already_in_dungeon = 1001,         --你已经在副本中
    error_dungeon_not_unlock = 1002,         --副本尚未解锁
    error_dungeon_not_match = 1003,          --副本id不匹配
    error_dungeon_result_not_legal = 1004,   --副本结算数据不合法
    error_item_not_enough = 1005,            --道具或资源数目不足
    error_count_can_not_negative = 1006,     --数值不能为负值
    error_no_empty_cell = 1007,              --背包空间不足
    error_item_can_not_sell = 1008,          --物品不可出售
    error_no_item_in_pos = 1009,             --物品格无物品
    error_split_number_out_range = 1010,     --拆分数目太大
    error_position_not_addable = 1011,       --物品格无法添加
    error_item_id_not_match = 1012,          --物品id不匹配，无法加入指定单元格
    error_one_pet_one_time = 1013,           --一个时间只能抓捕一只宠物
    error_pet_capture_energy_require = 1014, --抓宠灵力不足
    error_capture_not_start = 1015,          --抓宠尚未开始
    error_capture_num_out = 1016,            --抓宠次数用尽
    error_capture_time_out = 1017,           --抓宠时间用尽
    error_create_pet_fail = 1018,            --创建宠物失败
    error_pet_overflow = 1019,               --宠物数目太多
    error_item_can_not_equip = 1020,         --物品类型错误，无法装备
    error_equip_type_wrong = 1021,           --错误的装备类型
    error_cell_can_not_unlock = 1022,        --背包格子当前无法解锁
    error_cell_unlock_already = 1023,        --背包格子已经解锁
    error_level_not_enough = 1024,           --未达到使用等级
    error_vocation_not_match = 1025,         --职业不匹配
    error_pet_can_not_devour = 1026,         --不满足吞噬条件
    error_pet_can_not_merge = 1027,          --不满足融合条件
    error_pet_is_on_fight = 1028,            --出战中的宠物不能被吞噬和融合
    error_pet_less_than_two = 1029,          --宠物不足两个时不能吞噬和融合
    error_pet_not_exist = 1030,              --宠物不存在
    error_equip_unload = 1031,               --未装备
    error_item_not_enough = 1032,            --道具不足
    error_equipment_strengthen_max_level = 1033,--已达到最大等级
    error_equip_refine_atribute_not_match = 1034,--装备洗练属性不匹配
    error_equip_refine_atribute_max = 1035,  --装备洗练属性已达最大数量
    error_pet_uid_not_match = 1036,          --宠物uid不匹配
    error_pet_star_too_high = 1037,          --宠物星级过高
    error_pet_score_too_high = 1038,          --宠物分数过高
    error_no_pet_on_fight_place = 1039,       --无宠物出战栏位
    error_pet_not_on_fight = 1040,            --宠物当前未出战
    error_wander_disappear = 1041,            --云游商人已消失
    error_wander_goods_not_exist = 1042,      --云游商人无此商品
    error_wander_goods_not_enough = 1043,     --云游商人商品不足
    error_level_not_match_goods = 1044,       --等级不符合购买要求
    error_buy_not_cold_down = 1045,           --购买cd未到
    error_normal_dungeon_times_use_out = 1046,--每日普通副本次数用完
    error_tili_not_enough = 1047,             --体力不足
    error_dungeon_time_out = 1048,            --副本时间用尽
    error_chapter_reward_already_get = 1049,  --章节奖励重复领取
    error_chapter_reward_not_available = 1050,  --章节奖励条件未达成
    error_dungeon_not_achieve_sss = 1051,        --副本未达到SSS
    error_player_no_online = 1052,              --玩家不在线
    error_friend_in_your_friends = 1053,              --对方在你的好友列表里
    error_friend_in_your_applicants = 1054,              --对方在你的申请列表里
    error_friend_in_your_blacklist = 1055,              --对方在你的黑名单列表里
    error_friend_in_your_enemys = 1056,              --对方在你的仇人列表里
    error_friend_in_their_friends = 1057,           --你在对方的好友列表里
    error_friend_in_their_applicants = 1058,              --你在对方的申请列表里
    error_friend_in_their_blacklist = 1059,              --你在对方的黑名单列表里
    error_friend_in_their_enemys = 1060,              --你在对方的仇人列表里
    error_friend_applicant_is_full = 1061,            --对方申请列表已满
    error_no_player = 1062,                           --没有这个玩家
    error_friend_is_full = 1063,                      --好友列表已满
    error_friend_enemy_is_full = 1064,                --仇人列表已满
    error_friend_blacklist_is_full = 1065,            --黑名单已满
    error_friend_search_length  = 1066,               --搜索必须2个字符以上
    error_friend_not_same_country = 1067,              --不同阵营
    error_no_union = 1068,                              --没有公会
    error_no_team = 1069,                               --没有组队
    error_chat_cd_not_enough = 1070,                    --聊天cd不足
    error_chat_ban = 1071,                              --被禁言了
    error_exp_not_enough = 1072,                        --升级经验不足
    error_level_reach_ceil = 1073,                      --等级达到上限
    error_skill_level_ceil = 1074,                      --技能达到当前等级上限
    error_impossible_param = 1075,                      --参数错误，出现不可能的值
    error_skill_id_not_exsit = 1076,                    --当前不存在此技能
    error_skill_not_unlock = 1077,                      --技能未解锁
    error_level_not_enough = 1078,                      --等级不足
    error_invalid_while_dead = 1079,                    --死亡期间不可执行的动作
    error_rebirth_type_invalid = 1080,                  --复活类型错误
    error_rebirth_time_not_arrival = 1081,              --复活时间未到
    error_player_is_alive = 1082,                       --玩家未死亡
    error_scene_not_exist = 1083,                       --场景不存在
    error_scene_in_same_scene = 1084,                       --在同一场景
    error_equip_gem_slot_opened = 1085,                 --此孔已开
    error_equip_gem_slot_inlay = 1086,                  --此孔已有宝石
    error_equip_gem_slot_remove = 1087,                 --此孔没有宝石
    error_equip_gem_carve_grid = 1088,                       --此宝石格子数为1，已经无法打磨
    error_equip_gem_type_identify = 1089,               --此类型无法鉴定
    error_equip_gem_combine_formula = 1090,             --无法合成
    error_equip_gem_inlay_type = 1091,                  --装备类型与宝石类型不匹配
    error_equip_gem_open_slot_max = 1092,               --已全部开孔
    error_equip_gem_slot_not_opened = 1093,                 --此孔未开
    error_pet_unique_skill_can_not_replace = 1094,       --宠物特有的主动技不可替换
    error_pet_skill_level_max = 1095,                   --宠物已升到最大
    error_pet_field_num_max = 1096,                     --宠物技能栏位已达到最大值
    error_pet_field_not_unlock = 1097,                  --宠物技能栏位未解锁
    error_pet_active_skill_can_not_learn = 1098,        --宠物的主动技能不可学习
    error_pet_skill_already_learn = 1099,               --宠物技能已学习
    error_pet_skill_not_learn = 1100,                   --宠物技能未学习
    error_pet_skill_no_field_to_learn = 1101,           --无空槽位学习新宠物技能
    error_equip_gem_shape_not_match = 1102,             --形状不匹配
    error_equip_gem_same_type_inlay = 1103,             --同一装备同一种类宝石只能镶嵌一个
    error_item_type_wrong = 1104,                       --物品类型错误
    error_equip_gem_slot_wrong = 1105,                  --宝石槽位错误
    error_equip_gem_remove_different = 1106,            --欲移除的槽位不是同一颗宝石
    error_item_slot_not_enough = 1107,                  --背包中此格子道具不足
    error_data = 1108,                                  --数据错误
    error_equip_gem_combine_max_level = 1109,           --宝石已达最大等级
    error_equip_gem_combine_level = 1110,               --不同等级不能合成
    error_team_is_full = 1111,                          --队伍人数已满
    error_cannot_remove_team_captain = 1112,            --无法踢出队长
    error_team_member_not_enough = 1113,                --队伍成员不足
    error_team_not_exist = 1114,                        --队伍已经不存在
    error_is_team_captain_already = 1115,               --已经是队长了
    error_team_member_not_exist = 1116,                 --队伍成员不存在
    error_already_in_team = 1117,                       --已经在此team中
    error_already_in_anothor_team = 1118,               --已经在team中,无法加入其它team
    error_no_permission_to_operate = 1119,              --无权限操作
    error_war_rank_reward_is_getted = 1120,             --战阶奖励已经领取
    error_prestige_is_not_enough = 1121,                --威望值不足
    error_arena_type = 1122,                            --竞技场类别错误
    error_arena_dogfight_date = 1123,                   --混战赛今日未开放
    error_arena_dogfight_time = 1124,                   --未到混战赛开放时间
    error_arena_qualifying_refresh_no_info = 1125,      --排位赛刷新找不到信息
    error_arena_qualifying_refresh_not_find_matching = 1126,    --排位赛刷新找不到匹配文件
    error_arena_challenge_max_count = 1127,             --没有竞技场挑战次数
    error_arena_challenge_max_buy_count = 1128,         --已达到竞技场最大购买次数
    error_arena_challenge_cooling = 1129,               --竞技场挑战还未冷却
    error_arena_challenge_player_challenged = 1130,     --此玩家正在被挑战
    error_arena_challenge_player_upgrade = 1131,        --该玩家正在进行晋级战，无法被挑战。请稍后……
    error_arena_challenge_me_challenged = 1132,         --你正在被其他玩家挑战，无法进行晋级战。请稍后……
    error_arena_challenge_opponent_rank_update = 1133, --对方段位已更改
    error_arena_grade_data = 1134,                      --段位数据错误
    error_arena_grade_max = 1135,                       --已达到最大段位
    error_arena_create_scene = 1136,                    --无法创建竞技场场景
    error_arena_scene = 1137,                           --你在竞技场场景中，无法挑战
    error_arena_can_not_enter_arena_scene = 1138,       --无法进入竞技场场景
    error_is_on_battle_saul = 1139,                     --已经处于战魂状态了
    error_arena_challenge_normal_monster = 1140,        --正常挑战不能挑战怪物
    error_arena_qualifying_cooling = 1141,              --竞技场冷却时间已到
    error_arena_dogfight_matching = 1142,               --你已在匹配中
    error_arena_dogfight_create_scene_fail = 1143,      --混战赛创建场景失败
    error_country_not_exsit = 1144,                     --国家不存在
    error_arena_dogfight_not_matching = 1145,           --你没有在匹配
    error_already_in_auto_apply_team = 1146,            --已经在自动匹配队伍中
    error_not_in_auto_apply_team = 1147,                --没有处于自动匹配队伍中
    error_not_teleportation_type = 1148,                --目标不存在或非传送阵类型
    error_to_far_from_teleportation = 1149,             --距离传送阵太远
    error_bag_is_full = 1150,                               --背包已满
    error_arena_challenge_upgrade_rank = 1151,          --竞技场排位赛晋级赛必须前10才能挑战
    error_already_in_follow_state = 1152,               --已经处于跟随状态
    error_not_in_follow_state = 1153,                   --没有处于跟随状态
    error_team_captain_cannot_operate = 1154,            --队长无法操作
    error_country_different = 1155,                     --出现错误的阵营
    error_pet_capture_not_cool_down = 1156,             --抓宠cd未到
    error_arena_dogfight_ban_time = 1157,               --禁赛时间未到达
    error_arena_dogfight_time = 1158,                   --不在竞技场混战赛开放时间
    error_player_is_not_online = 1159,                  --玩家不在线
    error_self_country_can_not_enter = 1160,            --因为国家限制不可进入场景
    error_self_country_can_not_transport = 1161,        --因为国家限制不可传送场景
    error_team_no_target = 1162,                        --队伍没有目标
    error_team_dungeon_not_exist = 1163,                --指定组队副本不存在
    error_team_member_level_not_match = 1164,           --有队伍成员等级未达到要求
    error_team_member_not_in_same_scene = 1165,         --有队伍成员不在队长场景
    error_team_member_number_not_enough = 1166,         --队伍人数不达标
    error_team_member_tili_not_enough = 1167,           --队伍成员体力不足
    error_is_waiting_team_member_confirm = 1168,        --正在等待队员同意
    error_team_member_refuse_enter_dungeon = 1169,      --有队员拒绝进入副本
    error_team_is_waiting_dungeon_start = 1170,         --正在等待副本开启时候禁止此操作
    error_command_not_cool_down = 1171,                 --指令cd时间未到
    error_team_dungeon_is_not_member = 1172,            --你不是队伍成员
    error_team_member_refuse_set_target = 1173,         --成员拒绝修改队伍目标
    error_team_dungeon_can_not_find_scene = 1174,       --组队副本无法找到场景
    error_can_not_find_scene_born_pos = 1175,           --场景没有出生点
    error_waiting_player_replace_account = 1176,        --正在等待顶号处理
    error_level_not_match_team = 1177,                  --等级不满足队伍要求
    error_interface_is_closed = 1178,                   --该接口已屏蔽
    error_drop_item_is_not_exist = 1179,                --掉落物已不存在
    error_drop_item_in_protect_time = 1180,             --掉落物所有权保护时间中
    error_player_has_left = 1181,                       --玩家已经离开
    error_team_member_already_in_dungeon = 1182,        --有成员已在副本中
    error_drop_item_in_manual_roll = 1183,              --掉落物正在等待手动roll
    error_manual_roll_waiting_member_not_exsit = 1184,  --不存在此手动roll等待者
    error_enter_dungeon_fail = 1185,                    --进入副本失败
    error_set_team_target_fail = 1186,                  --修改队伍目标失败
    error_mail_not_read = 1187,                         --邮件为读
    error_mail_not_exist = 1188,                        --邮件不存在
    error_mail_already_extract_attachment = 1189,           --此邮件已领取附件
    error_mail_have_not_attachment = 1190,              --此邮件没有附件
    error_is_dogfight_matching = 1192,                 --竞技场匹配期间禁止此操作
    error_is_in_arena_scene = 1193,                    --在竞技场中禁止此操作
    error_not_allowed_operate = 1194,                   --当前状态不允许的操作
    error_is_in_team = 1195,                            --组队中禁止此操作
    error_vip_level_is_not_enough = 1196,               --vip等级不足
    error_item_buy_number_not_enough = 1197,            --已达到最大单人购买次数
    error_item_total_buy_number_not_enough = 1198,      --已达到全服最大购买次数
    error_item_is_off_shelves = 1199,                   --商品已下架或活动未开始
    error_not_in_scene = 1200,                          --不在场景中
    error_is_player_die = 1201,                         --玩家已死亡
    error_seal_energy_is_full = 1202,                   --宝印灵气已满
    error_pk_value_is_zero = 1203,                      --pk值为零
    error_random_transport_fail = 1204,                 --随机传送失败
    error_locate_in_dungeon = 1205,                     --副本中无法使用
    error_pet_appearance_condition_not_fulfilled = 1206,--宠物外观条件不满足
    error_change_name_interval_time = 1207,             --修改名字时间不足
    error_pet_level_not_enough  = 1208,                 --宠物等级不足
    error_already_buy_forever = 1209,                   --已经永久购买此物品了
    error_friend_not_friend = 1210,                     --你们不是好友
    error_is_has_team_member = 1211,                    --有队伍成员的时候禁止此操作
    error_faction_not_exist = 1212,                     --帮会不存在
    error_faction_chief_can_not_leave = 1213,           --帮主无法离开帮会
    error_faction_members_is_full = 1214,               --帮会人数已满
    error_applyer_not_in_apply_list = 1215,             --申请人已不在申请列表中
    error_already_in_this_faction = 1216,               --已经在本帮会中
    error_already_in_other_faction = 1217,              --已经在其他帮会中
    error_can_not_find_player_in_invite_list = 1218,    --受邀用户列表中找不到相应用户
    error_can_not_dissolve_while_member_more_than_half = 1219,  --人数过半时候无法解散帮会
    error_apply_number_in_list_is_full = 1220,          --帮会申请列表已满
    error_you_can_not_kick_yourself = 1221,             --无法踢出自己
    error_faction_name_illegal = 1222,                  --帮会名称不规范
    error_can_not_set_self_faction_as_enemy = 1223,     --不能设置本帮为敌对帮会
    error_is_not_fight_member = 1224,                   --非本场战斗成员
    error_too_many_words_num = 1225,                    --字数超过限制
    error_traitor_debuff_time_can_not_join_faction = 1226, --叛徒debuff时间无法加入或创建帮会
    error_already_has_faction = 1227,                   --玩家已有帮会
    error_level_not_match_create_faction = 1228,        --等级不符合创建帮派要求
    error_faction_position_number_full = 1229,          --帮派的该职位人数已满
    error_apply_too_many_in_one_hour = 1230,            --一小时内申请帮派数目过多
    error_already_has_enemy_faction = 1231,             --设置敌帮后七天内无法改动
    error_main_dungeon_can_not_find_scene = 1232,       --主线副本场景不存在
    error_current_hp_is_full = 1233,                    --当前血量已满
    error_current_mp_is_full = 1234,                    --当前内力已满
    error_current_pet_hp_is_full = 1235,                --当前宠物血量已满
    error_actor_is_not_in_scene = 1236,                 --玩家不在场景中
    error_pet_is_not_in_scene = 1236,                 --没有宠物在场景中
    error_recovery_drug_cd = 1237,                      --物品正在cd
    error_gender_not_match = 1238,                      --性别不符合要求
    error_not_unlock_this_fashion_yet = 1239,           --尚未解锁此外观
    error_already_out_of_time = 1240,                   --物品已过期
    error_not_define_dye_moudle = 1241,                 --未保存染色模板
    error_liveness_history_not_enough = 1242,           --历史活跃度不足
    error_liveness_current_not_enough = 1243,           --当前活跃度不足
    error_task_fight_power_not_enough = 1244,           --战斗力不足，无法接取任务
    error_task_distance_not_enough = 1245,              --与目的地距离过远
    error_task_preposition_is_not_complete = 1246,      --前置任务没有完成
    error_task_have_not_task = 1247,                    --当前没有这个任务
    error_task_can_not_submit = 1248,                   --这个任务未完成
    error_task_can_not_give_up = 1249,                  --这个任务不可放弃
    error_task_can_not_find = 1250,                     --没有这个任务
    error_task_level_not_enough = 1251,                --等级不足，无法接取任务
    error_search_not_cool_down = 1252,                  --搜索指令cd未到
    error_task_gather_count_enough = 1253,              --采集任务次数已满
    error_waiting_for_last_command_result = 1254,       --正在等待上一条指令处理结果
    error_qualifying_arena_can_not_find_player = 1255,  --对手不存在
    error_fight_server_create = 1256,                   --创建战斗场景失败
    error_task_already_receive = 1257,                  --你已经接受这个任务
    error_task_no_receive = 1258,                       --你还没有接受这个任务
    error_task_no_doing = 1259,                         --这个任务没有在进行
    error_alread_in_this_hide_name_state = 1260,        --已经处于该匿名状态
    error_can_not_task_dungeon = 1261,                  --无法创建任务副本
    error_task_dungeon_is_not_member = 1262,            --非任务副本成员
    error_cycle_task_count_not_enough = 1263,           --奇门遁甲次数不足
    error_cycle_task_level_not_enough = 1264,           --奇门遁甲等级不足
    error_cycle_task_player_count_not_enough = 1265,    --奇门遁甲人数不足
    error_cycle_task_is_not_captain = 1266,             --奇门遁甲只有队长才能开启任务
    error_cycle_task_is_exist = 1267,                   --你已领取奇门遁甲任务
    error_cycle_task_receive = 1268,                    --奇门遁甲任务接取失败
    error_pet_already_on_fight = 1269,                  --宠物已出战
    error_player_is_offline = 1270,                     --玩家已下线
    error_not_pet_exp_pill = 1271,                      --不是宠物经验丹
    error_pet_level_too_high = 1272,                    --宠物等级过高
    error_dogfight_arena_player_not_enough = 1273,      --竞技场玩家不足
    error_cannot_attack_same_country_new_player = 1274, --不能攻击同阵营低于30级小号
    error_wild_pet_not_exsit = 1275,                    --野生宠物已经不存在
    error_scene_already_create = 1276,              --场景已创建
    error_scene_already_create_in_all_lines = 1277,              --此场景已在所有分线创建
    error_scene_create_time_out = 1278,                 --场景创建超时
    error_server_busy = 1279,                           --服务器繁忙
    error_select_game_line_in_follow = 1280,            --跟随状态下不能主动切换分线
    error_select_game_line_scene_not_start = 1281,      --指定分线场景未开启
    error_select_game_line_scene_is_busy = 1282,        --指定分线场景繁忙
    error_search_include_illegal_char = 1283,           --非法字符
    error_fight_server_not_disconnect = 1284,           --战斗服务器并没有失去连接
    error_select_game_line_follow = 1285,               --跟随状态下不能主动切线
    error_select_game_line_fight = 1286,                --战斗状态下不能主动切分线
    error_country_war_not_start = 1287,                 --阵营大攻防活动未开始
    error_country_war_task_not_done = 1288,             --阵营大攻防任务未完成
    error_task_country_already_receive = 1289,          --你已接取阵营任务
    error_country_task_ban_receive = 1290,          --你当前在放弃任务惩罚时间内，还需要%d秒才能接取任务
    error_cannot_open_during_country_war = 1291,    --攻防战期间无法打开
    error_not_match_election_require = 1292,        --不符合竞选要求
    error_not_in_nomination_time = 1293,            --不在提名时间内
    error_not_in_vote_time = 1294,                  --不在投票时间内
    error_election_office_too_much = 1295,           --竞选职位过多
    error_country_monster_hp_is_full = 1296,        --阵营怪物（boss，箭塔，npc等）血量已满
    error_order_not_match = 1297,                   --序号不匹配
    error_can_not_add_arrow_for_non_tower = 1298,   --不能给非箭塔目标加箭
    error_country_monster_not_exist = 1299,         --阵营怪物（boss，箭塔，npc等）不存在
    error_arrow_number_get_max = 1300,              --箭塔箭数达到上限
    error_not_in_candidate_list = 1301,             --未成为候选人
    error_vote_number_not_enough = 1302,            --选票不足
    error_history_officers_index_error = 1303,      --历史官员索引错误
    error_history_officer_not_exsit = 1304,         --历史官员不存在
    error_history_officer_you_have_liked = 1305,    --已经点过赞了
    error_already_in_higher_discount = 1306,        --已经在更高职位中
    error_discount_times_is_full = 1307,            --打折次数已满
    error_team_member_is_dead = 1308,               --有队伍成员已死亡
    error_already_in_candidate_list = 1309,         --已经参选过了
    error_salary_already_paid = 1310,               --当日俸禄已发放
    error_country_fund_not_enough = 1311,           --阵营资金不足
    error_transport_other_country = 1312,           --无法传送到其他阵营
    error_transport_target_not_exist = 1313,        --传送目标不存在
    error_have_not_faction = 1314,                  --你还没有帮派
    error_faction_scene_not_start = 1315,           --帮派领地未开启
    error_no_salary_of_this_time = 1316,            --当前无俸禄
    error_team_member_not_in_same_game_server = 1317,--有队伍成员不在当前分线
    error_team_member_refuse_enter_dungeon = 1318,  --有队伍成员拒绝进入副本
    error_faction_building_lock = 1319,             --当前帮派建筑未解锁
    error_faction_not_member = 1320,                --你不是本帮成员
    error_faction_fund_invest_count_limit = 1321,   --你已达到帮派资金投资上限
    error_faction_upgrade_authority = 1322,         --你没有权限升级帮派建筑
    error_faction_upgrade_cd = 1323,                --帮派建筑在冷却中
    error_faction_upgrade_total_level = 1324,         --帮派建筑总等级不足，无法升级帮派大厅
    error_faction_upgrade_max_level = 1325,         --已达到帮派建筑最大等级
    error_faction_upgrade_progress_not_enough = 1326,--进度未满，无法升级建筑
    error_not_in_election_time = 1327,              --不在选举时段
    error_call_together_out_of_time = 1328,         --该召集消息已经过期，无法传送
    error_call_together_number_full = 1329,         --该召集消息人数已满，无法传送
    error_skill_already_cooled_down = 1330,         --技能已经冷却完毕
    error_can_not_refresh_this_skill = 1331,        --该技能无法重置
    error_ingot_not_enough = 1332,                  --元宝不足
    need_make_sure_cover_discount = 1333,           --需要确认是否覆盖低等级打折
    error_sect_not_match = 1334,                    --流派不匹配
    error_talent_page_not_unlock = 1335,            --天赋页未解锁
    error_already_has_sect = 1336,                  --已经有流派了
    error_cannot_repond_yourself = 1337,            --不能响应自己的阵营招募
    error_no_talent_of_this_id = 1338,              --天赋id不存在
    error_talent_not_unlock_yet = 1339,             --天赋尚未解锁

    --login错误信息列表
    error_login_server_error = 2000,               --login服务器内部错误
    error_regist_user_exist = 2001,                --注册用户已存在
    error_login_password_error = 2002,             --用户密码错误
    error_actor_num_overflow = 2003,               --角色数目超过最大值
    error_actor_name_overlaps = 2004,              --角色名重复
    error_actor_not_exsit = 2005,                  --角色不存在
    error_actor_id_not_match_name = 2006,          --角色名与id不匹配
    error_actor_name_length = 2007,                 --角色名字长度不合法
    error_faction_name_overlaps = 2008,             --帮派名字重复
    error_regist_code_not_evalid = 2009,            --无效的激活码
    error_regist_code_is_used = 2010,               --激活码已被使用
    error_player_not_regist = 2011,                 --玩家未注册
    error_gift_code_not_in_date = 2012,             --礼包码不在活动期间
    error_gift_code_is_used = 2013,                 --礼包码已被使用
    error_gift_code_not_evalid = 2014,              --无效的礼包码
    error_gift_receive_times_full = 2015,           --礼包码领取次数已满
    error_is_in_fight_server = 2016,                --副本中无法进行此操作
    error_account_is_locked = 2017,                 --账号被锁定
    error_username_or_passwd_cannot_be_nil = 2018,  --用户名或密码不能为空
    error_device_id_changed = 2019,                 --设备id不匹配

    --技能释放错误列表
    error_skill_cast_ok = 0,
    error_skill_owner_dead = 2100,              -- 施法者已经死亡
    error_skill_no_target = 2101,               -- 缺少目标
    error_skill_too_far = 2102,                 -- 距离目标太远
    error_skill_no_skill = 2103,                -- 没有这个技能
    error_skill_in_cd = 2104,                   -- 在冷却中
    error_skill_no_location = 2105,             -- 缺少施法地点
    error_skill_silence = 2106,                 -- 沉默中，无法释放技能
    error_skill_target_dead = 2107,             -- 目标已死亡
    error_skill_lack_mp = 2108,                 -- 缺少魔法
    error_skill_passive_skill = 2109,           -- 被动技能无法释放



    --宠物相关
    PET_CAPTURE_MAX_TIME = 20,                --抓宠最大时间
    PET_CAPTURE_MAX_NUM = 5,                  --抓宠最大次数
    CAPTURE_RESULT_SUCCESS = 0,               --0：成功
    CAPTURE_RESULT_FAIL_CONTINUE = 1,         --1：失败，可以继续
    CAPTURE_RESULT_FAIL_TIMES_EXHAUST = 2,    --2：捕获次数用尽
    CAPTURE_RESULT_FAIL_TIME_OUT = 3,         --3：时间用尽

    PET_SKILL_ACTIVE_TYPE = 1,                --主动技能
    PET_SKILL_PASSIVE_TYPE = 1,               --被动技能

    MAX_PET_SKILL_FIELD = 8,                  --最大宠物技能数目

    MAX_RECORD_NUM_IN_PET_LIST = 50 ,         --宠物排行榜最大记录数目

    PET_PROPERTY_TYPE_TO_NAME = {
    [1] = "physic_attack_quality",
    [2] = "physic_defence_quality",
    [3] = "magic_attack_quality",
    [4] = "magic_defence_quality",
    [5] = "base_physic_attack",
    [6] = "base_physic_defence",
    [7] = "base_magic_attack",
    [8] = "base_magic_defence",
    },

    --装备相关
    equip_type_to_name =
    {
        [301] = "Weapon",
        [302] = "Necklace",
        [303] = "Ring",
        [304] = "Helmet",
        [305] = "Armor",
        [306] = "Belt",
        [307] = "Legging",
        [308] = "Boot",
    },

    equip_name_to_type =
    {
        Weapon =  301,
        Necklace = 302,
        Ring = 303,
        Helmet = 304,
        Armor = 305,
        Belt = 306,
        Legging = 307,
        Boot = 308,
    },

    RARE_GOODS_LEVEL = 4,       --4为紫色品质
    --计时器
    INFINITY_CALL = 4294967295,

    --属性相关
    BASE_PROPERTY_NAME = {"physic_attack","magic_attack","physic_defence","magic_defence","hp_max","hit",
    "crit","miss","resist_crit","block","break_up","puncture","guardian",
    },

    PROPERTY_NAME_TO_INDEX = {
        physic_attack = 1,     --物理攻击
        magic_attack = 2,       --魔法攻击
        physic_defence  = 3,  --物理防御
        magic_defence = 4,     --魔法防御
        hp_max = 5,                          --最大生命
        hit = 6,                        --命中
        crit = 7,                      --暴击
        miss = 8,                      --闪避
        resist_crit = 9,         --抗暴
        block = 10,                    --格挡
        break_up = 11,               --击破
        puncture = 12,              --穿刺
        guardian = 13,              --守护
        move_speed = 14,           --移动速度

        gold_attack =  15,          --金攻击
        wood_attack =  16,          --木攻击
        water_attack = 17,          --水攻击
        fire_attack =  18,          --火攻击
        soil_attack =  19,          --土攻击
        wind_attack =  20,          --风攻击
        light_attack = 21,          --光攻击
        dark_attack = 22,          --暗攻击
        gold_defence = 23,          --金防御
        wood_defence = 24,          --木防御
        water_defence = 25,          --水防御
        fire_defence =  26,          --火防御
        soil_defence =  27,          --土防御
        wind_defence = 28,          --风防御
        light_defence = 29,          --光防御
        dark_defence =  30,          --暗防御

        fly_power = 31,                     --轻功值
        spritual = 32,                      --灵力

        mp_max = 33,                        --内力
        crit_ratio = 34,                    --暴击伤害倍率
        resist_petrified = 35,              --石化抗性
        ignore_resist_petrified = 36,       --忽视石化抗性
        resist_stun = 37,                   --眩晕抗性
        ignore_resist_stun = 38,            --忽视眩晕抗性
        resist_charm = 39,                  --魅惑抗性
        ignore_resist_charm = 40,           --忽视魅惑抗性
        resist_fear = 41,                   --恐惧抗性
        ignore_resist_fear = 42,            --忽视恐惧抗性
        },
    PROPERTY_INDEX_TO_NAME = {
        [1] = "physic_attack",     --物理攻击,
        [2] = "magic_attack",       --魔法攻击
        [3] = "physic_defence",  --物理防御
        [4] = "magic_defence",     --魔法防御
        [5] = "hp_max",                          --最大生命
        [6] = "hit",                        --命中
        [7] = "crit",                      --暴击
        [8] = "miss",                      --闪避
        [9] = "resist_crit",         --抗暴
        [10] = "block",                    --格挡
        [11] = "break_up",               --击破
        [12] = "puncture",              --穿刺
        [13] = "guardian",              --守护
        [14] = "move_speed",           --移动速度

        [15] = "gold_attack",         --金攻击
        [16] = "wood_attack",         --木攻击
        [17] = "water_attack",        --水攻击
        [18] = "fire_attack",         --火攻击
        [19] = "soil_attack",         --土攻击
        [20] = "wind_attack",         --风攻击
        [21] = "light_attack",        --光攻击
        [22] = "dark_attack",        --暗攻击
        [23] = "gold_defence",        --金防御
        [24] = "wood_defence",        --木防御
        [25] = "water_defence",        --水防御
        [26] = "fire_defence",         --火防御
        [27] = "soil_defence",         --土防御
        [28] = "wind_defence",        --风防御
        [29] = "light_defence",        --光防御
        [30] = "dark_defence",         --暗防御

        [31] = "fly_power",             --轻功值
        [32] = "spritual",              --灵力

        [33] = "mp_max",                        --内力
        [34] = "crit_ratio",                    --暴击伤害倍率
        [35] = "resist_petrified",              --石化抗性
        [36] = "ignore_resist_petrified",       --忽视石化抗性
        [37] = "resist_stun",                   --眩晕抗性
        [38] = "ignore_resist_stun",            --忽视眩晕抗性
        [39] = "resist_charm",                  --魅惑抗性
        [40] = "ignore_resist_charm",           --忽视魅惑抗性
        [41] = "resist_fear",                   --恐惧抗性
        [42] = "ignore_resist_fear",            --忽视恐惧抗性
        },
    QUALITY_NAME_TO_INDEX =
    {
        physic_attack_quality = 1,     --物理攻击
        magic_attack_quality = 2,       --魔法攻击
        physic_defence_quality = 3,  --物理防御
        magic_defence_quality = 4,     --魔法防御
        hp_max_quality = 5,                          --最大生命
        hit_quality = 6,                        --命中
        crit_quality = 7,                      --暴击
        miss_quality = 8,                      --闪避
        resist_crit_quality = 9,         --抗暴
        block_quality = 10,                    --格挡
        break_up_quality = 11,               --击破
        puncture_quality = 12,              --穿刺
        guardian_quality = 13,              --守护
    },

    BASE_NAME_TO_INDEX =
    {
        base_physic_attack = 1,     --物理攻击
        base_magic_attack = 2,       --魔法攻击
        base_physic_defence  = 3,  --物理防御
        base_magic_defence = 4,     --魔法防御
        base_hp_max = 5,                          --最大生命
        base_hit = 6,                        --命中
        base_crit = 7,                      --暴击
        base_miss = 8,                      --闪避
        base_resist_crit = 9,         --抗暴
        base_block = 10,                    --格挡
        base_break_up = 11,               --击破
        base_puncture = 12,              --穿刺
        base_guardian = 13,              --守护
    },

    FRIEND_NAME_TO_FLAG =
    {
        friends = 1,                     --好友
        applicants = 2,                  --申请人
        strangers = 3,                   --陌生人
        blacklist = 4,                  --黑名单
        enemys = 5,                      --仇人
    },

    FRIEND_FLAG_TO_NAME =
    {
        [1] = "friends",                     --好友
        [2] = "applicants",                  --申请人
        [3] = "strangers",                   --陌生人
        [4] = "blacklist",                  --黑名单
        [5] = "enemys",                      --仇人
    },

    PLAYER_SEX_NAME_TO_INDEX =
    {
        both = 0,                       --男女通用
        male = 1,                       --男性
        female = 2,                     --女性
    },

    PLAYER_SEX_INDEX_TO_NAME =
    {
        [1] = "male",                       --男性
        [2] = "female",                     --女性
    },

    FRIEND_VALUE_UPDATE_REASON =
    {
        blacklist = 1,                      --加入黑名单
        prop = 2,                           --物品增加
        talk = 3,                           --每天聊天
    },

    CHAT_CHANNEL =
    {
        UnionChannel = 1,                   --公会
        LoudspeakerChannel = 2,             --喇叭
        TeamChannel = 3,                    --队伍
        NearbyChannel = 4,                  --附近
        SystemChannel = 5,                  --系统
        FactionChannel = 6,                 --阵营
    },
    CHAT_MESSAGE_TYPE =
    {
        ServerPublicNotice = 1,             --服务器公告
        FightInformation = 2,               --战斗消息
        NormalSystemMessage = 3,            --普通系统消息
        ImportantSystemMessage = 4,         --重要系统消息
        FactionMessage = 5,                 --阵营消息
        UnionMessage = 6,                   --帮会消息
        TeamMessage = 7,                    --队伍消息
        NearbyMessage = 8,                  --附近消息
        LoudspeakerMessage = 9,             --大喇叭消息
    },
    SYSTEM_MESSAGE_ID =
    {
        --系统消息1001开始
        system_obtain_prop = 1001,           --系统消息获得物品
        system_level_up    = 1002,           --系统消息玩家升级

        --战斗消息2001开始
        battle_obtain_prop = 2001,           --战斗消息获得物品
        battle_defeated = 2002,              --战斗消息被击败了
        battle_get_exp = 2006,               --战斗活动经验
        boss_anger_change = 2007,            --精英boss怒气变化
        player_want_item = 2011,             --玩家需求roll点
        player_giveup_item = 2012,           --玩家放弃roll点
        get_prestige = 2013,                 --获得功勋
        monster_exp_max = 2014,              --达到当日杀怪经验上限
        --混战赛积分
        dogfight_plunder_score = 2008,       --混战赛掠夺积分
        dogfight_plundered_score = 2009,     --混战赛被掠夺积分
        dogfight_score = 2010,               --获得积分

        --大攻防
        country_war_kill_monster = 3001,
        country_war_assist_kill_monster = 3002,
        country_boss_is_low_hp = 3003,
        country_boss_is_dead = 3004,
        enmey_country_boss_be_killed = 3005,
        transport_fleet_is_under_attack = 3006,
        transport_fleet_get_target = 3007,
        prepare_country_war = 3008,

        --帮会
        system_faction_breakup = 4001,            --帮派破产
        system_faction_recovery = 4002,             --帮派恢复

        --官职
        election_nomination_start = 4003,           --选举报名
        election_vote_start = 4004,                 --投票开始
        election_count_end = 4005,                  --选举结束
        country_total_buff = 4006,                  --阵营全体buff
        country_shop_discount = 4007,               --阵营商店打折
        salary_paid = 4008,                         --俸禄已发放
    },

    --商店
    WANDER_LAST_TIME = 7200,         --云游商人持续秒数

    --日常
    REFRESH_HOUR = 5,                 --凌晨5点刷新
    WEEKLY_REFRESH_DAY = 2,            --周一

    --技能
    MAX_SKILL_PLAN = 3,                 --技能组合最大有3套方案

    --复活
    ALLOW_WHILE_DEAD =              --死亡期间运行的动作
    {
        [102] = true,               --login
        [106] = true,               -- 退出副本
        [199] = true,               --聊天
        [166] = true,               --用户注销
        [215] = true,               --复活
        [217] = true,               --进入场景
        [219] = true,               --进入场景
        [271] = true,               --排位赛结束
        [242] = true,               --rpc、复活
        [241] = true,               --rpc
        [286] = true,               --竞技场结束
        [292] = true,               --放弃竞技场
        [134] = true,                  --gm指令
    },
    --场景格子默认直径
    SCENE_RADIUS = 20,
    ENTITY_VIEW_RADIUS = 20,        --默认实体视野距离
    --主城场景
    CITY_SCENE_ID = {1,2},
    --出生场景id
    BORN_SCENE_ID = {3,7},
    --出生点id
    BORN_POSITION_ID = {31020,71020},
    --宝石孔状态
    GEM_SLOT_STATE =
    {
        lock = -1,               --未开孔
        unlock = 0,             --已开孔，但未镶嵌
    },
    --宝石类型
    GEM_BIG_TYPE =
    {
        normal = 1,               --普通
        special = 2,              --特殊
    },
    EQUIPMENT_ATTRIBUTE_VALUE_TYPE =
    {
        percent = 1,              --万分比
        normal = 2,               --值类型
    },
    --组队
    MAX_TEAM_MEMBER_NUM = 4,       --最大组队人数
    --竞技场类别
    ARENA_TYPE =
    {
        qualifying = 1,               --排位赛
        dogfight = 2,                 --混战赛
    },
    --竞技场挑战类别
    ARENA_CHALLENGE_TYPE =
    {
        normal = 1,                 --正常挑战
        upgrade = 2,                --晋级挑战
    },
    --竞技场挑战对手类别
    ARENA_CHALLENGE_OPPONENT_TYPE =
    {
        player = 1,                 --玩家
        monster = 2,                --守门npc(怪物)
    },
    ARENA_QUALIFYING_SCENE_ID = 801,    --竞技场排位赛场景id
    ARENA_DOGFIGHT_SCENE_ID = 802,    --竞技场混战赛场景id
    --复活类型
    REBIRTH_TYPE=
    {
        city_active = 1,                   --回城复活（主动）
        original_place = 2,                --原地复活
        rebirth_place_active = 3,          --复活点复活(主动)
        rebirth_place_passive = 4,         --复活点复活(被动)
        city_passive = 5,                  --回城复活（被动）
    },

    --系统列表
    SYSTEM_NAME_TO_ID=
    {
        arena_qualifying = 1350,            --竞技场排位赛
        arena_dogfight = 1351,              --竞技场混战赛
        country_task = 1552,                --阵营任务
    },

    --阵营

    --PK相关
    PK_TYPE_TO_VALUE_NAME =
    {
        [1] = "pk_value",                   --pk值
        [2] = "karma_value",                --善恶值
    },

    PK_COLOR_INDEX_TO_NAME =                --PK颜色对应索引
    {
        [1] = "green",
        [2] = "yellow",
        [3] = "red",
    },

    PK_COLOR_NAME_SCHEME =
    {
        green = "KillWhite",
        yellow = "KillYellow",
        red = "KillRed",
    },

    -- 为1表示可以手动设置的类型
    PK_MODE_SET =
    {
        country = 1,
        faction = 1,
        karma = 1,
        slaughter = 1,
        peace = 2,
    },

    PK_MODE_INDEX =
    {
        [1] = "country",
        [2] = "faction",
        [3] = "karma",
        [4] = "slaughter",
        [5] = "peace",
    },

    --副本相关
    DUNGEON_START_INDEX =
    {
        [1] = {0, "main_dungeon"},
        [2] = {1000, "team_dungeon"},
    },

    SCENE_TYPE =
    {
        WILD = 1,                       --野外
        CITY = 2,                       --主城
        ARENA = 3,                      --竞技场
        DUNGEON = 4,                    --个人副本
        TEAM_DUNGEON = 5,               --组队副本
        TASK_DUNGEON = 6,               --任务副本
        FACTION = 7,                    --帮派场景
    },

    MONSTER_TYPE =
    {
        NORMAL = 1,
        TRAP = 2,
        ELITE = 3,
        BOSS = 4,
        CAMP_BOSS = 5,
        WILD_ELITE_BOSS = 6,
        WORLD_BOSS = 7,
    },

   CAMP_TYPE = 
    {
        NONE = 0,
        JIULI = 1,
        YANHUANG = 2,
        NEUTRAL = 3,    -- 和0, 1, 2, 3友好
        CAMP = 4,       -- 和1, 2, 3友好 
    },

    SCENE_STATE =
    {
        start = 1,                        --开始
        running = 2,                      --进行中
        done = 3,                         --结束
    },
    MAIL_IDS={
        ARENA_DAY_REWARD = 9005,
        ARENA_WEEK_REWARD = 9006,
        ARENA_RANK_CHANGE = 9007,
        GROUP_BUY_REWARD = 9008,
        OVER_FLOW_ITEMS = 9009,
        BATTLE_RANK_REWARD = 9042,
        BE_ELECTED_OFFICER = 9043,
        TEAM_DUNGEON_SCORE_FIRST = 9101,
        MAIN_DUNGEON_SCORE_FIRST = 9105,
        TEAM_DUNGEON_HEGEMON = 9100,
        MAIN_DUNGEON_HEGEMON = 9104,
        NO_DUNGEON_HEGEMON_PACK = 9110
    },

    --互斥操作
    MUTEX_OPERATE_LIST = {
        default = {"is_in_team", "is_dogfight_matching", "is_in_arena_scene", "is_player_die"},
        map_teleportation = {"is_dogfight_matching", "is_in_arena_scene", "is_player_die"},
        mini_map_teleportation = {"is_dogfight_matching", "is_in_arena_scene", "is_player_die", "is_in_fight_server"},
        main_dungeon_start = {"is_dogfight_matching", "is_in_arena_scene", "is_player_die", "is_has_team_member"},
        call_together = {"is_dogfight_matching", "is_in_arena_scene", "is_player_die", "is_in_fight_server"},
    },

    HERO_OPERATION_STATUS ={
        None = 0,               --无
        Conveying = 1,             --传送施法中
        Locating = 2,              --定位施法中
        Stealthying = 3,            --隐身施法中
    },

    PET_OUTPUT_TYPE = {
        Wild = 1,                   --野外捕捉
        Stuff = 2,                  --作为材料产生万能宠物
        Store = 3,                  --商城
        NormalShop = 4,             --常规商店
    },

    PLAYER_NAME_MIN_LENTH = 1,
    PLAYER_NAME_MAX_LENTH = 7,

    --帮会
    --- 职位说明：帮主 chief; 副帮主 deputy_chief; 护法 dhammapala; 长老 elder;堂主 starflex; 精英 elite; 帮众 crew

    FACTION_POSITION_NAME_TO_INDEX = {
        chief = 10,
        deputy_chief = 20,
        dhammapala = 30,
        elder = 40,
        starflex = 50,
        elite = 60,
        crew = 70,
    },

    FACTION_VALUE_LIST = {
        total_power = true,
        faction_fund = true,
    },

    --战斗服战斗类型
    FIGHT_SERVER_TYPE = {
        MAIN_DUNGEON = 1,       --主线副本
        TEAM_DUNGEON = 2,       --组队副本
        QUALIFYING_ARENA = 3,   --竞技场排位赛
        DOGFIGHT_ARENA = 4,     --竞技场混战赛
        TASK_DUNGEON = 5,       --任务副本
    },

    --恢复药剂类型
    RECOVERY_DRUG_TYPE = {
        actor_hp = 1,            --玩家血
        actor_mp = 2,            --玩家法
        pet_hp = 3,              --宠物血
    },

    SERVICE_TYPE = {
        arena_service = 1,
        country_service = 2,
        faction_service = 3,
        mail_service = 4,
        ranking_service = 5,
        shop_service = 6,
        team_service = 7,
        friend_service = 8,
        cross_server_arena_service = 9,
        line_service = 10,
    },

    -- 外观
    TIME_FOREVER = 4102416000,      --2100年，高于这个秒数视作已永久购买
    APPEARANCE_TYPE_TO_NAME =
    {
        [901] = "head",    --头像时装
        [902] = "cloth",   --衣服时装
        [903] = "weapon",  --武器时装
        [904] = "ornament",--配饰时装
    },

    -- 日常活动
    ACTIVITY_NAME_TO_INDEX = {
        arena_challenge = 1001,
        arena_dogfight = 1002,
        elite_boss = 1003,
        team_dungeon = 1004,
        evil_invade = 1005,
        catch_pet = 1006,
        pvp_fight = 1007,
        experience = 1008,
        cycle_task = 1009,
        country_task = 1010,
    },
    --任务状态
    TASK_STATE = {
        unknown = 0,        --未知
        unacceptable = 1,   --不可接
        acceptable = 2,     --可接受
        doing = 3,          --进行中
        submit = 4,         --可提交
        done = 5,           --已完成
    },
    --任务分类
    TASK_SORT = {
        main = 1,           --主线任务
        branch = 2,         --分支任务
        secret = 3,         --隐藏任务
        vacation = 4,       --师门任务
        faction = 5,        --帮派任务
        daily_cycle = 6,    --奇门遁甲任务
        country = 7,        --阵营任务
    },
    --任务逻辑类型
    TASK_TYPE = {
        collect = 1,        --收集任务
        escort = 2,         --护送任务
        talk = 3,           --定点对话任务
        use_item = 4,       --定点使用道具
        trigger_mechanism = 5,--定点触发机关
        kill_monster = 6,   --杀怪任务
        kill_player = 7,    --击杀玩家
        daily_activity = 8, --日常活动挑战
        main_dungeon = 9,   --主线关卡挑战
        team_dungeon = 10,  --组队副本挑战
        level = 11,         --等级指标
        fight_power = 12,         --战斗力指标
        gather = 13,        --采集
        system_operation = 14,  --系统操作
        task_dungeon = 15,      --任务副本
    },
    --任务触发条件
    TASK_TRIGGER_CONDITION = {
        none = 0,           --无
        level = 1,          --等级
        fight_power = 2,    --战斗力
    },
    --任务系统操作(TASK_TYPE.system_operation)常量定义
    TASK_SYSTEM_OPERATION = {
        capture_pet = 101,              --捕捉宠物
        seal = 102,                     --升级宝印
        equipment_strengthen = 103,     --强化装备
        qinggong = 104,                 --使用轻功
        fashion = 105,                  --穿上时装
        faction = 106,                  --打开帮会界面
        shop = 107,                     --打开商店界面
        gem = 108,                      --打开宝石界面
        dress_equipment = 109,          --穿装备
        upgrade_skill = 110,            --升级技能
        arena_guide = 111,              --竞技场引导
        activity_guide = 112,           --活动引导
        team_guide = 113,               --组队引导
        contry_guide = 114,             --阵营引导
        businessman_guide = 115,        --云游商人引导
        equip_skill = 116,              --装备技能
        hangup_guide = 117,             --挂机引导
    },
    --国家id
    COUNTRY_ID = {
        jiuli = 1,          --九黎
        yanhuang = 2,       --炎黄
    },
    --任务NPC距离
    TASK_NPC_DISTANCE = 10,     --玩家与NPC距离

    SERVER_TYPE =
    {
        SERVER_TYPE_NONE = 0,						 -- 未定义
        SERVER_TYPE_GATE = 1,
        SERVER_TYPE_FIGHT = 2,
        SERVER_TYPE_GAME = 3,					     -- 游戏服务器
        SERVER_TYPE_DB = 4,
        SERVER_TYPE_GAMEMANAGER = 5,
    },
    DUNGEON_TYPE = {
        kill_target = 1,                --杀死目标
        peotect = 2,                    --保卫
        escort = 3,                     --护送
        sneakon = 4,                    --潜入
        fenxian = 5,                    --分线对推
        in_limited_time = 6,            --限时击杀
    },

    LINE_SCENE_TYPE = {
        start = 1,                      --开启即创建场景
        allow = 2,                     --允许创建场景
        ban = 3,                        --禁止创建场景
        faction = 4,                    --可以创建帮派场景
    },

    --大攻防
    BATTLE_SCENE_LIST = {3,4,5,6,7 },   --参与大攻防的场景id
    SHARE_HP_CONTRY_MONSTER = {         --是否是分线共血的阵营怪物
        [25] = true,
        [26] = true,
        [27] = true,
        [28] = true,
    },

    ASSIST_IN_COUNT_SEC = 60,
    FLEET_TYPE_NAME_TO_INDEX = {
        VAN = 1,
        GUARD = 2,
    },
    CLOSE_SESSION_DELAY_TIME = 900000,
    --大攻防任务状态
    COUNTRY_WAR_TASK_STATUS = {
        doing = 1,                      --进行中
        done = 2,                       --已完成，但未领奖
        reward = 3,                     --已领奖
    },
    --大攻防任务类别
    COUNTRY_WAR_TASK_LOGIC_ID = {
        win = 1,
        attack_monster = 2,
        country_score = 3,
        player_score = 4,
        attack_transport_fleet = 5,
        submit_arrow = 6,
        recovery_blood = 7,
    },
    --阵营NPC任务类型
    COUNTRY_NPC_TASK_TYPE = {
        recovery_blood = 1,         --恢复血量
        submit_arrow = 2,           --提交弓箭
    },
    --帮会领地场景ID
    FACTION_SCENE_ID = 1001,
    --分线操作
    LINE_OPERATION = {
        auto = 1,                   --自动切换分线
        manual = 2,                 --手动切换分线
        faction = 3,                --进入帮派场景
        convene_same_scene = 4,     --召集同场景
        convene_diffrent_scene = 5, --召集，不同场景
    },
    --帮会建筑类别,类别对应建筑基础表
    FACTION_BUILDING_TYPE = {
        HALL = 1,                     --大厅
        TREASARY = 2,                   --金库
        ALTAR = 3,                      --祭坛
    },
    --帮派建筑投资类别
    FACTION_BUILDING_INVESTMENT_TYPE = {
        coin = 1,                   --铜钱
        fund = 2,                   --帮派资金
    },

    -- 官职技能
    OFFICE_SKILL_NAME_TO_ID = {
        call_together = 1,              --阵营召集
        country_task = 2,               --阵营任务
        building_function = 3,          --开启阵营建筑状态
        boss_buff = 4,                  --开启阵营boss状态
        total_skill = 5,                --全体buff
        halo_skill = 6,                 --光环buff
        deploy_forces = 7,              --阵营调兵
        shop_discount = 8,              --商店打折
        open_portal = 9,                --开启传送门
        pay_salary = 10,                --发放薪水
    },

    -- 天赋类型
    TALENT_TYPE = {
        attrib_modify = 1,
    }
}