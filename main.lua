--this will be the main example file.
simpleScene=require("simpleScene")
love.graphics.setDefaultFilter("nearest","nearest")


function love.load() 
    --you only need to call this for the editor. If you want, you can scale manually outside of this
    --the editor needs this for scaling the mouse x/y when dropping things/etc
    simpleScene:setScale(3, 3)
    simpleScene:setEditorResourceDirectory("editorAssets")

    simpleScene:addSceneType({type="nightscene", vars={}})
    simpleScene:addLayerType({type="basic", vars={}})
    simpleScene:addObjectType({type="npc", icon=love.graphics.newImage("emily.png"), image=love.graphics.newImage("emily.png"),
                                update=function(self, object, dt)
                                    --neat.
                                end,
                                draw=function(self, object)
                                    love.graphics.draw(self.icon, object.x, object.y)
                                end,
                                })

    simpleScene:newScene("start", "nightscene")
    simpleScene:addLayer({image=love.graphics.newImage("map.png"), x=0, y=0, type="basic"})
    simpleScene:addObject({type="npc", x=100, y=20})
    simpleScene:startEditing()
end

function love.update(dt)
    simpleScene:update(dt)
end

function love.draw()
    simpleScene:draw()
end
