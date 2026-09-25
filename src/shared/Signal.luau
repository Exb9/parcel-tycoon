--!strict
-- Minimal synchronous signal. Handlers run in connection order; an error in one handler is reported
-- with a traceback and does not stop the others.

export type Connection = {
	Disconnect: (self: Connection) -> (),
}

export type Signal<T...> = {
	Connect: (self: Signal<T...>, handler: (T...) -> ()) -> Connection,
	Fire: (self: Signal<T...>, T...) -> (),
}

local Signal = {}

local function report(err: any): string
	return debug.traceback(tostring(err), 2)
end

function Signal.new<T...>(): Signal<T...>
	local handlers: { (T...) -> () } = {}
	local signal = {}

	function signal.Connect(_self: any, handler: (T...) -> ()): Connection
		table.insert(handlers, handler)
		local connection = {}
		function connection.Disconnect(_connection: any)
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end
		return connection :: any
	end

	function signal.Fire(_self: any, ...: T...)
		local args = table.pack(...)
		for _, handler in table.clone(handlers) do
			local ok, message = xpcall(function()
				(handler :: any)(table.unpack(args, 1, args.n))
			end, report)
			if not ok then
				warn(message)
			end
		end
	end

	return signal :: any
end

return Signal
