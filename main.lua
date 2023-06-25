--this will be the main example file.
simpleScene=require("simpleSceneDesigner")
love.graphics.setDefaultFilter("nearest","nearest")


function love.load() 
    --when we init we set the directories where it will find stuff.
    --default is same directory as source files, or "/"
    --we set the editor asset directory to be editorAssets
    simpleScene:init({directories={editor="editorAssets"}})

    --as you can see here, you can add draw functions to the object type that are called instead of the regular draw function.
    --this allows for animations/etc. what's passed- self is template, object is the instanatiated object, simpleScene is the simpleScene table.
    --other functions-
    -- init(self, object, simpleScene)
    -- update(self, object, simpleScene, dt)
    -- draw(self, object, simplescene)
    --[[
    simpleScene:addObjectType({type="npc", image="emily.png",
                                        draw=function(self, object, simpleScene)
                                            love.graphics.draw(self.image, object.x, object.y)
                                        end,
                                        })

    simpleScene:addObjectType({type="tree", image="tree.png"})

    simpleScene:newScene({name="", x=0, y=0})
    simpleScene:addObject({type="npc", x=100, y=20, layer=1})
    ]]
    simpleScene:newScene({name="", x=0, y=0})
    simpleScene:startEditing()
end

function love.update(dt)
    simpleScene:update(dt)
end

function love.draw()
    simpleScene:draw()
end
