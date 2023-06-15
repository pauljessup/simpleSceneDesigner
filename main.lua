--this will be the main example file.
simpleScene=require("simpleSceneDesigner")
love.graphics.setDefaultFilter("nearest","nearest")


function love.load() 
    
    --when we init we set the directories where it will find stuff.
    --default is same directory as source files, or "/"
    --we set the editor asset directory to be editorAssets. We set the scale to 3.
    --Note, only when using the editor do you ahve to set the scale here. You can do other scaling
    --stuff outside of the editor, it's only here, when using the mouse to edit, do you need it.
    simpleScene:init({directories={editor="editorAssets"}})

    simpleScene:setScale(3, 3)

    simpleScene:addObjectType({type="npc", image="emily.png",
                                        draw=function(self, object)
                                            love.graphics.draw(self.image, object.x, object.y)
                                        end,
                                        })

    simpleScene:addObjectType({type="tree", image="tree.png"})

    simpleScene:newScene({name="", x=0, y=0})
    simpleScene:addObject({type="npc", x=100, y=20, layer=1})
    simpleScene:startEditing()
end

function love.update(dt)
    simpleScene:update(dt)
end

function love.draw()
    simpleScene:draw()
end
