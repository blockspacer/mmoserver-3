--
-- Created by IntelliJ IDEA.
-- User: Administrator
-- Date: 2017/1/19 0019
-- Time: 15:37
-- To change this template use File | Settings | File Templates.
--

local objectid = objectid

local params = {
    mail_id = {db=true,sync=true,default=objectid()},
    system_mail_id = {db=true,sync=true,default=1},
    attachment= {db=true,sync=true,default={}},
    read = {db=true,sync=true,default=false},
    extract = {db=true,sync=true,default=false},
    send_time = {db=true,sync=true,default=_get_now_time_second() },
    params = {db=true,sync=true,default={}}
}

local mail_info = {}
mail_info.__index = mail_info

setmetatable(mail_info, {
    __call = function (cls, ...)
        local self = setmetatable({}, cls)
        self:__ctor(...)
        return self
    end,
})
mail_info.__params = params

function mail_info.__ctor(self)

end

--根据dict初始化
function mail_info.init_from_dict(self, dict)
    for i, v in pairs(params) do
        if dict[i] ~= nil then
            self[i] = dict[i]
        elseif v.default ~= nil then
            self[i] = v.default
        else
            self[i] = 0
        end
    end
end

function mail_info.write_to_dict(self, dict)
    for i, v in pairs(params) do
        if v.db then
            dict[i] = self[i]
        end
    end
end

function mail_info.write_to_sync_dict(self, dict)
    for i, v in pairs(params) do
        if v.sync then
            dict[i] = self[i]
        end
    end
end

function mail_info.get_mail_id(self)
    return self.mail_id
end

function mail_info.set_read(self)
    self.read = true
end

function mail_info.is_read(self)
    return self.read
end

function mail_info.set_extract(self)
    self.extract = true
end

function mail_info.is_extract(self)
    return self.extract
end

function mail_info.get_attachment_count(self)
    if table.isEmptyOrNil(self.attachment) then
        return 0
    end
    return #self.attachment
end

function mail_info.get_attachment(self)
    return self.attachment
end

return mail_info

