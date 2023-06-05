--this will be the main example file.
simpleScene=require("simpleScene")



function love.load() 
    simpleScene:addSceneType({type="nightscene", vars={}})
    simpleScene:addLayerType({type="basic", vars={}})
    simpleScene:addObjectType({type="npc", icon=love.graphics.newImage("emily.png"), image=love.graphics.newImage("emily.png")})

    simpleScene:newScene("start", "nightscene")
end

function love.update(dt)
    simpleScene:update(dt)
end

function love.draw()
    simpleScene:draw()
end
