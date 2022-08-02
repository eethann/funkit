local mod = require 'core/mods'
local matrix = require('matrix/lib/matrix')
local toolkit = require('toolkit/lib/mod')

local funkit = {}
local N_FUNS = 4

local n = function(i, s)
    return "fk_" .. i .. "_" ..s
end

local make_fun_ops = function()
    local x,y -- to be used in functions that have feedback or memory

    -- TODO determine if we want to operate on bipolar values instead of unipolar
    -- The Kurzweil functions operate on bipolar, so that would be truer to the original.
    -- Actually, let's just convert to bipolar and then have an option to convert back.
    return {
        max = math.max,
        min = math.min,
        sum = function(a,b) return a + b end,
        diff = function(a,b) return a - b end,
        avg = function(a,b) return (a + b)/2 end,
        ["|a-b|"] = function(a,b) return math.abs(a - b) end,
        ["a^b"] = function(a,b) return math.pow(a,b) end,
        qntz = function(a,b) return math.floor(b/a)*a end, -- quantize b to a
        mod = function(a,b) return (b > 0) and (a % b) or 0 end,
        wrap = function(a,b) return (b > 0) and ((a % b) / b) or 0 end, -- modulo normalized to 1
        ["a/2+b"] = function(a,b) return a/2 + b end,
        ["a/4+b/2"] = function(a,b) return a/4 + b/2 end,
        ["(a+2b)/3"] = function(a,b) return (a+2*b)/3 end,
        ["a*b"] = function(a,b) return a * b end,
        ["1-a*b"] = function(a,b) return 1 - a * b end,
        ["a*10^b"] = function(a,b) return a * (math.pow(10,2*b) / 100) end, -- same as k2000
        -- TODO confirm lopass and hipass
        lopass = function(a,b) 
            if y == nil then y = 0 end
            local out = (b + y*a)/(1+a)
            y = out
            return out
        end,
        ["b/1-a"] = function(a,b) return b / (1-a) end,
        -- TODO implement a(b-y) with 20ms update of y
        ["(a+b)/2"] = function(a,b) return (a+b)/2 end,
        -- TODO sin(a+b),cos, and tri
        -- TODO warp equations
        ["and"] = function(a,b) if (a > 0.5 and b > 0.5) then return 1 else return 0 end end,
        ["or"] = function(a,b) if (a > 0.5 or b > 0.5) then return 1 else return 0 end end,
        -- TODO ramp lfos
        -- TODO chaotic lfos (will need to move this into the make_fun so we can have a locally scoped y)
        -- TODO add hysterisis? (or add S&H w/ hysterisis)
        ["S&H"] = function(a,b) 
            if y == nil then y = b end
            if x == nil then x = 0 end
            -- TODO add hysterisis
            if x < 0.5 and a > 0.5 then 
                y = b 
            end
            x = a
            return y
        end,
        -- This might be best implemented through diode functions
        -- Not an original K2000 fun
        ["T&H"] = function(a,b) 
            if y == nil then y = b end
            -- TODO add hysterisis
            if a > 0.5 then 
                y = b 
            end
            return y
        end,
        -- TODO diode 
    }
end

local make_fun = function(i, targets)
    local target = nil
    local FUN_OPS = make_fun_ops()
    local FUN_OP_KEYS = {}
    for k,v in pairs(FUN_OPS) do
        table.insert(FUN_OP_KEYS, k)
    end
    matrix:add_unipolar("fun_"..i, "fun "..i)
    params:add_group("function " .. i, 4)
    params:add_option(n(i, "fun_op"), "operator", FUN_OP_KEYS, 1)
    params:add_binary(n(i, "fun_bipolar"), "bipolar", "toggle", 0)
    params:set_action(n(i, "fun_bipolar"), function (bipolar)
        if bipolar > 0 then
            matrix:lookup_source("fun_"..i).t = matrix.tBIPOLAR
        else
            matrix:lookup_source("fun_"..i).t = matrix.tUNIPOLAR
        end
    end)
    params:add_number(n(i, "fun_value_a"), "value a", 0, 1, 0)
    params:add_number(n(i, "fun_value_b"), "value b", 0, 1, 0)
    -- params:hide(n(i,"fun_value_a"))
    -- params:hide(n(i,"fun_value_b"))
    local value_a
    local value_b
    params:set_action(n(i, "fun_value_a"), function(a)
        value_a = a
    end)
    params:set_action(n(i, "fun_value_b"), function(b)
        value_b = b
    end)
    matrix:defer_bang(n(i,"fun_value_a"))
    matrix:defer_bang(n(i,"fun_value_b"))
    local tick = function()
        if not matrix:used("fun_" .. i) then
            return
        end
        local fun = FUN_OPS[params:string(n(i, "fun_op"))]
        local value = fun(value_a,value_b)
        local bipolar = params:get(n(i, "fun_bipolar"))
        matrix:set("fun_"..i, (bipolar + 1) * (value - 0.5 * bipolar))
    end
    -- TODO refactor to a single toolkit runner with priorities on different scheduled funcs
    funkit.funs[i] = toolkit.lattice:new_pattern{
        enabled = true,
        division = 1/96,
        action = tick,
    }
end

local pre_init = function()
    print("funkit pre-init")
    funkit.funs = {}
    matrix:add_post_init_hook(function() 
        -- TODO does this need to be before the latice start to be in sync?
        for i=1,N_FUNS,1 do
            make_fun(i, numbers)
        end
    end, -10)
end

mod.hook.register("script_pre_init", "funkit pre init", pre_init)

return funkit