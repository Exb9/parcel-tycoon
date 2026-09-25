--!strict
-- Updates the element tree in docs/UI_CONTRACT.md from src/shared/UiContract.luau.
-- Run from the repo root after changing the UI contract: lune run tools/ui-contract-doc

local fs = require("@lune/fs")

local UiContractDoc = require("./lib/UiContractDoc")

local document = fs.readFile(UiContractDoc.DOC_PATH)
local result = UiContractDoc.updated(document)
if result ~= document then
	fs.writeFile(UiContractDoc.DOC_PATH, result)
	print(`updated {UiContractDoc.DOC_PATH}`)
else
	print(`{UiContractDoc.DOC_PATH} is up to date`)
end
