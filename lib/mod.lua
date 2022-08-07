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
    -- May need to handle things like the boolean threshold differently for bipolar:
    -- true may be > 0 instead of >0.5
    return {
        max = {
          order = 1,
          f = math.max
        },
        min = {
          order = 2,
          f = math.min
        },
        sum = {
          order = 3,
          f = function(a,b) return a + b end
        },
        diff = {
          order = 4,
          f = function(a,b) return a - b end
        },
        avg = {
          order = 5,
          f = function(a,b) return (a + b)/2 end
        },
        ["|a-b|"] = {
          order = 6,
          f = function(a,b) return math.abs(a - b) end
        },
        ["a^b"] = {
          order = 7,
          f = function(a,b) return math.pow(a,b) end
        },
        qntz = {
          order = 8,
          f = function(a,b) return (a>0) and math.floor(b/a)*a or 0 end -- quantize b to a
        },
        mod = {
          order = 9,
          f = function(a,b) return (b > 0) and ((100*a) % (100*b))/100 or 0 end
        },
        wrap = {
          order = 10,
          f = function(a,b) return (b > 0) and (((a*100) % (b*100)) / (b*100)) or 0 end, -- modulo normalized to 1
        },
        ["a/2+b"] = {
          order = 11,
          f = function(a,b) return a/2 + b end
        },
        ["a/4+b/2"] = {
          order = 12,
          f = function(a,b) return a/4 + b/2 end
        },
        ["(a+2b)/3"] = {
          order = 13,
          f = function(a,b) return (a+2*b)/3 end
        },
        ["a*b"] = {
          order = 14,
          f = function(a,b) return a * b end
        },
        ["1-a*b"] = {
          order = 15,
          f = function(a,b) return 1 - a * b end
        },
        ["a*10^b"] = {
          order = 16,
          f = function(a,b) return a * (math.pow(10,2*b) / 100) end, -- same as k2000
        },
        -- TODO confirm lopass and hipass
        lopass = {
            order = 17,
            f = function(a,b) 
              if y == nil then y = 0 end
              local out = (b + y*a)/(1+a)
              y = out
              return out
          end
        },
        ["b/1-a"] = {
          order = 18,
          f = function(a,b) return b / (1-a) end
        },
        -- TODO implement a(b-y) with 20ms update of y
        ["(a+b)/2"] = {
          order = 19,
          f = function(a,b) return (a+b)/2 end
        },
        -- TODO sin(a+b),cos, and tri
        -- TODO warp equations
        ["and"] = {
          order = 20,
          f = function(a,b) if (a > 0.5 and b > 0.5) then return 1 else return 0 end end
        },
        ["or"] = {
          order = 21,
          f = function(a,b) if (a > 0.5 or b > 0.5) then return 1 else return 0 end end
        },
        -- TODO ramp lfos
        -- TODO chaotic lfos (will need to move this into the make_fun so we can have a locally scoped y)
        ["a(y + b)"] = {
          order = 22,
          f = function(a,b) 
            y = a * ((y or 0) + b)
            return y
          end
        },
        ["ay + b"] = {
          order = 22,
          f = function(a,b) 
            y = a * (y or 0) + b
            return y
          end
        },
        ["(a + 1)y + b"] = {
          order = 22,
          f = function(a,b) 
            y = (a + 1) * (y or 0) + b
            return y
          end
        },
        ["y +a(y + b)"] = {
          order = 22,
          f = function(a,b) 
            y = y or 0
            y = y + a * (y + b)
            return y
          end
        },
        ["a |y| + b"] = {
          order = 22,
          f = function(a,b) 
            y = a * math.abs(y or 0) + b
            return y
          end
        },
        -- TODO add hysterisis? (or add S&H w/ hysterisis)
        ["S&H"] = {
          order = 22,
          f = function(a,b) 
            if y == nil then y = b end
            if x == nil then x = 0 end
            -- TODO add hysterisis
            if x < 0.5 and a > 0.5 then 
                y = b 
            end
            x = a
            return y
          end
        },
        -- This might be best implemented through diode functions
        -- Not an original K2000 fun
        ["T&H"] = {
          order = 23,
          f = function(a,b) 
            if y == nil then y = b end
            -- TODO add hysterisis
            if a > 0.5 then 
                y = b 
            end
            return y
          end
        },
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
    table.sort(FUN_OP_KEYS, function(a,b) return FUN_OPS[a]["order"] < FUN_OPS[b]["order"] end)
    local FUN_OP = FUN_OPS["max"]["f"]
    matrix:add_unipolar("fun_"..i, "fun "..i)
    params:add_group("function " .. i, 4)
    params:add_option(n(i, "fun_op"), "operator", FUN_OP_KEYS, 1)
    params:set_action(n(i, "fun_op"), function (op_key_idx)
      FUN_OP = FUN_OPS[FUN_OP_KEYS[op_key_idx]].f
    end)
    matrix:defer_bang(n(i,"fun_op"))
    params:add_binary(n(i, "fun_bipolar"), "bipolar", "toggle", 0)
    params:set_action(n(i, "fun_bipolar"), function (bipolar)
        if bipolar > 0 then
            matrix:lookup_source("fun_"..i).t = matrix.tBIPOLAR
        else
            matrix:lookup_source("fun_"..i).t = matrix.tUNIPOLAR
        end
    end)
    params:add_control(n(i, "fun_value_a"), "value a", controlspec.UNIPOLAR)
    params:add_control(n(i, "fun_value_b"), "value b", controlspec.UNIPOLAR)
    local value_a = 0
    local value_b = 0
    local update_value = function()
        if not matrix:used("fun_" .. i) then
            return
        end
        local value = FUN_OP(value_a,value_b)
        local bipolar = params:get(n(i, "fun_bipolar"))
        if bipolar > 0 then value = 2 * value - 0.5 end
        if funkit_debug then
          print("in: "..value_a.." out: "..value)
        end
        matrix:set("fun_"..i, value)
    end
    params:set_action(n(i, "fun_value_a"), function(a)
        value_a = a
        update_value()
    end)
    params:set_action(n(i, "fun_value_b"), function(b)
        value_b = b
        update_value()
    end)
    matrix:defer_bang(n(i,"fun_value_a"))
    matrix:defer_bang(n(i,"fun_value_b"))
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