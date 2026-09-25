--!strict
-- Renders the element tree of src/shared/UiContract.luau for docs/UI_CONTRACT.md (between the
-- "ui-elements" markers). Used by tools/ui-contract-doc.luau and tests/contract.spec.luau.

local UiContract = require("../../src/shared/UiContract")

local UiContractDoc = {}

UiContractDoc.DOC_PATH = "docs/UI_CONTRACT.md"
local START = "<!-- ui-elements:start -->"
local STOP = "<!-- ui-elements:end -->"

type Node = { name: string, kind: string?, optional: boolean?, children: { Node }, byName: { [string]: Node } }

local function newNode(name: string): Node
	return { name = name, children = {}, byName = {} }
end

-- The element tree as an indented code block.
function UiContractDoc.render(): string
	local root = newNode("")
	for _, element in UiContract.elements do
		local node = root
		for _, name in string.split(element.path, "/") do
			local child = node.byName[name]
			if child == nil then
				child = newNode(name)
				node.byName[name] = child
				table.insert(node.children, child)
			end
			node = child
		end
		node.kind = element.kind
		node.optional = element.optional
	end
	local lines = {}
	local function walk(node: Node, depth: number)
		for _, child in node.children do
			local label = string.rep("  ", depth) .. child.name
			local kind = (child.kind or "?") .. (if child.optional then " (optional)" else "")
			table.insert(lines, label .. string.rep(" ", math.max(1, 34 - #label)) .. kind)
			walk(child, depth + 1)
		end
	end
	walk(root, 0)
	return "```\n" .. table.concat(lines, "\n") .. "\n```"
end

-- The document with a freshly rendered element tree.
function UiContractDoc.updated(document: string): string
	local first = string.find(document, START, 1, true)
	local last = string.find(document, STOP, 1, true)
	assert(first and last and last > first, `{UiContractDoc.DOC_PATH} needs the markers {START} and {STOP}`)
	return string.sub(document, 1, first + #START - 1)
		.. "\n"
		.. UiContractDoc.render()
		.. "\n"
		.. string.sub(document, last)
end

return UiContractDoc
