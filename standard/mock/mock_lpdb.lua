---
-- @Liquipedia
-- wiki=commons
-- page=Module:Mock/Lpdb
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Array = require('Module:Array')
local Lua = require('Module:Lua')
local String = require('Module:StringUtils')
local Table = require('Module:Table')

-- Parses a single condition into it's three components,
-- Eg. `[[field::!value]]` is parsed into `field`, `!`, `value`
local CONDITION_REGEX = '%[%[(%a+)::([!><]?)([%a%s%d]+)]]'

local mockLpdb = {}

local DEFAULTS = {
	limit = 20,
	offset = 0,
}

local _lpdb = {
	lpdb = mw.ext.LiquipediaDB.lpdb
}

function mockLpdb.setUp()
	mw.ext.LiquipediaDB.lpdb = mockLpdb.lpdb
end

function mockLpdb.tearDown()
	mw.ext.LiquipediaDB.lpdb = _lpdb.lpdb
end

--- Not yet supported in Mock is:
---- conditions with `OR` or `_`
---- query with `::`
---- order
---- groupby
---@param dbTable string
---@param parameters table
---@return table
function mockLpdb.lpdb(dbTable, parameters)
	local lpdbData = mockLpdb._getMockData(dbTable)

	lpdbData = mockLpdb._applyConditions(lpdbData, parameters.conditions)

	lpdbData = mockLpdb._applyLimitOffset(lpdbData, parameters.limit, parameters.offset)

	lpdbData = mockLpdb._applyQuery(lpdbData, parameters.query)

	return lpdbData
end

---Fetches mock lpdb data from store
---@param dbTable string
---@return table
function mockLpdb._getMockData(dbTable)
	local data = Lua.import('Module:TestAssets/Lpdb/' .. dbTable, {requireDevIfEnabled = true})

	if not data then
		error(mw.message.new('liquipediadb-error-invalid-datatype'))
	end

	return data
end

---Filters the mock data based on an lpdb conditions string.
---@param data table
---@param conditions string?
---@return table
function mockLpdb._applyConditions(data, conditions)
	if String.isNotEmpty(conditions) then
		---@cast conditions -nil ---Since the engine cannot determine that isNotEmpty checks for nil, we remove the nil
		local condition = mockLpdb._parseConditions(conditions)
		return Array.filter(data, condition)
	end

	return data
end

---Applies limit and offset to mock data
---@param data table
---@param inputLimit number?
---@param inputOffset number?
---@return table
function mockLpdb._applyLimitOffset(data, inputLimit, inputOffset)
	local limit = tonumber(inputLimit) or DEFAULTS.limit
	local offset = tonumber(inputOffset) or DEFAULTS.offset

	return Array.sub(data, offset + 1, (offset + limit))
end

---Applies the field selectors (query) to the mock data
---@param data table
---@param query string?
---@return table
function mockLpdb._applyQuery(data, query)
	if String.isNotEmpty(query) then
		local fields = Table.mapValues(mw.text.split(query, ','), mw.text.trim)

		return Array.map(data, function(entry)
			return Table.map(entry, function(field, value)
				-- Use map as a filter since there's no applicable filter function in either Array or Table yet
				return field, Table.includes(fields, field) and value or nil
			end)
		end)
	end

	return data
end

---Parse a condition string into a function
---@param conditions string
---@return function
function mockLpdb._parseConditions(conditions)
	---@type {comparator:string, name:string, value:string}[]
	local criterias = {}

	for name, comparator, value in string.gmatch(conditions, CONDITION_REGEX) do
		table.insert(criterias, {name = name, comparator = comparator, value = value})
	end

	return function (entry)
		return Array.all(criterias, function (criteria)
			if criteria.comparator == '' then
				return entry[criteria.name] == criteria.value
			elseif criteria.comparator == '!' then
				return entry[criteria.name] ~= criteria.value
			elseif criteria.comparator == '>' then
				return entry[criteria.name] > criteria.value
			elseif criteria.comparator == '<' then
				return entry[criteria.name] < criteria.value
			else
				error('Unknown comparator: '.. tostring(criteria.comparator))
			end
		end)
	end
end

return mockLpdb