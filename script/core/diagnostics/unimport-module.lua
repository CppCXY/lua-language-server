local files       = require 'files'
local vm          = require 'vm'
local lang        = require 'language'
local config      = require 'config'
local guide       = require 'parser.guide'
local noder       = require 'core.noder'
local collector   = require 'core.collector'
local await       = require 'await'
local furi        = require 'file-uri'

local requireLike = {
    ['include']  = true,
    ['import']   = true,
    ['require']  = true,
    ['load']     = true,
}

---@async
return function(uri, callback)
    local ast = files.getState(uri)
    if not ast then
        return
    end

    local moduleNames = {}

    for uri in files.eachFile() do
        if uri == guide.getUri(ast) then
            goto CONTINUE
        end
        local path = furi.decode(uri)
        local fileName = path:match '[^/\\]*$'
        local stemName = fileName:gsub('%..+', '')
        local moduleName = stemName:gsub("%-", '_')
        if moduleNames[moduleName] == nil then
            local waitImportModule = {}
            table.insert(waitImportModule, {
                path = path
            })
        end
        -- if not locals[stemName]
        --     and not vm.hasGlobalSets(stemName)
        --     and not config.get 'Lua.diagnostics.globals'[stemName]
        --     and stemName:match '^[%a_][%w_]*$'
        --     and matchKey(word, stemName) then
        --     local targetState = files.getState(uri)
        --     if not targetState then
        --         goto CONTINUE
        --     end
        --     local targetReturns = targetState.ast.returns
        --     if not targetReturns then
        --         goto CONTINUE
        --     end
        --     local targetSource = targetReturns[1] and targetReturns[1][1]
        --     if not targetSource then
        --         goto CONTINUE
        --     end
        --     if targetSource.type ~= 'getlocal'
        --         and targetSource.type ~= 'table'
        --         and targetSource.type ~= 'function' then
        --         goto CONTINUE
        --     end
        --     if targetSource.type == 'getlocal'
        --         and vm.isDeprecated(targetSource.node) then
        --         goto CONTINUE
        --     end
        --     results[#results + 1] = {
        --         label            = stemName,
        --         kind             = define.CompletionItemKind.Variable,
        --         commitCharacters = { '.' },
        --         command          = {
        --             title     = 'autoRequire',
        --             command   = 'lua.autoRequire:' .. sp:get_id(),
        --             arguments = {
        --                 {
        --                     uri    = guide.getUri(state.ast),
        --                     target = uri,
        --                     name   = stemName,
        --                 },
        --             },
        --         },
        --         id               = stack(function() ---@async
        --             local md = markdown()
        --             md:add('md', lang.script('COMPLETION_IMPORT_FROM', ('[%s](%s)'):format(
        --                 workspace.getRelativePath(uri),
        --                 uri
        --             )))
        --             md:add('md', buildDesc(targetSource))
        --             return {
        --                 detail      = buildDetail(targetSource),
        --                 description = md,
        --                 --additionalTextEdits = buildInsertRequire(state, originUri, stemName),
        --             }
        --         end)
        --     }
        -- end
        ::CONTINUE::
    end

    -- 遍历全局变量，检查所有没有 set 模式的全局变量
    guide.eachSourceType(ast.ast, 'getglobal', function(src) ---@async
        local key = src[1]
        if not key then
            return
        end
        if config.get 'Lua.diagnostics.globals'[key] then
            return
        end
        if config.get 'Lua.runtime.special'[key] then
            return
        end
        local node = src.node
        if node.tag ~= '_ENV' then
            return
        end
        await.delay()
        local id = 'def:' .. noder.getID(src)
        if not collector.has(id) then
            local message = lang.script('DIAG_UNDEF_GLOBAL', key)
            if requireLike[key:lower()] then
                message = ('%s(%s)'):format(message, lang.script('DIAG_REQUIRE_LIKE', key))
            end
            callback {
                start   = src.start,
            finish  = src.finish,
                message = message,
            }
            return
        end
    end)
end
