local folderOfThisFile = (...):match("(.-)[^%.]+$")
local function drawSort(a,b) return a.y+a.h < b.y+b.h end

return {
            editState="move",
            useGrid=false,
            activeLayer=1,
            objPageAt=1,
            sceneTypes={},
            layerTypes={},
            editorState="scene",
            fileSelect=false,
            name="",
            size={width=love.graphics.getWidth(), height=love.graphics.getHeight()},
            objectTypes={},
            layers={},
            objects={},
            editing=false,
            topMenuHide=false,
            windowColors={font={1, 1, 1,}, background={63/255, 63/255, 126/255, 150/255}, border={63/255, 63/255, 116/255, 255/255}},
            scale={x=1, y=1},
            editorScale={x=1, y=1},
            path=love.filesystem.getSource(),
            binser=require(folderOfThisFile .. "binser"),
            editorObject={},
            topMenuSize=100,
            vars={},
            zsort={},
            cooldown=0.0, --so mousepresses don't repeat a ton.
            --this allows us to search for background images, or to load scenes.
            --default is parent directory.
            directories={scenes="", layers="", editor="", sprites=""},
           init=function(self, info)
                local dir=info.directories
                if dir~=nil then
                    if dir.scenes~=nil then self.directories.scenes=dir.scenes end
                    if dir.layers~=nil then self.directories.layers=dir.layers end
                    if dir.editor~=nil then self.directories.editor=dir.editor end
                    if dir.sprites~=nil then self.directories.sprites=dir.sprites end
                end
                if info.scale~=nil then 
                    self:setScale(info.scale[1], info.scale[2]) 
                    self.editorScale={x=info.scale[1], y=info.scale[2]}
                else
                    self.editorScale={x=2, y=2}
                end


                self.topMenuSize=self.topMenuSize/self.editorScale.y

                --now we load the gui images for the editor.
                self.guiImages={
                                    arrow=love.graphics.newImage(self.directories.editor .. "/arrow.png"),
                                    gridButton=love.graphics.newImage(self.directories.editor .. "/gridDrop.png"),
                                    objDrop=love.graphics.newImage(self.directories.editor .. "/objectdrop.png"),
                                    objDel=love.graphics.newImage(self.directories.editor .. "/deleteobject.png"),
                                    objMove=love.graphics.newImage(self.directories.editor .. "/objectmove.png"),
                                    layerUp=love.graphics.newImage(self.directories.editor .. "/layerup.png"),
                                    layerDown=love.graphics.newImage(self.directories.editor .. "/layerdown.png"),
                                    newLayer=love.graphics.newImage(self.directories.editor .. "/newlayer.png"),
                                    backgroundImage=love.graphics.newImage(self.directories.editor .. "/backgroundImage.png"),
                                    moveLayer=love.graphics.newImage(self.directories.editor .. "/moveLayer.png"),
                                    tileLayer=love.graphics.newImage(self.directories.editor .. "/tileLayer.png"),
                                    plus=love.graphics.newImage(self.directories.editor .. "/up.png"),
                                    minus=love.graphics.newImage(self.directories.editor .. "/down.png"),
                } 
                -- add basic types
                simpleScene:addLayerType({type="basic", vars={}})
                simpleScene:addSceneType({type="basic", vars={}})
           end,
           setWindowColor=function(self, font, background, border)
                self.windowColors.background=background
                self.windowColors.border=border 
                self.windowColors.font=font
           end,
           setSceneDirectory=function(self, directory)
            self.directories.scenes=directory
           end,
           setLayerDirectory=function(self, directory)
            self.directories.layers=directory
           end,
           setEditorResourceDirectory=function(self, directory)
            self.directories.editor=directory
           end,
           drawWindow=function(self, window)
                local oldColor={}
                oldColor[1], oldColor[2], oldColor[3], oldColor[4]=love.graphics.getColor()
                local b, o=self.windowColors.background, self.windowColors.border
                if window.border then o=window.border end 
                if window.background then b=window.background end
                love.graphics.setColor(b[1], b[2], b[3], b[4])
                love.graphics.rectangle("fill", window.x, window.y, window.w, window.h)
                love.graphics.setColor(o[1], o[2], o[3], o[4])
                love.graphics.rectangle("line", window.x, window.y, window.w, window.h)
                love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
           end,
           setScale=function(self, scalex, scaley)
                self.scale={x=scalex, y=scaley}
            end,
            newScene=function(self, vars)
                self:clean()
                self.name=vars.name
                self.type=vars.type
                if vars.x~=nil and vars.y~=nil then
                    self.x=vars.x
                    self.y=vars.y
                end
                if vars.x==nil then vars.x=0 end
                if vars.y==nil then vars.y=0 end
                if vars.gridSize~=nil then self.gridSize=vars.gridSize else self.gridSize=8 end

                if vars.width~=nil and vars.height~=nil then
                    self.size={width=vars.width, height=vars.height}
                else
                    self.size={width=love.graphics:getWidth(), height=love.graphics:getHeight()}
                end
                self.vars=vars.vars
                self.canvas={scene=love.graphics.newCanvas(self.size.width, self.size.height), editor=love.graphics.newCanvas(self.size.width, self.size.height)}
                --first blank layer--
                simpleScene:addLayer({x=0, y=0, type="basic"})
            end,
            clean=function(self)
                for i=#self.layers, -1 do self.layers[i]=nil end self.layers={}
                for i=#self.objects, -1 do self.objects[i]=nil end self.objects={}
            end,
            load=function(self, data)
                local data, len=binser.readFile(self.path .. "/" .. self.name)
                self:clean()
                self.layers=data.layers 
                self.objects=data.objects
            end,
            save=function(self)
                --serialize it and write to a file
                --add scene info here as well, like name, x, y, width, height, etc.
                binser.writeFile(self.path .. "/" .. self.name, binser.serialize({layers=self.layers, objects=self.objects}))
            end,
            addLayer=function(self, data)
                if data.speed==nil then data.speed=1.0 end
                if data.alpha==nil then data.alpha=1.0 end 
                if data.x==nil then data.x=0 end
                if data.y==nil then data.y=0 end
                if data.image then
                    data.imageName=data.image
                    data.image=love.graphics.newImage(self.directories.layers .. data.image)
                end
                self.layers[#self.layers+1]=data
            end,
            addObject=function(self, data)
                --sanity check
                if self.objectTypes[data.type]==nil then error(data.type .. " object type doesn't exist") end

                --add other variable data.
                local width, height=self.objectTypes[data.type].width,self.objectTypes[data.type].height

                data.width=width 
                data.height=height
                data.id=#self.objects+1
                data.scene=self.name
                self.objects[data.id]=data
            end,
            update=function(self, dt)
                if self.editing==true then
                    self:updateEditor(dt)
                end
                if self.sceneTypes[self.type]~=nil and self.sceneTypes[self.type].update~=nil then
                    self.sceneTypes[self.type]:update(dt)
                end
                for il, layer in ipairs(self.layers) do 
                    local type=self.layerTypes[layer.type]
                    if type.update~=nil and self.editing==false then type:update(layer, dt) end
                end
                for ob, object in ipairs(self.objects) do 
                    local type=self.objectTypes[object.type]
                    if type.update~=nil and self.editing==false then type:update(object, dt) end                    
                end
                --zsorting...
                for i=#self.zsort, -1 do self.zsort=nil end 
                self.zsort={}
                for i,v in ipairs(self.objects) do
                    self.zsort[#self.zsort+1]={id=i, x=v.x, y=v.y, h=v.height, w=v.width}
                end

                table.sort(self.zsort, drawSort)
            end,
            ---allow the dev to query layers and objects, in case they want
            --to use something other than the simpleScene's default system for drawing and updating.
            getLayers=function(self)
                return self.layers
            end,
            getLayer=function(self, layer)
                if self.layers[layer]==nil then error("Layer " .. layer .. " doesn't exist") end
                return self.layers[layer]
            end,
            getObjects=function(self, layerid)
                if layerid~=nil and self.layers[layerid]~=nil then
                    local objects={}
                    for i,v in ipairs(self.objects) do
                        if v.layer==layerid then
                            objects[#objects+1]=v
                        end
                    end
                    return objects
                else
                    return self.objects
                end
            end,
            getObject=function(self, id)
                if id==nil and self.objecs[id]==nil then 
                    error("Object id " .. id .. " doesn't exist.")
                else
                    return self.objects[id]
                end
            end,
            drawObjects=function(self, layer, x, y)
                local didlight, litId=false, 0

                if self.editing then
                    local mx, my=self:scaleMousePosition(true)
                    local windowH=self.topMenuSize+16
                    if self.topMenuHide==true then windowH=16 end
                    if my>(windowH+16) then
                        local mx, my=self:scaleMousePosition(false)
                            if (self.editState=="move" or self.editState=="delete") and self.dragNDrop==nil then
                                for i,v in ipairs(self.zsort) do
                                    local object=self.objects[v.id]
                                    local type=self.objectTypes[object.type]
                                    if self:mouseCollide(object)  then
                                        didlight=true 
                                        litId=i
                                    end
                                end
                            end
                    end
                end

                for i,v in ipairs(self.zsort) do
                    local object=self.objects[v.id]
                    local type=self.objectTypes[object.type]
                    if didlight and litId==i then
                            love.graphics.setColor(0.5, 0.5, 0.5, 1)
                    end
                    if type.draw~=nil then
                            type:draw(object, x, y, self.editing) 
                    elseif type.image~=nil then
                        love.graphics.draw(type.image, object.x+x, object.y+y)
                    end
                    love.graphics.setColor(1, 1, 1, 1)
                end
            end,
            drawLayer=function(self, x, y, layer)
                --if it's passing the layer number...
                if type(layer)~="table" then layer=self.layers[layer] end
                local type=self.layerTypes[layer.type]
                if type.draw~=nil then
                    type:draw(layer, x+self.layers[layer].x, y+self.layers[layer].y)
                else
                    --if there is no draw function and there is an image, just draw the image relative to camera coords.
                    if layer.image~=nil then
                        love.graphics.draw(layer.image, x+layer.x, y+layer.y)
                    end
                end
                --draw the grid if in editor and grid is set.
                if self.editing then
                    if self.useGrid==true then
                        love.graphics.setColor(1, 1, 1, 0.12)
                        for x=0, self.size.width, self.gridSize do
                            love.graphics.line((-self.x)+x, -self.y, (-self.x)+x, self.size.height)
                        end
                        for y=0, self.size.width, self.gridSize do
                            love.graphics.line((-self.x), (-self.y)+y, self.size.width, (-self.y)+y)
                        end
                        love.graphics.setColor(1, 1, 1, 1)
                    end
                end
                self:drawObjects(il, x, y)   
            end,
            draw=function(self, x, y)
                if x==nil then x=self.x end
                if y==nil then y=self.y end
                love.graphics.setCanvas(self.canvas.scene)
                love.graphics.clear()
                for il,layer in ipairs(self.layers) do 
                        self:drawLayer(x, y, layer)
                end

                if self.sceneTypes[self.type]~=nil and self.sceneTypes[self.type].draw~=nil then
                    self.sceneTypes[self.type]:draw()
                end
                self:mouseDrop()
                love.graphics.setCanvas()
                love.graphics.draw(self.canvas.scene, 0, 0, 0, self.scale.x, self.scale.y)
                if self.editing==true then 
                    self:drawEditor() 
                    love.graphics.draw(self.canvas.editor, 0, 0, 0, self.editorScale.x, self.editorScale.y)
                end
            end,

------------------------------------------------------------------------EDITOR FUNCTIONALITY----------------------------------------------------
            startEditing=function(self) self.editing=true end,
            endEditing=function(self) self.editing=true end,
            addSceneType=function(self, type)
                self.sceneTypes[type.type]=type
            end,
            addObjectType=function(self, type)
                if type.image~=nil then 
                    type.imageName=type.image
                    type.image=love.graphics.newImage(self.directories.sprites .. type.image) 
                end
                if type.width==nil then type.width=type.image:getWidth() end
                if type.height==nil then type.height=type.image:getHeight() end
  
                self.objectTypes[type.type]=type
                self.editorObject[#self.editorObject+1]=type.type
            end,
            addLayerType=function(self, type)
                if type.x==nil then type.x=0 end 
                if type.y==nil then type.y=0 end 
                self.layerTypes[type.type]=type
            end,
            moveLayer=function(self, layer, x, y)
                self.layers[layer].x=x
                self.layers[layer].y=y
            end,
            moveScene=function(self, x, y)
                self.x=x
                self.y=y
            end,
            changeSceneSize=function(self, width, height)
                self.size={width=width, height=height}
            end,

            scaleMousePosition=function(self, editor)
                local scale={x=self.scale.x, y=self.scale.y}
                if editor then scale.x=self.editorScale.x scale.y=self.editorScale.y  end
                local mx, my = love.mouse.getPosition()
                mx=math.floor(mx/scale.x)
                my=math.floor(my/scale.y)
                return mx, my
            end,
            drawMsgBox=function(self)
                --this draws the mssg box when adding layer or dropping an object
                --so that you can specify additional variables, based on a vars variable
                --added when creating the object type or the layer type or the scene type.
            end,

            mouseCollide=function(self, col, editor)
                local mx, my = self:scaleMousePosition(editor)

                if col.layer and self.activeLayer and (col.layer~=self.activeLayer) then return false end
                if   col.x < mx+2 and
                mx < col.x+col.width and
                col.y < my+2 and
                my < col.y+col.height 
                then
                    return true
                end
                return false
            end,
            mouseDrop=function(self)
                local mx, my=self:scaleMousePosition(true)
                --show object under mouse to drop
                if self.dropObject~=nil and self.editState=="drop" then
                    local obj=self.objectTypes[self.editorObject[self.dropObject]]
                    local windowH=self.topMenuSize
                    if self.topMenuHide==true then windowH=16 end
                    if my>(windowH+32)then
                        mx, my=self:scaleMousePosition(false)
                        love.graphics.setColor(1, 1, 1, 0.7)
                        if self.useGrid then 
                            mx=self.gridSize*(math.floor(mx/self.gridSize)) 
                            my=self.gridSize*(math.floor(my/self.gridSize)) 
                        end
                        if obj.draw~=nil then 
                            obj:draw({x=mx-(obj.width/2), y=my-(obj.height/2)})
                        else
                            love.graphics.draw(obj.image, mx-(obj.width/2), my-(obj.height/2))
                        end
                        love.graphics.setColor(1, 1, 1, 1)
                    end
                end

            end,
            mouseOverObject=function(self)
                --make sure you can't accidently select things hidden behind the windows.
                local mx, my=self:scaleMousePosition(true)
                local windowH=self.topMenuSize+16
                if self.topMenuHide==true then windowH=16 end
                if my>(windowH+16) then

                        if  self.dragNDrop==nil and (self.editState=="move" or self.editState=="delete") and self.cooldown==0.0 then
                                for i,v in ipairs(self.zsort) do
                                    local object=self.objects[v.id]
                                    if self:mouseCollide(object, false) then
                                        if love.mouse.isDown(1) then
                                            self.cooldown=1.0
                                            self.dragNDrop=v.id
                                        end
                                    end
                                end
                        end
                        if self.dragNDrop~=nil and self.editState=="delete" then
                            table.remove(self.objects, self.dragNDrop)
                            self.dragNDrop=nil
                        end
                        
                        if self.dragNDrop~=nil and self.editState=="move" then
                            local mx, my=self:scaleMousePosition()
                            local windowH=self.topMenuSize
                            if self.topMenuHide==true then windowH=16 end
                            if my>(windowH+32)then
                                --draw it being moved.
                                local obj=self.objects[self.dragNDrop]
                                obj.x=mx-(obj.width/2) 
                                obj.y=my-(obj.height/2)
                                if self.useGrid then 
                                    obj.x=self.gridSize*(math.floor(obj.x/self.gridSize)) 
                                    obj.y=self.gridSize*(math.floor(obj.y/self.gridSize)) 
                                end
                                --if mouse is let go, drop object there.
                                if love.mouse.isDown(1)==false and self.cooldown==0.0 then
                                    self.cooldown=1.0
                                    self.dragNDrop=nil
                                end
                            end
                        end
                end
            end,
            drawEditor=function(self)
                love.graphics.setCanvas(self.canvas.editor)
                love.graphics.clear()

                self:drawTopMenu()
                love.graphics.setCanvas()
            end,
            drawTab=function(self, name, x, y)
                local font=love.graphics.getFont()
                local windowHt=self.topMenuSize
                local windowWidth=(love.graphics.getWidth()/self.editorScale.x)

                if self.editorState==name then
                    --draw the tab at the top.
                    self:drawWindow({x=x-2, y=y-2, w=font:getWidth(name)+4, h=font:getHeight()+3, background=self.windowColors.border})    
                end
                --change state if a new tab is clicked on.
                if self:mouseCollide({x=x, y=y, width=font:getWidth(name)+2, height=font:getHeight()+2}, true) and self.editorState~=name then
                    --love.graphics.setColor(238/255, 241/255, 65/255, 1)
                    if love.mouse.isDown(1) and self.cooldown==0.0 then
                        self.cooldown=1.0
                        self.editorState=name
                        self.topMenuHide=false
                    end
                end
                    --draw the little thing underneath.
                    love.graphics.print(name, x, y)
                    local x, y=14, font:getHeight()+2
                    local windowWidth=(love.graphics.getWidth()/self.editorScale.x)
                if self.topMenuHide==false then
                    self:drawWindow({x=-32, y=y, w=windowWidth+42, h=windowHt+8})
                        --draw slider up button
                         --centered on the bttom, just slightly about the height of the dropper window.
                        love.graphics.draw(self.guiImages.arrow, (windowWidth/2)-(self.guiImages.arrow:getWidth()/2), y+(windowHt-4))
                else
                    self:drawWindow({x=-32, y=y, w=windowWidth+42, h=16})
                    love.graphics.draw(self.guiImages.arrow, (windowWidth/2)-(self.guiImages.arrow:getWidth()/2), y+16, 0, 1, -1)
                end

                love.graphics.setColor(0.5, 0.5, 0.5, 1)
                local xspot=windowWidth-(font:getWidth("using:"))
                love.graphics.print("using: ", xspot-32, 0)
                local img=self.guiImages.objDrop
                if self.editState=="move" then img=self.guiImages.objMove end
                if self.editState=="delete" then img=self.guiImages.objDel end

                love.graphics.draw(img, xspot+15, 0)

                love.graphics.print("working layer: " .. self.activeLayer, xspot-32-(font:getWidth("working layer:         ")))
                love.graphics.setColor(1, 1, 1, 1)

            end,
            drawTopMenu=function(self)
                local font=love.graphics.getFont()
                love.graphics.setColor(0, 0, 0, 0.8)
                love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth()/self.editorScale.x, font:getHeight()+2)
                love.graphics.setColor(1, 1, 1, 1)
                
                --draw tabs.
                local tabs={"objs", "layers", "scene"}
                
                local x, y=2, 2
                for i,v in ipairs(tabs) do
                    self:drawTab(v, x, y)
                    x=x+font:getWidth(v)+6
                end
                if self.topMenuHide==false then
                    if self.editorState=="scene" then

                    elseif self.editorState=="layers" then
                        self:drawLayerMenu()
                    elseif self.editorState=="objs" then
                        self:drawObjectDropper()
                    end
                end                
            end,
            updateObjectMenu=function(self)
                local x,y=(love.graphics.getWidth()/self.editorScale.x)-52, 20
                    if love.mouse.isDown(1) and self.cooldown==0.0 and self:mouseCollide({x=x, y=y, width=48, height=48}, true)  then
                        self.cooldown=1.0
                        if self:mouseCollide({x=x, y=y, width=24, height=24}, true) then self.editState="drop" end
                        if self:mouseCollide({x=x+24, y=y, width=24, height=24}, true) then self.editState="delete" self.dropObject=nil end
                        if self:mouseCollide({x=x, y=y+24, width=24, height=24}, true) then self.editState="move" self.dropObject=nil end
                        if self:mouseCollide({x=x+24, y=y+24, width=24, height=24}, true) then self.useGrid=not self.useGrid end
                    end
            end,
            drawButton=function(self, image, x, y, lighten, tooltip)
                if lighten then love.graphics.setColor(1, 1, 1, 1) else love.graphics.setColor(0.5, 0.5, 0.5, 1) end
                love.graphics.draw(image, x, y)
                if self:mouseCollide({x=x, y=y, width=24, height=24}, true) then
                    local font=love.graphics.getFont()
                    local screenWidth=(love.graphics.getWidth()/self.editorScale.x)
                    local w, h=font:getWidth(tooltip), font:getHeight(tooltip)
                    local xpos=x-(w/2)
                    --this checks to see if the tooltip is too long for the screen, and if so, move it back some.
                    if (xpos+w+2)>screenWidth then xpos=(screenWidth-w)-5 end

                    love.graphics.setColor(0, 0, 0, 0.5)
                    love.graphics.rectangle("fill", xpos-2, (y-2)-h, w+4, h+4)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.print(tooltip, xpos, y-h)
                end
                love.graphics.setColor(1, 1, 1, 1)
            end,
            numberBox=function(self, name, x, y, data)
                local font=love.graphics.getFont()
                love.graphics.print(name ..": ", x, y)
                x=x+font:getWidth(name .. ": ")
                self:drawButton(self.guiImages.plus, x, y, (self:mouseCollide({x=x, y=y, width=16, height=16}, true)), "increase " .. name)
                x=x+self.guiImages.plus:getWidth()
                love.graphics.print(" " .. data, x, y)
                x=x+font:getWidth(" " .. data)
                self:drawButton(self.guiImages.minus, x, y, (self:mouseCollide({x=x, y=y, width=16, height=16}, true)), "decrease " .. name)
            end,
            drawLayerMenu=function(self)
                --parallax: x speed, yspeed  constant or relative
                local font=love.graphics.getFont()

                love.graphics.print("total layers: " .. #self.layers, ((love.graphics.getWidth()/self.editorScale.x)/2)-(font:getWidth("total layers:    ")/2), 20)                
                local x,y=8, 20
                self:numberBox("alpha", x, y, self.layers[self.activeLayer].alpha)

                x=8
                y=y+5
                local y=y+font:getHeight()
                self:numberBox("scroll speed", x, y, self.layers[self.activeLayer].speed)
 


                --draws an object menu for different tools, etc. Placing via grid (or not),
                --deleting or moving instead of placing object
                x,y=(love.graphics.getWidth()/self.editorScale.x)-72, 20
                self:drawButton(self.guiImages.newLayer, x, y, (self:mouseCollide({x=x, y=y, width=24, height=24}, true)), "newlayer")                                
                self:drawButton(self.guiImages.layerUp, x+24, y, (self:mouseCollide({x=x+24, y=y, width=24, height=24}, true)), "up a layer")
                self:drawButton(self.guiImages.layerDown, x+48, y, (self:mouseCollide({x=x+48, y=y, width=24, height=24,}, true)), "down a layer")
                y=y+24
                self:drawButton(self.guiImages.backgroundImage, x, y, (self:mouseCollide({x=x, y=y, width=24, height=24}, true)), "change background")                                
                self:drawButton(self.guiImages.tileLayer, x+24, y, (self.layers[self.activeLayer].tiled or self:mouseCollide({x=x+24, y=y, width=24, height=24}, true)), "tile background")
                self:drawButton(self.guiImages.moveLayer, x+48, y, (self.editorState=="move layer" or self:mouseCollide({x=x+48, y=y, width=24, height=24}, true)), "move layer")

                --self:drawButton(self.guiImages.gridButton, x+24, y+24, self.useGrid, "use grid")
            end,
            --this lists the object types and allows you to select them before dropping them on the map.
            drawObjectMenu=function(self)
                --draws an object menu for different tools, etc. Placing via grid (or not),
                --deleting or moving instead of placing object
                local x,y=(love.graphics.getWidth()/self.editorScale.x)-52, 20
                
                self:drawButton(self.guiImages.objDrop, x, y, (self.editState=="drop"), "place object")
                self:drawButton(self.guiImages.objDel, x+24, y, (self.editState=="delete"), "delete object")
                self:drawButton(self.guiImages.objMove, x, y+24, (self.editState=="move"), "move object")
                self:drawButton(self.guiImages.gridButton, x+24, y+24, self.useGrid, "use grid")
            end,
            drawObjectDropper=function(self)
                local windowHt=self.topMenuSize
                local windowWidth=(love.graphics.getWidth()/self.editorScale.x)
                local objDropWidth=windowWidth-(5*24)
                local objButtonSize=windowHt*0.7
                local font=love.graphics.getFont()
                local x, y=14, font:getHeight()+2
                local pgTotal=(math.floor(objDropWidth/objButtonSize)-self.editorScale.x)
                local pgEdge=math.floor((pgTotal+self.editorScale.x)*objButtonSize)+(objButtonSize/self.editorScale.x)

                local arrowY=14+(windowHt/2)
                if self.objPageAt>1 then
                                    --draw left and left arrow, if necassary.
                                    love.graphics.draw(self.guiImages.arrow, 12, arrowY, math.rad(-90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                                    if self:mouseCollide({x=0, y=arrowY, height=16, width=32}, true)  and self.cooldown==0.0 and love.mouse.isDown(1) then
                                        self.cooldown=1.0
                                        self.objPageAt=self.objPageAt-1
                                        if self.objPageAt<1 then self.objPageAt=1 end
                                    end
                end
                if (self.objPageAt+pgTotal)<#self.editorObject then
                                    local addup=objButtonSize+5
                                    if objDropWidth%objButtonSize==0 then addup=0 end
                                    local ax=pgEdge+addup
                                    --draw left and right arrow, if necassary.
                                    love.graphics.draw(self.guiImages.arrow, ax, arrowY, math.rad(90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                                    if self:mouseCollide({x=ax, y=32, height=arrowY, width=16}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                                        self.cooldown=1.0
                                        self.objPageAt=self.objPageAt+1
                                        if self.objPageAt>=(#self.editorObject-pgTotal) then self.objPageAt=(#self.editorObject-pgTotal) end
                                    end
                end

                local total=self.objPageAt+pgTotal
                --error(pgTotal)
                if total>=#self.editorObject then total=#self.editorObject end

                for i=self.objPageAt, total do
                    v=self.editorObject[i]
                    local obj=self.objectTypes[v]
                    --if object image is larger than window, scale to fit.
                    local scale=1
                    if obj.width>obj.height then scale=objButtonSize/obj.width else scale=objButtonSize/obj.height end
                    --if scale>1 then scale=math.floor(scale) end 

                    love.graphics.setColor(0.5, 0.5, 0.5, 1) 
                    --if mouse isn't over the object type, brighten it
                    if self:mouseCollide({x=x, y=y+7, width=(scale*obj.width), height=(scale*obj.height)}, true) then 
                        love.graphics.setColor(1, 1, 1, 1) 
                        if love.mouse.isDown(1) and self.cooldown==0.0 then
                            self.cooldown=1.0
                            if self.dropObject~=i then 
                                self.dropObject=i 
                                self.editState="drop"
                            end
                        end
                    end
                    if self.dropObject==i then love.graphics.setColor(1, 1, 1, 1) end
                    love.graphics.draw(obj.image, x, y+4, 0, scale, scale)
                
                    love.graphics.print(v, x+1, (windowHt-5))
                    x=x+windowHt-8
                end
                love.graphics.setColor(1, 1, 1, 1) 
                self:drawObjectMenu()
            end,
            updateEditor=function(self, dt)
                    self:mouseOverObject()
                    local mx, my=self:scaleMousePosition(true)

                    if self.cooldown>0.0 then self.cooldown=self.cooldown-0.1 else self.cooldown=0.0 end
                    if not self.fileSelect then
                                        --drop an object on the map
                                        if love.mouse.isDown(1) and self.cooldown==0.0 then
                                            if self.dropObject~=nil and self.editState=="drop" then
                                                local type=self.editorObject[self.dropObject]
                                                local obj=self.objectTypes[type]
                                                local windowH=self.topMenuSize+16
                                                if self.topMenuHide==true then windowH=16 end
                                                if my>(windowH+16) then
                                                    mx, my=self:scaleMousePosition(false)
                                                    self.cooldown=1.0
                                                    if self.useGrid then 
                                                        mx=self.gridSize*(math.floor(mx/self.gridSize)) 
                                                        my=self.gridSize*(math.floor(my/self.gridSize)) 
                                                    end
                                                    self:addObject({type=type, x=mx-(obj.width/2), y=my-(obj.height/2)})
                                                end
                                            end
                                        end

                                        --if top menu is not hidden, and the up arrow is pressed, hide it.
                                        if self.topMenuHide==false then
                                                local x,y=((love.graphics.getWidth()/self.editorScale.x)/2)-(self.guiImages.arrow:getWidth()/2), 16+(self.topMenuSize-8)
                                                if self:mouseCollide({x=x, y=y, width=self.guiImages.arrow:getWidth(), height=self.guiImages.arrow:getHeight()}, true) then
                                                    if love.mouse.isDown(1) and self.cooldown==0.0 then
                                                        self.cooldown=1.0
                                                        self.topMenuHide=true
                                                    end
                                                end
                                        else
                                            if self:mouseCollide({x=((love.graphics.getWidth()/self.editorScale.x)/2)-(self.guiImages.arrow:getWidth()/2), y=16, width=self.guiImages.arrow:getWidth(), height=self.guiImages.arrow:getHeight()}, true) then
                                                if love.mouse.isDown(1) and self.cooldown==0.0 then
                                                    self.cooldown=1.0
                                                    self.topMenuHide=false
                                                end
                                            end
                                        end
                                        if self.topMenuHide==false and self.editorState=="objs" then
                                            self:updateObjectMenu()
                                        end
                        else
                            --do file select menu update stuff. 
                        end
            end,
}