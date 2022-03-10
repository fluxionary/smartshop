local get_node = minetest.get_node
local parse_json = minetest.parse_json
local pos_to_string = minetest.pos_to_string
local show_formspec = minetest.show_formspec
local swap_node = minetest.swap_node
local write_json = minetest.write_json

local S = smartshop.S
local class = smartshop.util.class
local player_is_admin = smartshop.util.player_is_admin
local string_to_pos = smartshop.util.string_to_pos
local table_is_empty = smartshop.util.table_is_empty

local api = smartshop.api

--------------------

local node_class = smartshop.node_class
local shop_class = class(node_class)
smartshop.shop_class = shop_class

--------------------

function shop_class:initialize_metadata(player)
	node_class.initialize_metadata(self, player)

	local player_name = player:get_player_name()
	local is_admin = player_is_admin(player_name)

	self:set_infotext(S("Shop by: @1", player_name))
	self:set_admin(is_admin)
	self:set_unlimited(is_admin)
	self:set_upgraded()
	self:set_state(0)  -- mesecons?
	self:set_strict_meta(false)
end

function shop_class:initialize_inventory()
	node_class.initialize_inventory(self)

	local inv = self.inv
	inv:set_size("main", 32)
	for i = 1, 4 do
		inv:set_size(("give%i"):format(i), 1)
		inv:set_size(("pay%i"):format(i), 1)
	end
end

--------------------

function shop_class:set_admin(value)
	self.meta:set_int("creative", value and 1 or 0)
	self.meta:mark_as_private("creative")
end

function shop_class:is_admin()
	return self.meta:get_int("creative") == 1
end

function shop_class:set_unlimited(value)
	self.meta:set_int("unlimited", value and 1 or 0)
	self.meta:mark_as_private("unlimited")
end

function shop_class:toggle_unlimited()
	local owner_is_admin = player_is_admin(self:get_owner())
	if self:is_unlimited() or not owner_is_admin then
		self:set_unlimited(false)
	else
		self:set_unlimited(true)
		self:set_send_pos()
		self:set_refill_pos()
	end
end

function shop_class:is_unlimited()
	local meta = self:get_meta()
	return meta:get_int("unlimited") == 1
end

function shop_class:set_send_pos(send_pos)
	local pos_as_string = send_pos and pos_to_string(send_pos) or ""
	self.meta:set_string("item_send", pos_as_string)
	self.meta:mark_as_private("item_send")
end

function shop_class:get_send_pos()
	local string_as_pos = self.meta:get_string("item_send")
	return string_to_pos(string_as_pos)
end

function shop_class:get_send()
	local send_pos = self:get_send_pos()
	if send_pos then
		local send = api.get_object(send_pos)
		if not send or not send:is_owner(self:get_owner()) then
			self:set_send_pos()
		end
		return send
	end
end

function shop_class:get_send_inv()
	local send = self:get_send()
	if send then
		return send.inv
	end
end

function shop_class:set_refill_pos(refill_pos)
	local pos_as_string = refill_pos and pos_to_string(refill_pos) or ""
	self.meta:set_string("item_refill", pos_as_string)
	self.meta:mark_as_private("item_refill")
end

function shop_class:get_refill_pos()
	local string_as_pos = self.meta:get_string("item_refill")
	return string_to_pos(string_as_pos)
end

function shop_class:get_refill()
	local refill_pos = self:get_refill_pos()
	if refill_pos then
		local refill = api.get_object(refill_pos)
		if not refill or not refill:is_owner(self:get_owner()) then
			self:set_refill_pos()
		end
		return refill
	end
end

function shop_class:get_refill_inv()
	local refill = self:get_refill()
	if refill then
		return refill.inv
	end
end

function shop_class:set_upgraded()
	self.meta:set_string("upgraded", "true")
	self.meta:mark_as_private("upgraded")
end

function shop_class:has_upgraded()
	return self.meta:get("upgraded")
end

function shop_class:set_refund(refund)
	if table_is_empty(refund) then
		self.meta:set_string("refund", "")
	else
		self.meta:set_string("refund", write_json(refund))
	end
	self.meta:mark_as_private("refund")
end

function shop_class:get_refund()
	local refund = self.meta:get("refund")
	return refund and parse_json(refund) or {}
end

function shop_class:has_refund()
	return self.meta:get("refund")
end

function shop_class:set_state(value)
	self.meta:set_int("state", value)
	self.meta:mark_as_private("state")
end

function shop_class:set_strict_meta(value)
	self.meta:set_int("strict_meta", value and 1 or 0)
	self.meta:mark_as_private("strict_meta")
end

function shop_class:is_strict_meta()
	return self.meta:get_int("strict_meta") == 1
end

--------------------

function shop_class:get_pay_stack(i)
	local inv = self.inv
	local listname = ("pay%i"):format(i)
	return inv:get_stack(listname, 1)
end

function shop_class:get_give_stack(i)
	local inv = self.inv
	local listname = ("give%i"):format(i)
	return inv:get_stack(listname, 1)
end

--------------------

function shop_class:link_storage(storage, storage_type)
	if storage_type == "send" then
		self:set_send_pos(storage.pos)
	elseif storage_type == "refill" then
		self:set_refill_pos(storage.pos)
	end

	self:update_appearance()
end

--------------------

function shop_class:get_count(stack)
	local match_meta = self:is_strict_meta()
	return node_class.get_count(self, stack, match_meta)
end

function shop_class:give_is_valid(i)
	local stack = self:get_give_stack(i)
	return not stack:is_empty() and stack:is_known()
end

function shop_class:can_give_count(i)
	local stack = self:get_give_stack(i)
	local count = self:get_count(stack)
	local refill = self:get_refill()
	if refill then
		local match_meta = self:is_strict_meta()
		count = count + refill:get_count(stack, match_meta)
	end
	return count
end

function shop_class:pay_is_valid(i)
	local stack = self:get_pay_stack(i)
	return not stack:is_empty() and stack:is_known()
end

function shop_class:has_pay(i)
	local stack = self:get_pay_stack(i)
	return self:contains_item(stack)
end

function shop_class:has_pay_count(i)
	local stack = self:get_pay_stack(i)
	local count = self:get_count(stack)
	local send = self:get_send()
	if send then
		local match_meta = self:is_strict_meta()
		count = count + send:get_count(stack, match_meta)
	end
	return count
end

function shop_class:room_for_pay(i)
	local stack = self:get_pay_stack(i)
	return self:room_for_item(stack)
end

function shop_class:can_exchange(i)
	return self:give_is_valid(i) and self:pay_is_valid(i) and self:can_give(i) and self:room_for_pay(i)
end

function shop_class:room_for_item(stack)
	if self:is_unlimited() then
		return true
	end

	if node_class.room_for_item(self, stack) then
		return true
	end

	local send = self:get_send()
	return send and send:room_for_item(stack)
end

function shop_class:add_item(stack)
	if self:is_unlimited() then
		return ItemStack()
	end

	local send = self:get_send()
	if send and send:room_for_item(stack) then
		return send:add_item(stack)
	end

	return node_class.add_item(self, stack)
end

function shop_class:contains_item(stack)
	if self:is_unlimited() then
		return true
	end

	local match_meta = self:is_strict_meta()

	if node_class.contains_item(self, stack, match_meta) then
		return true
	end

	local refill = self:get_refill()
	return refill and refill:contains_item(stack, match_meta)
end

function shop_class:remove_item(stack)
	if self:is_unlimited() then
		return stack
	end

	local strict_meta = self:is_strict_meta()
	local refill = self:get_refill()

	if refill and refill:contains_item(stack, strict_meta) then
		return refill:remove_item(stack, strict_meta)
	end

	return node_class.remove_item(self, stack, strict_meta)
end

--------------------

function shop_class:on_destruct()
	self:clear_entities()
end

--------------------

function shop_class:on_rightclick(node, player, itemstack, pointed_thing)
	if self:is_owner(player) and self:is_admin() and not player_is_admin(player) then
		-- if a shop is admin, but the player no longer has admin privs, revert the shop
		self:set_admin(false)
		self:set_unlimited((false))
	end

	node_class.on_rightclick(self, node, player, itemstack, pointed_thing)
end

function shop_class:show_formspec(player, force_client_view)
	local formspec
	if self:is_owner(player) and not force_client_view then
		formspec = api.build_owner_formspec(self)
	else
		formspec = api.build_client_formspec(self)
	end

	local formname = ("smartshop:%s"):format(self:get_pos_as_string())
	local player_name = player:get_player_name()

	show_formspec(player_name, formname, formspec)
end

local function get_buy_index(pressed)
    for i = 1, 4 do
        if pressed["buy" .. i] then
	        return i
        end
    end
end

function shop_class:receive_fields(player, fields)
    if fields.tsend then
        api.start_storage_linking(player, self, "send")

    elseif fields.trefill then
        api.start_storage_linking(player, self, "refill")

    elseif fields.customer then
        self:show_formspec(player, true)

    elseif fields.toggle_unlimited then
	    self:toggle_unlimited(player)
        self:show_formspec(player)

    elseif not fields.quit then
        local i = get_buy_index(fields)
        if i then
            api.try_purchase(player, self, i)
        end
    end

    self:update_appearance()
end

--------------------

function shop_class:update_appearance()
	self:update_variant()
	self:update_info()
	self:update_entities()
end

function shop_class:get_info_line(i)

	if not self:give_is_valid(i) or not self:pay_is_valid(i) then
		return
	end

	local give = self:get_give_stack(i)
	local def = give:get_definition()

	local description = def.short_description or (def.description or ""):match("^[^\n]*")
    if not description or description == "" then
        description = give:get_name()
    end
	description = description:gsub("%%", "%%%%")

	if self:is_unlimited() then
		return ("(inf) %s"):format(description)
	end

	local give_count = self:can_give_count(i)
	if give_count == 0 then
		return
	end
	return ("(%i) %s"):format(give_count, description)
end

function shop_class:update_info()
	local lines = {}
	for i = 1, 4 do
		local line = self:get_info_line(i)
		if line then
			table.insert(lines, line)
		end
	end

	local owner = self:get_owner()
	if #lines == 0 then
		self:set_infotext(S("(Smartshop by @1)\nThis shop is empty.", owner))
	else
		if self:is_unlimited() then
			table.insert(lines, 1, S("(Smartshop by @1) Stock is unlimited", owner))
		else
			table.insert(lines, 1, S("(Smartshop by @1) Purchases left:", owner))
		end
		self:set_infotext(table.concat(lines, "\n"))
	end
end

function shop_class:can_give(i)
	local give = self:get_give_stack(i)
	return self:contains_item(give)
end

function shop_class:compute_variant()
	if self:is_unlimited() then
		return "smartshop:shop_admin"
	end

	local n_total = 4
	local n_have_give = 0
	local n_have_pay = 0
	local n_have_room_for_pay = 0

	for i = 1, 4 do
		if not self:pay_is_valid(i) or not self:give_is_valid(i) then
			n_total = n_total - 1
		else
			if self:can_give(i) then
				n_have_give = n_have_give + 1
			end
			if self:has_pay(i) then
				n_have_pay = n_have_pay + 1
			end
			if self:room_for_pay(i) then
				n_have_room_for_pay = n_have_room_for_pay + 1
			end
		end
	end

	if n_total == 0 then
		-- unconfigured shop
		return "smartshop:shop"
	elseif n_have_room_for_pay ~= n_total then
		-- something can't be bought because the shop is full`
		return "smartshop:shop_full"
	elseif n_have_give ~= n_total then
		-- something is sold out
		return "smartshop:shop_empty"
	elseif n_have_pay > 0 then
		return "smartshop:shop_used"
	else
		-- shop is ready for use
		return "smartshop:shop"
	end
end

function shop_class:update_variant()
	local to_swap = self:compute_variant()

    local node = get_node(self.pos)
    local node_name = node.name
    if node_name ~= to_swap then
        swap_node(self.pos, {
            name = to_swap,
            param1 = node.param1,
            param2 = node.param2
        })
    end

	-- this logic is totally broken, disable it for the moment
	--self:update_send_variant(to_swap)
	--self:update_refill_variant(to_swap)
end

function shop_class:update_refill_variant(to_swap)
	local refill = self:get_refill()
	if not refill then return end

	local storage_variant
	if to_swap == "smartshop:shop_empty" then
		storage_variant = "smartshop:storage_empty"
	else
		storage_variant = "smartshop:storage"
	end

    local node = get_node(refill.pos)
    local node_name = node.name
    if node_name ~= storage_variant then
        swap_node(refill.pos, {
            name = storage_variant,
            param1 = node.param1,
            param2 = node.param2
        })
    end
end

function shop_class:update_send_variant(shop_to_swap)
	local send = self:get_send()
	if not send then return end

	local storage_variant
	if shop_to_swap == "smartshop:shop_full" then
		storage_variant = "smartshop:storage_full"
	elseif shop_to_swap == "smartshop:shop_used" then
		storage_variant = "smartshop:storage_used"
	else
		storage_variant = "smartshop:storage"
	end

    local node = get_node(send.pos)
    local node_name = node.name
    if node_name ~= storage_variant then
        swap_node(send.pos, {
            name = storage_variant,
            param1 = node.param1,
            param2 = node.param2
        })
    end
end

function shop_class:clear_entities()
	api.clear_entities(self.pos)
end

function shop_class:update_entities()
	-- TODO don't just clear the old entities, most of the time they don't even need to change...
	self:clear_entities()
	api.update_entities(self)
end

--------------------

function shop_class:allow_metadata_inventory_put(listname, index, stack, player)
	if node_class.allow_metadata_inventory_put(self, listname, index, stack, player) == 0 then
		return 0

	elseif listname == "main" then
		return stack:get_count()

	else
		-- interacting with give/pay slots
		local inv = self.inv

		local old_stack = inv:get_stack(listname, index)
		if old_stack:get_name() == stack:get_name() then
			local old_count = old_stack:get_count()
			local add_count = stack:get_count()
			local max_count = old_stack:get_stack_max()
			local new_count = math.min(old_count + add_count, max_count)
			old_stack:set_count(new_count)
			inv:set_stack(listname, index, old_stack)

		else
			inv:set_stack(listname, index, stack)
		end

		-- so we don't remove anything from the player's own stuff
		return 0
	end
end

function shop_class:allow_metadata_inventory_take(listname, index, stack, player)
	if node_class.allow_metadata_inventory_take(self, listname, index, stack, player) == 0 then
		return 0

	elseif listname == "main" then
		return stack:get_count()

	else
		local inv = self.inv
		local cur_stack = inv:get_stack(listname, index)
		local new_count = math.max(0, cur_stack:get_count() - stack:get_count())
		if new_count == 0 then
			cur_stack = ItemStack("")
		else
			cur_stack:set_count(new_count)
		end
		inv:set_stack(listname, index, cur_stack)
		return 0
	end
end

function shop_class:allow_metadata_inventory_move(from_list, from_index, to_list, to_index, count, player)
	if node_class.allow_metadata_inventory_move(self, from_list, from_index, to_list, to_index, count, player) == 0 then
		return 0

	elseif from_list == "main" and to_list == "main" then
		return count

	elseif from_list == "main" then
		local inv = self.inv
		local stack = inv:get_stack(from_list, from_index)
		stack:set_count(count)
		return self:allow_metadata_inventory_put(to_list, to_index, stack, player)

	elseif to_list == "main" then
		local inv = self.inv
		local stack = inv:get_stack(to_list, to_index)
		stack:set_count(count)
		return self:allow_metadata_inventory_take(from_list, from_index, stack, player)
	else
		return count
	end
end

function shop_class:on_metadata_inventory_put(listname, index, stack, player)
	if listname == "main" then
		node_class.on_metadata_inventory_put(self, listname, index, stack, player)
	end
end

function shop_class:on_metadata_inventory_take(listname, index, stack, player)
	if listname == "main" then
		node_class.on_metadata_inventory_take(self, listname, index, stack, player)
	end
end