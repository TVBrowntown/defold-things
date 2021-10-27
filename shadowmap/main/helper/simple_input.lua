local M = {}

local registered_nodes = {}
local longtap = {}

local function ensure_node(node_or_node_id)
	return type(node_or_node_id) == "string" and gui.get_node(node_or_node_id) or node_or_node_id
end

--- Convenience function to acquire input focus
function M.acquire()
	msg.post(".", "acquire_input_focus")
end

--- Convenience function to release input focus
function M.release()
	msg.post(".", "release_input_focus")
end

--- Register a node and a callback to invoke when the node
-- receives input
function M.register(param, callback, value, click_cb, longtap_cb)
	assert(param, "You must provide a node")

	if type(param) == 'table' then
		local node = ensure_node(param.node)
		registered_nodes[node] = {
			url = msg.url(),
			callback = param.callback,
			click_cb = param.click_cb,
			node = node,
			scale = gui.get_scale(node),
			value = param.value,
			longtap_cb = param.longtap_cb 
			}
	else
		local node = ensure_node(param)
		registered_nodes[node] = {
			url = msg.url(),
			callback = callback,
			click_cb = click_cb,
			node = node,
			scale = gui.get_scale(node),
			value = value,
			longtap_cb = longtap_cb
			}
	end
end

--- Unregister a previously registered node or all nodes
-- registered from the calling script
-- @param node_or_string
function M.unregister(node_or_string)
	if not node_or_string then
		local url = msg.url()
		for k, node in pairs(registered_nodes) do
			if node.url == url then
				registered_nodes[k] = nil
				longtap[k] = nil
			end
		end
	else
		local node = ensure_node(node_or_string)
		registered_nodes[node] = nil
		longtap[node] = nil
	end
end

local function shake(node, initial_scale)
	gui.cancel_animation(node, "scale.x")
	gui.cancel_animation(node, "scale.y")
	gui.set_scale(node, initial_scale)
	local scale = gui.get_scale(node)
	gui.set_scale(node, scale * 1.2)
	gui.animate(node, "scale.x", scale.x, gui.EASING_OUTELASTIC, 0.8)
	gui.animate(node, "scale.y", scale.y, gui.EASING_OUTELASTIC, 0.8, 0.05, function()
		gui.set_scale(node, initial_scale)
	end)
end

local function is_enabled(node)
	local enabled = gui.is_enabled(node)
	local parent = gui.get_parent(node)
	if not enabled or not parent then
		return enabled
	else
		return is_enabled(parent)
	end
end

--- Forward on_input calls to this function to detect input
-- for registered nodes
-- @param action_id,
-- @param action
-- @return true if input a registerd node received input
M.TOUCH = hash("touch")
function M.on_input(self, action_id, action)
	if action_id ~= M.TOUCH then return end
	--print("action_id=", action_id, action.pressed, action.released, action.repeated)
	if action.pressed then
		local url = msg.url()
		for _,r_node in pairs(registered_nodes) do
			if r_node.url == url then
				local node = r_node.node
				if is_enabled(node) and gui.pick_node(node, action.x, action.y) then
					r_node.pressed = true
					if r_node.longtap_cb then
						r_node.startTime = socket.gettime()
						longtap[node] = r_node
					end
					if r_node.click_cb then r_node.click_cb(self, r_node.value, node) end
					shake(node, r_node.scale)
					return true, node
				end
			end
		end
	elseif action.released then
		local url = msg.url()
		for _, r_node in pairs(registered_nodes) do
			if r_node.url == url then
				local node = r_node.node
				local pressed = r_node.pressed
				r_node.pressed = false
				longtap[node] = nil
				if is_enabled(node) and gui.pick_node(node, action.x, action.y) and pressed then
					--shake(node, r_node.scale)
					if r_node.callback then r_node.callback(self, r_node.value, node) end
					return true, node
				end
			end
		end
	elseif action.repeated then
		local url = msg.url()
		for _, lt_node in pairs(longtap) do
			if lt_node.url == url then
				local node = lt_node.node
				local pressed = lt_node.pressed
				local t = socket.gettime() - lt_node.startTime
				if t>= 0.8 then
					if is_enabled(node) and gui.pick_node(node, action.x, action.y) and pressed then
						if lt_node.longtap_cb then lt_node.longtap_cb(self, lt_node.value, node) end
						longtap[node] = nil
						lt_node.pressed = false
						return true, node
					end
				end
			end
		end
	end
	return false
end

return M
