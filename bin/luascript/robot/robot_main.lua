--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/5/18 0018
-- Time: 15:10
-- To change this template use File | Settings | File Templates.
--
-- 添加好require路径管理

package.path = package.path .. ";./luascript/?.lua;"
package.cpath = package.cpath .. ";./luascript/?.dll;./luascript/?.so"

math.randomseed(os.clock())

-- Common
require "tolua"

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
require "robot/robot_event"



