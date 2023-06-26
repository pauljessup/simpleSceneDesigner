--Here is just a simple example on how to use it.
simpleScene=require("simpleSceneDesigner")
love.graphics.setDefaultFilter("nearest","nearest")


function love.load() 
    --when we init we set the directories where it will find stuff.
    --default is same directory as source files, or "/"
    --we set the editor asset directory to be editorAssets
    simpleScene:init({directories={editor="editorAssets"}})

    simpleScene:startEditing()
end

function love.update(dt)
    simpleScene:update(dt)
end

function love.draw()
    simpleScene:draw()
end
