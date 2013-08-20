function love.conf(t)
	t.title = "Minesweeper"
	t.author = "Matthew Reckless"
	
	t.release = false
	t.screen.width = 800
	t.screen.height = 600
	t.screen.vsync = true
	
	t.modules.joystick = false
	t.modules.physics = false
end