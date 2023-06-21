--this will be the main example file.
simpleScene=require("simpleSceneDesigner")
love.graphics.setDefaultFilter("nearest","nearest")


function love.load() 
    
    --when we init we set the directories where it will find stuff.
    --default is same directory as source files, or "/"
    --we set the editor asset directory to be editorAssets. We set the scale to 3.
    --Note, only when using the editor do you ahve to set the scale here. You can do other scaling
    --stuff outside of the editor, it's only here, when using the mouse to edit, do you need it.
    simpleScene:init({directories={editor="editorAssets", music="music"}})

    simpleScene:setScale(3, 3)

    --as you can see here, you can add draw functions to the object type that are called instead of the regular draw function.
    --this allows for animations/etc. what's passed- self is template, object is the instanatiated object, simpleScene is the simpleScene table.
    --other functions-
    -- init(self, object, simpleScene)
    -- update(self, object, simpleScene, dt)
    simpleScene:addObjectType({type="npc", image="emily.png",
                                        draw=function(self, object, simpleScene)
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
