local realchess = {}

local function index_to_xy(index)
	index = index - 1
	local x = index % 8
	local y = (index - x) / 8
	return x, y
end

local function xy_to_index(x, y)
	return x + y * 8 + 1
end

function realchess.init(pos)
	local meta = minetest.get_meta(pos)
	local inv = meta:get_inventory()
	local slots = "listcolors[#00000000;#00000000;#00000000;#30434C;#FFF]"
	local formspec
	
	inv:set_size("board", 64)
	
	meta:set_string("formspec",
		"size[8,8.6;]"..
		"bgcolor[#080808BB;true]"..
		"background[0,0;8,8;chess_bg.png]"..
		"button[3.2,7.6;2,2;new;New game]"..
		"list[context;board;0,0;8,8;]"..
		slots)
		
	meta:set_string("infotext", "Chess Board")
	meta:set_string("playerBlack", "")
	meta:set_string("playerWhite", "")
	meta:set_string("lastMove", "")
	meta:set_string("lastMoveTime", "")
	meta:set_string("winner", "")
	
	inv:set_list("board", {
		"realchess:rook_black_1",
		"realchess:knight_black_1",
		"realchess:bishop_black_1",
		"realchess:king_black",
		"realchess:queen_black",
		"realchess:bishop_black_2",
		"realchess:knight_black_2",
		"realchess:rook_black_2",
		"realchess:pawn_black_1",
		"realchess:pawn_black_2",
		"realchess:pawn_black_3",
		"realchess:pawn_black_4",
		"realchess:pawn_black_5",
		"realchess:pawn_black_6",
		"realchess:pawn_black_7",
		"realchess:pawn_black_8",		
		"", "", "", "", "", "", "", "",
		"", "", "", "", "", "", "", "",
		"", "", "", "", "", "", "", "",
		"", "", "", "", "", "", "", "",
		"realchess:pawn_white_1",
		"realchess:pawn_white_2",
		"realchess:pawn_white_3",
		"realchess:pawn_white_4",
		"realchess:pawn_white_5",
		"realchess:pawn_white_6",
		"realchess:pawn_white_7",
		"realchess:pawn_white_8",
		"realchess:rook_white_1",
		"realchess:knight_white_1",
		"realchess:bishop_white_1",
		"realchess:queen_white",
		"realchess:king_white",
		"realchess:bishop_white_2",
		"realchess:knight_white_2",
		"realchess:rook_white_2",
	})
end

function realchess.move(pos, from_list, from_index, to_list, to_index, count, player)
	if from_list ~= "board" and to_list ~= "board" then
		return 0
	end
	
	local playerName = player:get_player_name()
	local meta = minetest.get_meta(pos)
	
	if meta:get_string("winner") ~= "" then
		minetest.chat_send_player(playerName, "This game is over.")
		return 0
	end

	local inv = meta:get_inventory()
	local pieceFrom = inv:get_stack(from_list, from_index):get_name()
	local pieceTo = inv:get_stack(to_list, to_index):get_name()
	local lastMove = meta:get_string("lastMove")
	local thisMove -- will replace lastMove when move is legal
	local playerWhite = meta:get_string("playerWhite")
	local playerBlack = meta:get_string("playerBlack")
	
	if pieceFrom:find("white") then
		if playerWhite ~= "" and playerWhite ~= playerName then
			minetest.chat_send_player(playerName, "Someone else plays white pieces")
			return 0
		end		
		if lastMove ~= "" and lastMove ~= "black" then
			minetest.chat_send_player(playerName, "It's not your turn, wait for your opponent to play.")
			return 0
		end
		if pieceTo:find("white") then
			-- Don't replace pieces of same color
			return 0
		end
		playerWhite = playerName
		thisMove = "white"
	elseif pieceFrom:find("black") then
		if playerBlack ~= "" and playerBlack ~= playerName then
			minetest.chat_send_player(playerName, "Someone else plays black pieces")
			return 0
		end
		if lastMove ~= "" and lastMove ~= "white" then
			minetest.chat_send_player(playerName, "It's not your turn, wait for your opponent to play.")
			return 0
		end
		if pieceTo:find("black") then
			-- Don't replace pieces of same color
			return 0
		end
		playerBlack = playerName
		thisMove = "black"
	end
	
	-- DETERMINISTIC MOVING
	
	local from_x, from_y = index_to_xy(from_index)
	local to_x, to_y = index_to_xy(to_index)
	
	if pieceFrom:find("pawn") then
		if thisMove == "white" then
			-- white pawns can go up only
			if from_y - 1 == to_y then
				if from_x == to_x then
					if pieceTo ~= "" then
						return 0
					end
				elseif from_x - 1 == to_x or from_x + 1 == to_x then
					if not pieceTo:find("black") then
						return 0
					end
				else
					return 0
				end
			elseif from_y - 2 == to_y then
				if pieceTo ~= "" or from_y < 6 or inv:get_stack(from_list, xy_to_index(from_x, from_y - 1)):get_name() ~= "" then
					return 0
				end
			else
				return 0
			end
		elseif thisMove == "black" then
			-- black pawns can go down only
			if from_y + 1 == to_y then
				if from_x == to_x then
					if pieceTo ~= "" then
						return 0
					end
				elseif from_x - 1 == to_x or from_x + 1 == to_x then
					if not pieceTo:find("white") then
						return 0
					end
				else
					return 0
				end
			elseif from_y + 2 == to_y then
				if pieceTo ~= "" or from_y > 1 or inv:get_stack(from_list, xy_to_index(from_x, from_y + 1)):get_name() ~= "" then
					return 0
				end
			else
				return 0
			end
			
			-- if x not changed,
			--   ensure that destination cell is empty
			-- elseif x changed one unit left or right
			--   ensure the pawn is killing opponent piece
			-- else
			--   move is not legal - abort
			
			if from_x == to_x then
				if pieceTo ~= "" then
					return 0
				end
			elseif from_x - 1 == to_x or from_x + 1 == to_x then
				if not pieceTo:find("white") then
					return 0
				end
			else
				return 0
			end
		else
			return 0
		end

	elseif pieceFrom:find("rook") then
		if from_x == to_x then
			-- moving vertically
			if from_y < to_y then
				-- moving down
				-- ensure that no piece disturbs the way
				
				for i = from_y + 1, to_y - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x, i)):get_name() ~= "" then
						return 0
					end
				end
			else
				-- mocing up
				-- ensure that no piece disturbs the way
				
				for i = to_y + 1, from_y - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x, i)):get_name() ~= "" then
						return 0
					end
				end
			end
		elseif from_y == to_y then
			-- mocing horizontally
			if from_x < to_x then
				-- mocing right
				-- ensure that no piece disturbs the way
				
				for i = from_x + 1, to_x - 1 do
					if inv:get_stack(from_list, xy_to_index(i, from_y)):get_name() ~= "" then
						return 0
					end
				end
			else
				-- mocing left
				-- ensure that no piece disturbs the way
				
				for i = to_x + 1, from_x - 1 do
					if inv:get_stack(from_list, xy_to_index(i, from_y)):get_name() ~= "" then
						return 0
					end
				end
			end
		else
			-- attempt to move arbitrarily -> abort
			return 0
		end

	elseif pieceFrom:find("knight") then
		-- get relative pos
		local dx = from_x - to_x
		local dy = from_y - to_y
		
		-- get absolute values
		if dx < 0 then
			dx = -dx
		end
		if dy < 0 then
			dy = -dy
		end
		
		-- sort x and y
		if dx > dy then
			dx, dy = dy, dx
		end
		
		-- ensure that dx == 1 and dy == 2
		if dx ~= 1 or dy ~= 2 then
			return 0
		end
		
		-- just ensure that destination cell does not contain friend piece
		-- ^ it was done already thus everything ok

	elseif pieceFrom:find("bishop") then
		-- get relative pos
		local dx = from_x - to_x
		local dy = from_y - to_y
		
		-- get absolute values
		if dx < 0 then
			dx = -dx
		end
		if dy < 0 then
			dy = -dy
		end
		
		-- ensure dx and dy are equal
		if dx ~= dy then
			return 0
		end
		
		if from_x < to_x then
			if from_y < to_y then
				-- moving right-down
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x + i, from_y + i)):get_name() ~= "" then
						return 0
					end
				end
			else
				-- moving right-up
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x + i, from_y - i)):get_name() ~= "" then
						return 0
					end
				end
			end
		else
			if from_y < to_y then
				-- moving left-down
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x - i, from_y + i)):get_name() ~= "" then
						return 0
					end
				end
			else
				-- moving left-up
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x - i, from_y - i)):get_name() ~= "" then
						return 0
					end
				end
			end
		end
	elseif pieceFrom:find("queen") then
		local dx = from_x - to_x
		local dy = from_y - to_y
		
		-- get absolute values
		if dx < 0 then
			dx = -dx
		end
		if dy < 0 then
			dy = -dy
		end
		
		-- ensure valid relative move
		if dx ~= 0 and dy ~= 0 and dx ~= dy then
			return 0
		end
		
		if from_x == to_x then
			if from_y < to_y then
				-- goes down
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x, from_y + i)):get_name() ~= "" then
						return 0
					end
				end
			else
				-- goes up
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x, from_y - i)):get_name() ~= "" then
						return 0
					end
				end
			end		
		elseif from_x < to_x then
			if from_y == to_y then
				-- goes right
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x + i, from_y)):get_name() ~= "" then
						return 0
					end
				end
			elseif from_y < to_y then
				-- goes right-down
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x + i, from_y + i)):get_name() ~= "" then
						return 0
					end
				end
			else
				-- goes right-up
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x + i, from_y - i)):get_name() ~= "" then
						return 0
					end
				end
			end				
		else
			if from_y == to_y then
				-- goes left
				-- ensure that no piece disturbs the way and destination cell does
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x - i, from_y)):get_name() ~= "" then
						return 0
					end
				end
			elseif from_y < to_y then
				-- goes left-down
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x - i, from_y + i)):get_name() ~= "" then
						return 0
					end
				end
			else
				-- goes left-up
				-- ensure that no piece disturbs the way
				
				for i = 1, dx - 1 do
					if inv:get_stack(from_list, xy_to_index(from_x - i, from_y - i)):get_name() ~= "" then
						return 0
					end
				end
			end		
		end
	
	elseif pieceFrom:find("king") then
		local dx = from_x - to_x
		local dy = from_y - to_y
		
		-- get absolute values
		if dx < 0 then
			dx = -dx
		end
		if dy < 0 then
			dy = -dy
		end
		
		if dx > 1 or dy > 1 then
			return 0
		end
	end
	
	meta:set_string("playerWhite", playerWhite)
	meta:set_string("playerBlack", playerBlack)
	meta:set_string("lastMove", thisMove)
	meta:set_string("lastMoveTime", minetest.get_gametime())
	
	if pieceTo:find("king") then
		minetest.chat_send_player(playerBlack, playerName .. " won the game.")
		minetest.chat_send_player(playerWhite, playerName .. " won the game.")
		meta:set_string("winner", thisMove)
	end
	
	return 1
end
	
function realchess.fields(pos, formname, fields, sender)
	local playerName = sender:get_player_name()
	local meta = minetest.get_meta(pos)

	if fields.quit then return end

	-- The chess can't be reset while playing unless if nobody has played during a while
	if fields.new and (meta:get_string("playerWhite") == playerName or
			meta:get_string("playerBlack") == playerName) then
		realchess.init(pos)
	elseif fields.new and meta:get_string("lastMoveTime") ~= "" and
			minetest.get_gametime() >= tonumber(meta:get_string("lastMoveTime") + 250) and
			(meta:get_string("playerWhite") ~= playerName or
			meta:get_string("playerBlack") ~= playerName) then
		realchess.init(pos)
	else
		minetest.chat_send_player(playerName, "You can't reset the chessboard, a game has been started.\nIf you weren't playing it, try again after a while.")
	end
end

function realchess.dig(pos, player)
	local meta = minetest.get_meta(pos)
	local playerName = player:get_player_name()

	-- The chess can't be dug while playing unless if nobody has played during a while
	if (meta:get_string("playerWhite") ~= "" or meta:get_string("playerBlack") ~= "") and
			meta:get_string("lastMoveTime") ~= "" and
			minetest.get_gametime() <= tonumber(meta:get_string("lastMoveTime") + 250) then
		minetest.chat_send_player(playerName, "You can't dug the chessboard, a game has been started.\nIf you weren't playing it, try again after a while.")
		return false
	end
	
	return true
end

function realchess.on_move(pos, from_list, from_index, to_list, to_index, count, player)
	local inv = minetest.get_meta(pos):get_inventory()
	inv:set_stack(from_list, from_index, '')
	return false
end

function realchess.take(pos, listname, index, stack, player)
	return 0
end

minetest.register_node("realchess:chessboard", {
	description = "Chess Board",
	drawtype = "nodebox",
	paramtype = "light",
	paramtype2 = "facedir",
	inventory_image = "chessboard_top.png",
	wield_image = "chessboard_top.png",
	tiles = {"chessboard_top.png", "chessboard_top.png",
		"chessboard_sides.png", "chessboard_sides.png",
		"chessboard_top.png", "chessboard_top.png"},
	groups = {choppy=3, flammable=3},
	sounds = default.node_sound_wood_defaults(),
	node_box = {type = "fixed", fixed = {-0.5, -0.5, -0.5, 0.5, -0.4375, 0.5}},
	sunlight_propagates = true,
	can_dig = realchess.dig,
	on_construct = realchess.init,
	on_receive_fields = realchess.fields,
	allow_metadata_inventory_move = realchess.move,
	on_metadata_inventory_move = realchess.on_move,
	allow_metadata_inventory_take = realchess.take
})

local function register_piece(name, count)
	for _, color in pairs({"black", "white"}) do
	if not count then
		minetest.register_craftitem("realchess:"..name.."_"..color, {
			description = color:gsub("^%l", string.upper).." "..name:gsub("^%l", string.upper),
			inventory_image = name.."_"..color..".png",
			stack_max = 1,
			groups = {not_in_creative_inventory=1},
		})
	else
		for i = 1, count do
			minetest.register_craftitem("realchess:"..name.."_"..color.."_"..i, {
				description = color:gsub("^%l", string.upper).." "..name:gsub("^%l", string.upper),
				inventory_image = name.."_"..color..".png",
				stack_max = 1,
				groups = {not_in_creative_inventory=1},
			})
		end
	end
	end
end

register_piece("pawn", 8)
register_piece("rook", 2)
register_piece("knight", 2)
register_piece("bishop", 2)
register_piece("queen")
register_piece("king")

minetest.register_craft({ 
	output = "realchess:chessboard",
	recipe = {
		{"dye:black", "dye:white", "dye:black"},
		{"stairs:slab_wood", "stairs:slab_wood", "stairs:slab_wood"}
	} 
})

