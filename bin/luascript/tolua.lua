---------------------------------------------------
-- auth： wupeifeng
-- date： 2016/11/28
-- desc： 将一些tolua搬到 服务器
---------------------------------------------------

Mathf = {}
UnityEngine = {}

Mathf		= require "UnityEngine.Mathf"
Vector3 	= require "UnityEngine.Vector3"
Quaternion	= require "UnityEngine.Quaternion"
Vector2		= require "UnityEngine.Vector2"
Vector4		= require "UnityEngine.Vector4"

function GetConfig(name)
	return require ("data/" .. name)
end
