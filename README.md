# simpleScene
A simple way of making your own level editor in love2d/LÖVE and Lua. Loading and saving files is as easy as could be, and you can either 
run it using the included camera system and framework, or roll your own (or use your own favorites). It's easy to extend, and works great
for PSX style games. Including the Square Soft RPG's of the 90's (like Final Fantasy 7, 8, or 9), Lunar:Silver Star Story, SaGa Frontier 2, 
Legend of Mana, etc. Also great for making games like Hollow Knight, or point and click adventure games that use hand painted or complex
pixel art backgrounds.

# Basic Usage
Including the library is as easy as

    simpleScene=require("simpleSceneDesigner")

You can change the fonts and the screen resolution as you normally would in LÖVE. The windowing system and buttons automatically resize
to take advantage of the new size and dimensions. This makes it easy to support complex scenes in any resolution without issue.

You will need to init the library in function love.load(), like so-

    simpleScene:init({directories={editor="editorAssets"}})

Here, you include the directories you want to use. As you can see, the editor assets (which is necassary for using the editor) are
in the editorAssets directory. Other directories include-
- music, which stores the music to load
- scenes, which stores the saved scene files
- layers, which stores the background layer art (stored in png)
- sprites, which stores the object sprite art.

These are setup in a way that makes it easy to load and save while editing and playing the game, and makes it so it's simple to
package the game as a .love file (or bundle as an executable) without worrying about losing art/etc in other directories. 

If no directory is specified, then the root directory of main.lua is assumed, and you can just dump all of your graphics and
music assets there, if you want.

Next, you'll need to call the update and draw functions like so-

            function love.update(dt)
                simpleScene:update(dt)
            end

            function love.draw()
                simpleScene:draw()
            end

And that's it!

# Terms and concepts
This is a basica level designer. All levels are constructed as "scenes". Each scene has it's own scaling amount, name, camera, and background music
(if you wish to set any background music). These scenes are made up of layers and objects.

A layer can be scaled, has objects walking on it, and a background image that acts as the layer's background. You can also set scroll speeds to have it
move faster/slower than the main scene's camera, move the position so it's in a different area compared to the rest of the scene, set it's alpha tranperency,
and whether or not it's constantly scrolling (for fog effects). Notice, scaling of the layer effects the scroll speed relative to the main scene's camera.
This means, if you scale a layer really far back, so it looks like it's in the distance, it will scroll smaller and "behind" the main layers, thus giving it
a parallax effect. You can also place objects that will be scaled with the layer as well, making for complex parallax scenes. Moving clouds, monsters in the
distance, etc.

The "objects" in the game are just anything you place on a layer that's not a background. They can freely move between layers, and they are scaled
and positioned relative to the layer. Each object needs to be prepared ahead of time, before calling the editor or using it in a game.

It's just a simple function call-
    simpleScene:addObjectType({type="tree", image="tree.png"})

What's passed is a table, containing the type name for future reference, and an image to use when drawing/placing the object. There is more you can do with 
these object types, and we'll get to that later.



# Starting the editor
Just one function call loads and starts the editor
simpleScene:startEditing()

To leave the editor call
simpleScene:endEditing()

Make sure you have objects defined, as show above

# Using a saved scene in a game
This is also just a simple function call-
simpleScene:load("myScene.scene")

Where "myScene.scene" is the name of the scene you wish to load. Now, you may be asking yourself "well, how do I animate the objects? do collision detection? etc?"

The easiest way is to use the simpleScene framework. Remember object types above? You can pass init, update, and draw functions to that object type, like so

    simpleScene:addObjectType({type="npc", image="emily.png",
                                        init=function(self, object, simpleScene)
                                            --create a quad here for animations.
                                        end,
                                        update=function(self, object, simpleScene, dt)
                                            --perform the animation counter, etc. or use an animation library. Whatever works!
                                        end,
                                        draw=function(self, object, simpleScene)
                                        --use a quad here for animations
                                            love.graphics.draw(self.image, object.x, object.y)
                                        end,
                                        })

object is the actual object table on the map. Self is the object type table. simpleScene is the simpleScene table.
You can add variables to the table for tracking collision and animation, and then update and check against them in the update,
and change how things are drawn while drawing. If you want specific stuff only for the editor, for example outputting
a collision rectangle while editing, or showing the object id, you can check to see if the editor is running in the function with

                        if simpleScene.isediting==true then
                        etc. etc.
                        end

You can also add update, updateLayers, draw, drawLayers functions to the init of simpleScene, like so-

    simpleScene:init({directories={editor="editorAssets"}, functions={
            startGame=function(self)
                -- do something here. Self is the simpleScene table.
            end,
            init=function(self)
                -- do something here whenerver a new scene is loaded
            end,
            update=function(self, dt)
                --do here each update.
            end,
            draw=function(self)
                --and for each draw.
            end,
            layers=
            {
                init=function(self, layer)
                --this is called whenever a layer is created.
                end,
                update=function(self, layer, dt)
                --called on layer update.
                end,
                draw=function(self, layer)
                --called when a layer is drawn.
                end,
            }

    }})

This can add for a lot of power and flexibility to the game, and uses the same camera system/etc as the editor. This allows you to preview the game
exactly as is by running the same update code/etc for the game while in the editor.

# Using your own cameras/etc in a game 
So, you have a preffered camera system/etc and way of drawing layers, and you don't want to use this one in your game? That's fine! Just don't calle
simpleScene:update or draw in your game, and after you load the save file, you can get all of the layers and objects with two function calls.

simpleScene:getLayers()
simpleScene:getObjects()

You can also get individual layers and objects by calling
simpleScene:getLayer(layerID)
simpleScene:getObject(objectID)

The variables in layer tables are as follows-
    scale= the amount to scale, x and y are both scaled the same, so it's a singular number.
    reverse= whether or to reverse how it scales with the camera. Good for fog effects/etc. 
    alpha= the alpha blending of the layer
    x, y= the starting x and y offset of the layer
    visible= if it's visible
    imageName= the name of the background image to load
    scroll= a table, with 
                speed= relative scroll speed to the rest of the layer
                constant=
                        a table with
                        x= boolean for if it's constantly scrolling x
                        y=boolean for if it's constantly scrolling y

The variables in the object tables are as follows:
    scene= the scene this is in
    id= the object id
    image= the image to draw
    x= x position
    y= y position
    layer= the layer it's on

If you go the route of rolling your own camera/etc for running a scene saved in your game, you will also have to do your own zsorting.
