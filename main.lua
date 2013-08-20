-- random seed
math.randomseed(os.time())


-- window size (default - gets set in love.load)
local window_width	= 800
local window_height	= 600


-- game settings
local grid_width	= 8
local grid_height	= 8
local square_size	= 16
local border_size	= 4
local square_space 	= 1

local request_mine_count	= math.floor(0.15625*(grid_width*grid_height))
local debug_mine_highlight	= false

local square_color	= {150, 150, 150}
local border_color	= {90, 90, 90}
local reveal_color	= {115, 115, 115}
local flag_color	= {205, 85, 85}
local count_colors	= {
	{0, 0, 205},
	{0, 205, 0},
	{205, 0, 0},
	{0, 0, 105},
	{105, 0, 0},
	{0, 105, 105},
	{105, 0, 105},
	{0, 0, 0}
}


-- timer
local timer_paused = true
local timer_time = 0


-- game state
local game_over 			= false						-- false = still player, 1 = lose, 2 = win
local actual_mine_count		= request_mine_count
local revealed_squares 		= 0
local flag_count 			= 0


-- grid generation
local grid
local grid_bound
local grid_start_x
local grid_start_y

local function gen_grid()
	-- constrain mine_count to (width-1)*(height-1)
	actual_mine_count = math.min(request_mine_count, (grid_height - 1)*(grid_width-1))

	-- clear grid
	grid = {}
	
	-- recalculate grid bounds
	grid_bound_w = grid_width*square_size + (grid_width - 1)*square_space
	grid_bound_h = grid_height*square_size + (grid_height - 1)*square_space
	grid_start_x = window_width/2 - grid_bound_w/2
	grid_start_y = window_height/2 - grid_bound_h/2
	
	-- generate random points for mine placement	
	local mine_pos = {}
	for x=1, grid_width do
		mine_pos[x] = {}
	end
	
	for i=1, actual_mine_count do
		local x, y
		repeat
			x = math.random(grid_width)
			y = math.random(grid_height)
		until not mine_pos[x][y]
		
		mine_pos[x][y] = true
	end
	
	-- generate new grid
	for x=1, grid_width do
		grid[x] = {}
		
		for y=1, grid_height do
			local s = {}
			s.revealed = false
			s.flagged = false
			s.mine = mine_pos[x][y]
			
			grid[x][y] = s
		end
	end
end


-- mouse position to grid position
local function mouse_to_grid(mx, my)
	if mx < grid_start_x or mx > grid_start_x + grid_bound_w or my < grid_start_y or my > grid_start_y + grid_bound_h then
		return false
	end
	
	local ox = mx - grid_start_x
	local oy = my - grid_start_y
	
	local gx = math.floor(grid_width*ox/grid_bound_w) + 1
	local gy = math.floor(grid_height*oy/grid_bound_h) + 1
	
	return true, gx, gy
end


-- check win condition
local function check_win()
	if grid_width*grid_height - revealed_squares == actual_mine_count then
		game_over = 2
		return
	end
end


-- reveal a square/neighbours
local reveal_neighbours
local reveal_square

reveal_square = function(x, y)
	if x < 1 or x > grid_width or y < 1 or y > grid_height then
		return
	end
	
	local s = grid[x][y]
	if s.revealed or s.flagged then
		return
	end	
	
	-- move mine to new square if first reveal hits a mine
	if revealed_squares == 0 and s.mine then
		s.mine = false
		
		local nx, ny
		repeat 
			nx = math.random(grid_width)
			ny = math.random(grid_height)
		until not grid[nx][ny].mine
		
		grid[nx][ny].mine = true
	end
	
	-- calculate neighbour mine count
	local count = 0
	for i=-1, 1 do
		for j=-1, 1 do
			if x ~= 0 or y ~= 0 then
				local row = grid[x+i]
				if row then
					local c = row[y+j]
					if c and c.mine then
						count = count + 1
					end
				end
			end
		end
	end
	
	s.revealed = true
	s.count = count
	
	if s.mine then
		game_over = 1
		return
	end
	
	revealed_squares = revealed_squares + 1
	
	-- check win condition
	check_win()
	
	-- if count is zero, reveal all surrounding squares
	if count == 0 then
		reveal_neighbours(x, y)
	end
end

reveal_neighbours = function(x, y)
	local s = grid[x][y]
	if not s.revealed then
		return
	end
	
	-- reveal all neighbours
	reveal_square(x-1, y-1)
	reveal_square(x-1, y)
	reveal_square(x-1, y+1)
	reveal_square(x, y-1)
	reveal_square(x, y+1)
	reveal_square(x+1, y-1)
	reveal_square(x+1, y)
	reveal_square(x+1, y+1)
end


-- flag square
local function flag_square(x, y)
	if x < 1 or x > grid_width or y < 1 or y > grid_height then
		return
	end
	
	local s = grid[x][y]
	if s.flagged then
		s.flagged = false
		flag_count = flag_count - 1
	else
		s.flagged = true
		flag_count = flag_count + 1
		
		-- check win condition
		check_win()
	end
end


-- load function
local win_font
local info_font
function love.load()
	-- set width and height variables
	window_width = love.graphics.getWidth()
	window_height = love.graphics.getHeight()
	
	-- load win font
	if not win_font then
		win_font = love.graphics.newFont(48)
	end
	
	-- load info font
	if not info_font then
		info_font = love.graphics.newFont(12)
	end

	-- reset state
	flag_count = 0
	revealed_squares = 0
	actual_mine_count = 0
	game_over = false
	timer_time = 0
	timer_paused = true
	
	-- generate grid
	gen_grid()
end


-- tick function
function love.update(dt)
	if not timer_paused and not game_over then
		timer_time = timer_time + dt
	end
end


-- draw function
function love.draw()
	-- calculate border bounds
	local bg_bound_w = grid_bound_w + 2*border_size
	local bg_bound_h = grid_bound_h + 2*border_size
	local bg_start_x = window_width/2 - bg_bound_w/2
	local bg_start_y = window_height/2 - bg_bound_h/2
	
	-- calculate font height
	local info_font_height = info_font:getHeight()
	local win_font_height = win_font:getHeight()

	-- draw border
	love.graphics.setColor(unpack(border_color))
	love.graphics.rectangle("fill", bg_start_x, bg_start_y, bg_bound_w, bg_bound_h)
	
	-- get mouse grid position
	local b, hx, hy = mouse_to_grid(love.mouse.getPosition())

	-- draw squares
	for i=1, grid_width do
		for j=1, grid_height do
		
			-- get position of current square
			local s_pos_x = grid_start_x + (i - 1)*square_size + (i - 1)*square_space
			local s_pos_y = grid_start_y + (j - 1)*square_size + (j - 1)*square_space
		
			-- draw cursor "highlight"
			if not game_over and b and hx == i and hy == j then
				love.graphics.setColor(85, 205, 85)
				love.graphics.rectangle("fill", s_pos_x - square_space, s_pos_y - square_space, square_size + square_space*2, square_size + square_space*2)
			end
		
			-- draw square
			local s = grid[i][j]
			if s.revealed then			
				if s.mine then
					love.graphics.setColor(unpack(flag_color))
				else					
					love.graphics.setColor(unpack(reveal_color))
				end
				
				love.graphics.rectangle("fill", s_pos_x, s_pos_y, square_size, square_size)
				
				if s.count > 0 and not s.mine then
					-- draw neighbour mine count
					love.graphics.setColor(unpack(count_colors[s.count]))
					love.graphics.setFont(info_font)
					love.graphics.printf(tostring(s.count), s_pos_x, s_pos_y + square_size/2 - info_font_height/2, square_size, "center")
				end
				
				if s.mine then
					love.graphics.setColor(0, 0, 0)
					love.graphics.circle("fill", s_pos_x + square_size/2, s_pos_y + square_size/2, square_size/4, 36)
				end
			else
				if s.flagged then					
					love.graphics.setColor(unpack(flag_color))
				elseif debug_mine_highlight and s.mine then
					love.graphics.setColor(205, 135, 135)
				else
					love.graphics.setColor(unpack(square_color))
				end
				
				love.graphics.rectangle("fill", s_pos_x, s_pos_y, square_size, square_size)
				
				if game_over == 1 then
					if s.flagged and not s.mine or not s.flagged and s.mine then
						love.graphics.setColor(0, 0, 0)
						love.graphics.line(s_pos_x + 2, s_pos_y + 2, s_pos_x + square_size - 3, s_pos_y + square_size - 3)
						love.graphics.line(s_pos_x + 2, s_pos_y + square_size - 3, s_pos_x + square_size - 3, s_pos_y + 2)
					end
				elseif game_over == 2 then
					love.graphics.setColor(0, 0, 0)
					love.graphics.circle("fill", s_pos_x + square_size/2, s_pos_y + square_size/2, square_size/4, 36)
				end
			end
		end
	end
	
	-- draw grid info
	love.graphics.setColor(255, 255, 255)
	love.graphics.setFont(info_font)
	love.graphics.print("grid size: " .. grid_width .. "x" .. grid_height, 10, 10, 0, 1, 1, 0, 0, 0, 0)
	love.graphics.print("mines left: " .. actual_mine_count - flag_count, 10.5, 25.5, 0, 1, 1, 0, 0, 0, 0)
	
	-- draw time
	love.graphics.print("time: " .. math.floor(timer_time) .. "s", window_width - 100, 10, 0, 1, 1, 0, 0, 0,0)
	
	-- we have a winner!
	if game_over == 2 and love.timer.getTime()%(0.53*2) <= 0.53 then
		love.graphics.setFont(win_font)
		love.graphics.printf("WINNER!", 0, window_height/2 - win_font_height/2, window_width, "center")
	end
end


-- mousepress event
function love.mousepressed(x, y, btn)
	if game_over then
		return
	end
	
	local b, gx, gy = mouse_to_grid(x, y)
	if b then
		if btn == "l" then
			reveal_square(gx, gy)
		elseif btn == "r" then
			flag_square(gx, gy)
		elseif btn == "m" then
			reveal_neighbours(gx, gy)
		end
		
		timer_paused = false
	end
end


-- keypress event
function love.keypressed(key)
	if key == " " then
		love.load()
	elseif key == "up" then
		grid_height = grid_height + 1
		love.load()
	elseif key == "down" then
		grid_height = math.max(2, grid_height - 1)
		love.load()
	elseif key == "right" then
		grid_width = grid_width + 1
		love.load()
	elseif key == "left" then
		grid_width = math.max(2, grid_width - 1)
		love.load()
	elseif key == "w" then
		request_mine_count = math.min(request_mine_count, actual_mine_count) + 1
		love.load()
	elseif key == "s" then
		request_mine_count = math.max(0, math.min(request_mine_count, actual_mine_count) - 1)
		love.load()
	elseif key == "a" then
		request_mine_count = math.floor(0.15625*(grid_width*grid_height))
		love.load()
	elseif key == "d" then
		request_mine_count = math.huge
		love.load()
		request_mine_count = actual_mine_count
	elseif key == "f3" then
		debug_mine_highlight = not debug_mine_highlight
	end
end