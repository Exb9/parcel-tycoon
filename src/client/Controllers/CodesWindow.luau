--!strict
-- Codes window (Windows.Codes): type a code from social media and redeem it. The server checks it
-- (codes live server-side) and answers with a toast.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Ui = require(script.Parent.Parent.Lib.Ui)
local Windows = require(script.Parent.Windows)

local CodesWindow = {}

local WINDOW = "Codes"
local MAX_LENGTH = 40

function CodesWindow.init()
	local window = Windows.get(WINDOW)
	local input = Ui.find(window, "Input")
	local function redeem()
		if input and input:IsA("TextBox") and input.Text ~= "" then
			Net.event(Net.RedeemCode):FireServer(string.sub(input.Text, 1, MAX_LENGTH))
			input.Text = ""
		end
	end
	Ui.onActivated(Ui.button(window, "Redeem"), redeem)
	if input and input:IsA("TextBox") then
		input.FocusLost:Connect(function(enterPressed)
			if enterPressed then
				redeem()
			end
		end)
	end
end

return CodesWindow
