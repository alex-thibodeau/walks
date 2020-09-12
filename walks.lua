-- paths
--
-- create graphs, 
-- walk along them.
-- 
-- k1 is alt
-- enc1: change mode
--
-- DRAW mode:
-- ====================
-- enc2: move x
-- enc3: move y
--
-- k2 (hold + drag): draw edges
-- k3: place/move vertices
-- alt+k2: delete edge
-- alt+k3: delete vertex
--
-- the above controls sort of
-- 'snap' to the nearest
-- edge/vertex.

function init()
    -- first some globals
    mode = 0 -- 0: draw. 1: walk. 2: param?
    v_tolerance = 6 -- how close can vertices be?
    mode_visible = false -- show the mode text on the screen
    alt = false -- is alt held?
    drawing_edge = false -- are we currently drawing an edge?
    k3down = false -- is k3 held?
    cur_vertex = nil -- current vertex selected
    cur_index = nil -- INDEX Of current vertex selected
    screen.aa(1)
    
    -- some important points
    cursor = {}
	cursor.x = 0
	cursor.y = 0
	start = {}
	start.x = nil
	start.y = nil
	
	-- our tables describing our graph and her walkers
	vertices = {}
	edges = {}
	walkers = {}
	
	-- this just hides the mode text after some time
    mode_text_metro = metro.init(
        function() 
            mode_visible = not mode_visible 
            redraw()
        end, 
        2, 1)
    
    -- metronome controlling the walkers
    walk_metro = metro.init()
    walk_metro.time = 0.1
    walk_metro.count = -1
    walk_metro.event = move_walkers
    walk_metro:start()
    
    -- don't wanna flip thru pages too fast!!!
    norns.enc.sens(1, 100)
end

-- check if the grpah contains a given vertex
function containsvertex(v)
    for i, u in pairs(vertices) do
        if v.x == u.x and v.y == u.y then
            return i
        end
    end
    return false
end

-- check if the graph contains a given edge
function containsedge(v, u)
    for i, e in pairs(edges) do
        if (e[1].x == v.x and e[1].y == v.y and e[2].x== u.x and e[2].y == u.y)
                or (e[2].x == v.x and e[2].y == v.y and e[1].x == u.x and e[1].y == u.y) then
            return i
        end
    end
    return false
end

function redraw()
	screen.clear()
	
	-- draw edges
	if drawing_edge then
	    screen.level(1)
	    screen.move(start.x, start.y)
	    screen.line(cursor.x, cursor.y)
	    screen.stroke()
	end
	screen.level(3)
	for _, e in pairs(edges) do
	    screen.move(e[1].x, e[1].y)
	    screen.line(e[2].x, e[2].y)
	    screen.stroke()
	end
	
	-- and vertices
	for _, v in pairs(vertices) do
    	if v.walker then screen.level(10) else screen.level(6) end
	    screen.circle(v.x, v.y, 2)
	    screen.fill()
    	screen.stroke()
	end
	
	-- and cursor
	if mode == 0 then
    	screen.level(15)
    	screen.pixel(cursor.x, cursor.y)
    	screen.stroke()
    end
    
    -- and walkers
    screen.level(13)
    for _, w in pairs(walkers) do
        screen.pixel(w.x, w.y)
        screen.stroke()
    end
    
    if mode == 1 then
        screen.level(15)
        if cur_vertex then screen.circle(cur_vertex.x, cur_vertex.y, 5) end
        screen.stroke()
    end
	
	-- maybe the mode text
	if mode_visible then
        screen.move(0, 64)
        screen.level(12)
        local text = nil
        if mode == 0 then
            text = "DRAW"
        elseif mode == 1 then
            text = "WALK"
        elseif mode == 2 then
            text = "EDIT"
        end
        screen.text(text)
    end
    
	screen.update()
end

-- also remove any edges adjacent to the given vertex-slightly complicated
-- procedure just for this reason.
function removevertex(indx)
    v = vertices[indx]
    for i, u in pairs(vertices) do
        eindx = containsedge(u, v)
        if eindx then
           table.remove(edges, eindx) 
        end
    end
    table.remove(vertices, indx)
end

-- TODO : abstract a good deal of this... this is freaking disgusting
-- TODO : clean up redraws and consolidate... clean up in general tbh
function key(n, z)
    if n == 1 then
        alt = not alt
    end
    if mode == 0 then -- draw mode
        if n == 3 then k3down = not k3down end
        if n == 3 and z == 1 then
            -- possibly nil or false, this is fine and accounted for
            local i, d = closestvertex(cursor)
            if alt and i then
                removevertex(i)
            end
            if not alt and not i then
                if d > v_tolerance then
                    table.insert(vertices, {["x"] = cursor.x, ["y"] = cursor.y, ["walker"] = false})
                end
            end
            redraw()
        elseif n == 2 then
            if z == 1 then
                if alt then
                    if k3down then 
                        vertices = {}
                        edges = {}
                        redraw()
                    else
                        local i, _ = closestedge(cursor)
                        if i then table.remove(edges, i) end
                    end
                else
                    local i, _ = closestvertex(cursor)
                    if i then
                        start = vertices[i]
                        drawing_edge = true
                        redraw()
                    end
                end
            elseif z == 0 then
                if not alt then
                    -- warning: gross condition ahead
                    local i, _ = closestvertex(cursor)
                    if i and start.x ~= nil and start.y ~= nil 
                            and not containsedge(start, cursor)then
                        table.insert(edges, {start, vertices[i]})
                        start = nil -- reset start point
                    end
                end
                drawing_edge = false
                redraw()
            end
        end
    elseif mode == 1 then -- walk mode
        if n == 3 and z == 1 then
            if cur_vertex then
                if not cur_vertex.walker then
                    cur_vertex.walker = true
                    table.insert(walkers, 
                        {
                            ["home"] = cur_vertex, 
                            ["last"] = cur_vertex,
                            ["target"] = nil,
                            ["x"] = cur_vertex.x, 
                            ["y"] = cur_vertex.y,
                            ["cur_slope"] = 0,
                            ['walking'] = false
                        })
                elseif cur_vertex.walker then
                    
                end
                redraw()
            end
        end
    end
end

function move_walkers(c)
    for _, w in pairs(walkers) do
        if w.walking then
            local l = math.sqrt(1 + w.cur_slope^2)
            local dx = (w.target.x < w.last.x) and (-1 / l) or (1 / l)
            local dy = w.cur_slope / l
            w.x = w.x + dx
            w.y = w.y + dy
            local i, d = closestvertex(w)
            if vertices[i] == w.target and d < 1.5 then
                w.last = vertices[i]
                w.target = nil
                w.x = vertices[i].x
                w.y = vertices[i].y
                w.cur_slope = 0
                w.walking = false
            end
        else
            local neighbors = neighborhood(w.last)
            if #neighbors > 0 then
                w.target = neighbors[math.random(#neighbors)]
                w.cur_slope = (w.target.y - w.last.y) / math.abs(w.target.x - w.last.x)
                w.walking = true
            end
        end
    end
    redraw()
end

function neighborhood(v)
    local neighbors = {}
    for _, e in pairs(edges) do
       if e[1] == v then
           table.insert(neighbors, e[2])
        elseif e[2] == v then
            table.insert(neighbors, e[1])
        end
    end
    return neighbors
end

function closestvertex(v)
    local min = 999 -- surely big enough
    local indx = nil
    local d = min
    for i, u in pairs(vertices) do
        d = math.sqrt((u.x - v.x)^2 + (u.y - v.y)^2)
        if d < min then
            min = d
            -- if a vertex is especially close, return it.
            -- this is useful for drawing edges since being
            -- right on top of a vertex is difficult and annoying.
            -- this provides a sort of 'snap'
            if min < v_tolerance then indx = i end
        end
    end
    return indx, min
end

function closestedge(v)
    -- this is much more complicated....
    local min = 999
    local indx = nil
    local d = min
    for i, e in pairs(edges) do
        local slope = (e[2].y - e[1].y) / (e[2].x - e[1].x)
        local perp = -(1 / slope)
        -- disgusting formulas below...
        local xint = (v.y - perp * v.x + slope * e[1].x - e[1].y) / (slope - perp)
        local yint = slope * (xint - e[1].x) + e[1].y
        d = math.sqrt((v.x - xint)^2 + (v.y - yint)^2)
        if d < min then
            min = d
            if min < 2.5 then indx = i end
        end
    end
    return indx, min
end

function enc(n, d)
    if n == 1 then
        if d > 0 then
            mode = math.min(2, mode + 1)
        elseif d < 0 then
            mode = math.max(0, mode - 1)
        end
        mode_visible = true
        mode_text_metro:start()
        if mode == 1 and not cur_vertex and vertices[1] then
            cur_index = 1
            cur_vertex = vertices[1]
        end
    else
        if mode == 0 then
            local moving_vertex = false
            local i, _ = closestvertex(cursor)
            if k3down and i then
                moving_vertex = true
                cursor.x = vertices[i].x
                cursor.y = vertices[i].y
            end
        	if n == 2 then
        		cursor.x = math.max(0, math.min(128, cursor.x + d))
        	end
        	if n == 3 then
        	    cursor.y = math.max(0, math.min(64, cursor.y - d))
        	end
        	if moving_vertex then
        	    vertices[i].x = cursor.x
        	    vertices[i].y = cursor.y
        	end
    	elseif mode == 1 then
    	    if n == 2 and cur_index then
    	        if d > 0 then
    	            cur_index = math.min(cur_index + 1, #vertices)
    	        elseif d < 0 then
    	            cur_index = math.max(cur_index - 1, 1)
    	        end
    	        cur_vertex = vertices[cur_index]
	        end
    	end
    end
    redraw()
end

-- for debug
function printedges()
    print("x1", "y1", "x2", "y2")
    for i, e in pairs(edges) do
        print(e[1].x, e[1].y, e[2].x, e[2].y)
    end
end

-- for debug
function printvertices()
    print("x1", "y1")
    for i, v in pairs(vertices) do
        print(v.x, v.y)
    end
end