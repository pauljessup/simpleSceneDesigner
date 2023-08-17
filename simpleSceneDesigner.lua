local utf8 = require("utf8")

local folderOfThisFile = (...):match("(.-)[^%.]+$")
local function drawSort(a,b) return a.y+a.h < b.y+b.h end

--text buffer stuff and typing stuff. Snurched from the wiki
local textBuffer=""

function love.textinput(t)
    textBuffer = textBuffer .. t
end

function love.keypressed(key)
    if key == "backspace" then
        -- get the byte offset to the last UTF-8 character in the string.
        local byteoffset = utf8.offset(textBuffer, -1)

        if byteoffset then
            -- remove the last UTF-8 character.
            -- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
            textBuffer = string.sub(textBuffer, 1, byteoffset - 1)
        end
    end
end


return {
            editState="move camera",
            useGrid=false,
            activeLayer=1,
            objPageAt=1,
            editorState="scene",
            messageBox=false,
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
            topMenuSize=135,
            textEditing=false,
            zsort={},
            saveImages={},
            saveLookup={},
            cooldown=0.0, --so mousepresses don't repeat a ton.
            mousePressed=false, --for singular mouse presses, like placing new objects.
            --this allows us to search for background images, or to load scenes.
            --default is parent directory.
            directories={scenes="", layers="", editor="", sprites="", music=""},
           init=function(self, info)
                local dir=info.directories
                if dir~=nil then
                    if dir.scenes~=nil then self.directories.scenes=dir.scenes end
                    if dir.layers~=nil then self.directories.layers=dir.layers end
                    if dir.editor~=nil then self.directories.editor=dir.editor end
                    if dir.sprites~=nil then self.directories.sprites=dir.sprites end
                    if dir.music~=nil then self.directories.music=dir.music end
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
                                    checkYes=love.graphics.newImage(self.directories.editor .. "/checkyes.png"),
                                    checkNo=love.graphics.newImage(self.directories.editor .. "/checkno.png"),
                                    play=love.graphics.newImage(self.directories.editor .. "/play-button.png"),
                                    pause=love.graphics.newImage(self.directories.editor .. "/pause-button.png"),
                                    musicNote=love.graphics.newImage(self.directories.editor .. "/musicnote.png"),
                } 
                local t=(self.topMenuSize+30)*self.editorScale.y
                self.buttonQuad=love.graphics.newQuad(0, t, love.graphics.getWidth()-t, love.graphics.getHeight()-t, love.graphics.getWidth(), love.graphics.getHeight())

                --preload screenshots of saved scenes from save folder
                self:loadSaveImages()


                --preload scene images from scene folder.
                local files = love.filesystem.getDirectoryItems(self.directories.layers)
                self.sceneImages={}
                self.imageLookup={}
                for i,file in ipairs(files) do
                    if string.find(file, ".png") then
                        --make sure it's not a save file screenshot.
                        if self.saveLookup[file]==nil then
                            local id=#self.sceneImages+1
                            --the name is going to be the name of the scene file, so we strip .png for the name, but keep it for the image.
                            self.sceneImages[id]={name=file, image=love.graphics.newImage(self.directories.layers .. "/" .. file)}
                            self.imageLookup[file]=id
                        end
                    end
                end

                --preload scene music from scene folder.
                local files = love.filesystem.getDirectoryItems(self.directories.music)
                self.sceneMusic={}
                for i,file in ipairs(files) do
                    if string.find(file, ".mp3") or string.find(file, ".wav") or string.find(file, ".ogg") then
                        self.sceneMusic[#self.sceneMusic+1]={name=file, music=love.audio.newSource(self.directories.music .. "/" .. file, "stream")}
                    end
                end
                self.canvas=love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())

                self.customFunc={}
                if info.functions~=nil then
                    info=info.functions 
                    if info.startGame~=nil then info.startGame(self) end
                    if info.init~=nil then self.customFunc.init=info.init end
                    if info.draw~=nil then self.customFunc.draw=info.draw end
                    if info.update~=nil then self.customFunc.update=info.update end
                    --layer functions, with similar update/etc. called per layer.
                    if info.layers~=nil then self.customFunc.layers=info.layers end
                end
                simpleScene:newScene({name="", x=0, y=0})
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
            newScene=function(self, vars, loading)
                self:clean()
                self.name=vars.name
                if vars.x==nil then vars.x=0 end
                if vars.y==nil then vars.y=0 end

                self.x=vars.x
                self.y=vars.y

                if vars.gridSize~=nil then self.gridSize=vars.gridSize else self.gridSize=8 end
                if vars.scale~=nil then self.scale=vars.scale else self.scale={x=1, y=1} end

                self.music=vars.music
                if vars.activeLayer~=nil then self.activeLayer=vars.activeLayer else vars.activeLayer=1 end
                --first blank layer--
                if not loading then simpleScene:addLayer({x=0, y=0}) end
            end,
            clean=function(self)
                self.useGrid=false
                self.activeLayer=1
                self.scale={x=1, y=1}
                for i=#self.layers, -1 do self.layers[i]=nil end self.layers={}
                for i=#self.objects, -1 do self.objects[i]=nil end self.objects={}
            end,
            load=function(self, name)
                --this needs to change, a lot. For loading layers, for loading objects, for loading scenes/etc
                --also, need to add a selection window that runs through the screenshots in save folder,
                --and uses that to list the loadable scenes you can click on. When clicked on, it loads the binser file.
                local data, len=self.binser.readFile(self.path .. "/" .. self.directories.scenes .. "/" .. name)
                data=data[1]
                --this needs to be done differently for layers because of images
                self:newScene(data.scene, true)
                --self.objects=data.objects
                for i,v in ipairs(data.objects) do
                    self:addObject(v)
                end
                for i,v in ipairs(data.layers) do
                    self:addLayer(v)
                end
            end,
            save=function(self)
                local saveLayerdata={}
                for i,v in ipairs(self.layers) do
                    local image=""
                    if self.sceneImages[v.image]~=nil then image=self.sceneImages[v.image].name end
                    saveLayerdata[i]={
                                    x=v.x,
                                    y=v.y,
                                    scale=v.scale,
                                    alpha=v.alpha,
                                    tiled=v.tiled, 
                                    image=image,
                                    scroll=v.scroll, 
                                    visible=v.visible,
                                    reverse=v.reverse }
                end
                local objects={}
                for i,v in ipairs(self.objects) do
                    objects[i]={
                                    x=v.x,
                                    y=v.y,
                                    layer=v.layer,
                                    type=v.type,
                                    width=v.width,
                                    height=v.height,
                                    id=v.id,
                                    scene=v.scene,
                    }
                end
                local saveData={
                    scene={activeLayer=self.activeLayer, x=self.x, y=self.y, music=self.music, name=self.name, scale=self.scale},
                    layers=saveLayerdata, objects=objects,
                }
                
                self.binser.writeFile(self.path .. "/" .. self.directories.scenes .. "/" .. self.name .. ".scene", saveData)
            end,
            setBackgroundImage=function(self, layer, imageID)
                local img=self.sceneImages[imageID] 
                self.layers[layer].imageName=img.file
                self.layers[layer].image=imageID
                self.layers[layer].canvas=love.graphics.newCanvas(img.image:getWidth(), img.image:getHeight())
                self:moveLayer(layer, 0, 0)
            end,
            --add check here to see if x/y/w/h is obscured by layer over top of it.
            --if so, returns true, and layer id
            --if not, just returns false.
            addLayer=function(self, data, layer)
                if data.scroll==nil then
                    data.scroll={}
                    data.scroll.speed=1.0
                    data.scroll.constant={}
                    data.scroll.constant.x=false
                    data.scroll.constant.y=false
                end
                if data.scale==nil then data.scale=1 end
                if data.reverse==nil then data.reverse=false end 

                if data.alpha==nil then data.alpha=1.0 end 
                if data.x==nil then data.x=0 end
                if data.y==nil then data.y=0 end
                if data.visible==nil then data.visible=true end

                data.canvas=love.graphics.newCanvas(love.graphics.getWidth(), love.graphics.getHeight())
                if layer==nil then 
                    data.id=#self.layers+1
                    self.layers[data.id]=data
                else
                    data.id=layer+1
                    table.insert(self.layers, data.id, data)
                end
                if data.image and self.imageLookup[data.image]~=nil then
                    self:setBackgroundImage(data.id, self.imageLookup[data.image])
                end
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
                
                self.zsort[#self.zsort+1]={id=data.id, x=data.x, y=data.y, w=data.width, h=data.height}

                --if an init function is set in the object's template, use it.
                if self.objectTypes[data.type].init then  self.objectTypes[data.type]:init(self.objects[data.id], self) end
            end,
            changeObjectLayer=function(self, object, newLayer)
                if self.layers[newLayer]==nil then error("Tried to move object to layer #" .. newLayer ..",  but layer does not exist.") end
                --if an ID is passed and not the actual object, get the actual object.
                if type(object)=="number" then object=self.objects[object] end
                --we convert old coords on old layer to screen coords
                local x, y=self:layertoScreen(object.x, object.y, object.layer)
                --now we convert the screen coords to the new layer coords
                object.x, object.y=self:screenToLayer(x, y, newLayer)
                object.layer=newlayer
            end,
            deleteLayer=function(self, layer)
                table.remove(self.layers, layer)
                if layer==self.activeLayer then self.activeLayer=self.activeLayer-1 end
                --delete all objects on layer.
                for i,v in ipairs(self.objects) do
                    if v.layer==layer then self:deleteObject(i) end
                end
            end,
            deleteObject=function(self, objid)
                table.remove(self.objects, objid)
            end,
            update=function(self, dt)
                if not self.textEditing then textBuffer="" end

                if self.editing==true then
                    self:updateEditor(dt)
                end

                for i=1, #self.layers do
                    self:updateLayer(i, dt)
                    if self.customFunc.layers~=nil and self.customFunc.layers.update~=nil then self.customFunc.layers.update(self, self.layers[i], dt) end
                end

                for ob, object in ipairs(self.objects) do 
                    local type=self.objectTypes[object.type]
                    if type.update~=nil and self.editing==false then type:update(object, self, dt) end                    
                end
                --zsorting...
                for i,v in ipairs(self.zsort) do
                    local data=self.objects[v.id]
                    self.zsort[i]={id=v.id, x=data.x, y=data.y, w=data.width, h=data.height}
                end

                --run custom functions.
                if self.customFunc.update~=nil then self.customFunc.update(self, dt) end

                table.sort(self.zsort, drawSort)
            end,
            updateLayer=function(self, layer, dt)
                local id=layer
                layer=self.layers[layer]
                local move={x=0, y=0}
                if layer.scroll.constant.x==true then
                    move.x=layer.scroll.speed
                end
                if layer.scroll.constant.y==true then
                    move.y=layer.scroll.speed
                end
                self:moveLayer(id, move.x, move.y)
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
            drawObjects=function(self, layer)
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
                                    if self:mouseCollide(object) and object.layer==self.activeLayer  then
                                        didlight=true 
                                        litId=i
                                    end
                                end
                            end
                    end
                end

                for i,v in ipairs(self.zsort) do
                    local object=self.objects[v.id]
                    if object.layer==layer then
                            local type=self.objectTypes[object.type]
                            if didlight and litId==i and self.editing==true then
                                    love.graphics.setColor(0.5, 0.5, 0.5, 1)
                            end
                            if type.draw~=nil then
                                    type:draw(object, self) 
                            elseif type.image~=nil then
                                love.graphics.draw(type.image, object.x, object.y)
                            end
                            if didlight and litId==i and self.editing==true then
                                love.graphics.setColor(1, 1, 1, 1)
                            end
                    end
                end
            end,
            drawLayer=function(self, layer)
                local c={}
                c[1], c[2], c[3], c[4]=love.graphics.getColor()
                local a=c[4]
                --if it's passing the layer number...
                if type(layer)~="table" then layer=self.layers[layer] end
                if layer.visible then
                        love.graphics.setCanvas(layer.canvas)
                        love.graphics.clear()


                        if layer.image~=nil and self.sceneImages[layer.image]~=nil  then
                            if self.customFunc.layers~=nil and self.customFunc.layers.draw~=nil then 
                                self.customFunc.layers.draw(self, layer, 0, 0) 
                            else
                                love.graphics.draw(self.sceneImages[layer.image].image, 0, 0)
                            end
                        end
                        --draw the grid if in editor and grid is set.
                        if self.editing then
                            if layer.id==self.activeLayer then
                                if self.useGrid==true  then
                                    love.graphics.setColor(1, 1, 1, 0.12)
                                    for x=0, layer.canvas:getWidth(), self.gridSize do
                                        love.graphics.line(x, 0, x, layer.canvas:getHeight())
                                    end
                                    for y=0, layer.canvas:getHeight(), self.gridSize do
                                        love.graphics.line(0, y, layer.canvas:getWidth(), y)
                                    end
                                    love.graphics.setColor(1, 1, 1, 1)
                                end
                                self:mouseDrop()
                            end
                        end
                        self:drawObjects(layer.id) 
                        love.graphics.setCanvas()

                        love.graphics.setColor(c[1], c[2], c[3], layer.alpha)
                        if layer.tiled==true and layer.image~=nil then
                                layer.canvas:setWrap("repeat", "repeat")
                                local quad = love.graphics.newQuad(-layer.x*(self.scale.x*layer.scale), -layer.y*(self.scale.y*layer.scale), love.graphics.getWidth(), love.graphics.getHeight(), self.sceneImages[layer.image].image:getWidth(), self.sceneImages[layer.image].image:getHeight())	
                                love.graphics.draw(layer.canvas, quad, 0, 0, 0, (self.scale.x*layer.scale), (self.scale.y*layer.scale))
                        else
                            local x, y=(layer.scroll.speed*layer.scale)*self.x, (layer.scroll.speed*layer.scale)*self.y
                            love.graphics.draw(layer.canvas, (x*-1)+(layer.x*(self.scale.x*layer.scale)), (y*-1)+(layer.y*(self.scale.y*layer.scale)), 0, self.scale.x*layer.scale, self.scale.y*layer.scale)
                        end
                        love.graphics.setColor(c[1], c[2], c[3], c[4])
                end
            end,
            --precise placement.
            placeCamera=function(self, x, y)
                --this makes sure when it's placed that the sublayers are moved correctly
                --by finding the diference between current location and new location.
                self:moveCamera(x-self.x, y-self.y)
            end,
            --relative movement.
            moveCamera=function(self, x, y)
                if self.cooldown==0.0 then
                    self.x=math.floor(self.x+x)
                    self.y=math.floor(self.y+y)
                end
            end,
            
            cameraClampLayer=function(self, layer)
                local layer=self.layers[layer]
                local scale=(layer.scale*self.scale.x)
                local screen={x=(love.graphics.getWidth()/scale), y=(love.graphics.getHeight()/scale)}
                local edges={x=layer.x*scale, y=(layer.y-scale)*scale, w=screen.x-(layer.canvas:getWidth()/scale), h=screen.y-(layer.canvas:getHeight()/scale)}

                if self.x<edges.x then self.x=edges.x end
                if self.y<edges.y then self.y=edges.y end
                if self.x>edges.x+edges.w then self.x=edges.x+edges.w end
                if self.y>edges.y+edges.h then self.y=edges.y+edges.h end
            end,
            cameraFollowObject=function(self, obj)
                if type(obj)=="number" then obj=self.objects[obj] end
                local layer=self.layers[obj.layer]
                local center={x=(love.graphics.getWidth()/(self.scale.x*layer.scale))/2, y=(love.graphics.getHeight()/(self.scale.y*layer.scale))/2}

                simpleScene:placeCamera((((obj.x+(obj.width/2))-center.x)+layer.x)*(self.scale.x*layer.scale), (((obj.y+obj.height/2)-center.y)+layer.y)*(self.scale.y*layer.scale))
            end,
            sceneToScreen=function(self, x, y)
                x=x+self.x
                y=y+self.y
                x=x*self.scale.x
                y=y*self.scale.y
                return x, y
            end,
            screenToScene=function(self, x, y)
                x=x/self.scale.x
                y=y/self.scale.y
                x=x-self.x
                y=y-self.y
                return x, y
            end,
            screenToLayer=function(self, layer, x, y)
                local l=self.layers[layer]
                local scale=self.scale.x*l.scale
                x=x-l.x 
                y=y-l.y 
                x=x/scale 
                y=y/scale

                return x, y     
            end,
            --returns a rect of the portion of the layer on screen
            --this can be used to speed up bulk on screen object detection, too
            layerOnscreen=function(self, layer)
                if self.layers[layer]~=nil then layer=self.layers[layer] else return nil end
                local ox, oy=(layer.scroll.speed*layer.scale)*self.x, (layer.scroll.speed*layer.scale)*self.y --offset x and y
                --get scaled edges
                local x, y=(ox*-1)+((layer.x)*(self.scale.x*layer.scale)), (oy*-1)+((layer.y)*(self.scale.y*layer.scale))
                local w, h=x+(layer.canvas:getWidth()*(self.scale.x*layer.scale)), y+(layer.canvas:getHeight()*(self.scale.y*layer.scale))
                local screen={w=love.graphics.getWidth(), h=love.graphics.getHeight()}
                --now subtract the screen edge from the layer edge position
                if w>screen.w then w=w-screen.w end 
                if h>screen.h then h=h-screen.h end 
                if x<0 then x=x*-1 end 
                if y<0 then y=y*-1 end 
                return {x=x, y=y, w=w, h=h}
            end,
            --this gets a list of object id for every object visible on the screen.
            --good for things like speeding up collision detection & layer drawing.
            allObjectsOnScreen=function(self, layer)
                local objs={}
                local screen=self:layerOnscreen(layer)
                if layer~=nil and self.layers[layer]~=nil then
                    layer=self.layers[layer]
                end
                for i,v in ipairs(self.objects) do
                    if self:objectOnScreen(v, screen) and (layer==nil or v.layer==layer) then objs[i]=true else objs[i]=false end
                end
                return objs                
            end,
            objectOnScreen=function(self, obj, screen)
                if screen==nil then 
                    local x, y=self:layertoScreen(obj.layer, obj.x, obj.y)
                    local layer=self.layers[obj.layer]
                    if x>-(100*layer.scale*self.scale.x) and y>-(100*layer.scale*self.scale.y) and x+(obj.width*(layer.scale*self.scale.x))<(love.graphics.getWidth()+(100*layer.scale*self.scale.x)) and y+(obj.height*(layer.scale*self.scale.y))<(love.graphics.getHeight()+(100*layer.scale*self.scale.x)) then return true end                    
                else
                    if obj.x>screen.x and obj.y>screen.y and (obj.x+obj.width)<screen.w and(obj.y+obj.height)<screen.h then return true end
                end
                return false
            end,
            layertoScreen=function(self, layer, x, y)
                if self.layers[layer]~=nil then layer=self.layers[layer] end
                local ox, oy=(layer.scroll.speed*layer.scale)*self.x, (layer.scroll.speed*layer.scale)*self.y
                x=(ox*-1)+(x*(self.scale.x*layer.scale))+(layer.x)*(self.scale.x*layer.scale)
                y=(oy*-1)+(y*(self.scale.x*layer.scale))+(layer.y)*(self.scale.y*layer.scale)
                return x, y
            end,
            --amount to move.
            moveObject=function(self, obj, x, y)
                local layer=self.layers[obj.layer]
                local tx=obj.x+x 
                local ty=obj.y+y

                obj.moveX=nil 
                obj.moveY=nil
                if tx>0 and tx+obj.width<layer.canvas:getWidth() then 
                    obj.moveX=x
                    obj.x=tx 
                end
                if ty>0 and ty+obj.height<layer.canvas:getHeight() then 
                    obj.moveY=y
                    obj.y=ty
                end
            end,
            moveLayer=function(self, layer, x, y)
                local layer=self.layers[layer]
                local move={x=layer.scroll.speed*x, y=layer.scroll.speed*y}
                if layer.reverse then 
                    move.x=move.x*-1
                    move.y=move.y*-1
                end
 
                layer.x=layer.x+(move.x)
                layer.y=layer.y+(move.y)
            end,
            --loop plays the music set for this scene.
            playMusic=function(self)
                self:stopAllMusic()
                if self.music~=nil and self.music.music~=nil and self.sceneMusic[self.music.music]~=nil then
                    self.sceneMusic[self.music.music].music:setLooping(true)
                    self.sceneMusic[self.music.music].music:play()
                    self.playing=true
                end
            end,
            draw=function(self, x, y)
                if x==nil then x=self.x end
                if y==nil then y=self.y end


                for il,layer in ipairs(self.layers) do 
                        self:drawLayer(layer)
                end

                if self.editing==true then 
                    self:drawEditor() 
                    love.graphics.draw(self.canvas, 0, 0, 0, self.editorScale.x, self.editorScale.y)
                end
                if self.customFunc.draw~=nil then self.customFunc.draw(self) end
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
            
------------------------------------------------------------------------EDITOR FUNCTIONALITY----------------------------------------------------
            startEditing=function(self) self.editing=true end,
            endEditing=function(self) self.editing=false end,

            scaleMousePosition=function(self, editor)
                local l=self.layers[self.activeLayer]
                local scale={x=(self.scale.x*l.scale), y=(self.scale.y*l.scale)}
                local mx, my = love.mouse.getPosition()
                if editor then 
                    scale.x=self.editorScale.x scale.y=self.editorScale.y  
                else
                    mx=mx+self.x 
                    my=my+self.y
                end
                mx=math.floor(mx/scale.x)
                my=math.floor(my/scale.y)
                return mx, my
            end,
            loadSaveImages=function(self)
                --clear them out--
                for i=#self.saveImages, -1 do self.images[i]=nil end
                for i=#self.saveLookup, -1 do self.images[i]=nil end
                self.saveImages={}
                self.saveLookup={}

                files = love.filesystem.getDirectoryItems(self.directories.scenes)
                for i,file in ipairs(files) do
                    if string.find(file, ".scene") then
                        local id=#self.saveImages+1
                        file=file:match("(.+)%..+$")
                        local img=love.graphics.newImage(self.directories.editor .. "/emptyImage.png")
                        if love.filesystem.getInfo(file .. ".png") then
                            img=love.graphics.newImage(file .. ".png")
                        end
                        self.saveImages[id]={name=file, image=img}
                        self.saveLookup[file .. ".png"]=id
                    end      
                end
            end,
            updateSmallMsgBox=function(self)
                local font=love.graphics.getFont()
                local w, h=((love.graphics.getWidth()/self.editorScale.x)*0.5), ((love.graphics.getHeight()/self.editorScale.y)*0.2)
                local x, y=((love.graphics.getWidth()/self.editorScale.x)/2)-w/2, ((love.graphics.getHeight()/self.editorScale.y)/2)-h/2
                local textbox={x=x+20, y=(y+(font:getHeight()*2)-4)}

                if self.editorState=="save scene" then
                        if self:updateTextButton("okay", x+(w/2)-((font:getWidth("okay")/2)+8), y+32) then 
                            self.cooldown=1.0
                            self.smallMessageBox=false
                            self.editorState=self.oldState
                            self.oldState=nil
                        end
                end
                if self.editorState=="rename" then
                    if self:updateTextButton("okay", textbox.x+10+font:getWidth("AAAAAAAAAAAAAAA"), textbox.y+2) then
                        self.cooldown=1.0
                        self.textEditing=false
                        self.smallMessageBox=false
                        self.editorState=self.oldState
                        self.oldState=nil
                    end
                end
                if self.editorState=="new scene" then
                    if self:updateTextButton("okay", textbox.x+10+font:getWidth("AAAAAAAAAAAAAAA"), textbox.y+2) then
                        self:newScene({name=textBuffer})
                        self.cooldown=1.0
                        self.textEditing=false
                        self.smallMessageBox=false
                        self.editorState=self.oldState
                        self.oldState=nil
                    end
                end
            end,
            
            inputTextBox=function(self, prompt, x, y, w, h)
                if self.blinkCursor==nil then self.blinkCursor={show=true, time=2.0} end
                if self.blinkCursor.time>0.0 then self.blinkCursor.time=self.blinkCursor.time-0.1 else self.blinkCursor.time=2.0 self.blinkCursor.show=not self.blinkCursor.show end 

                local font=love.graphics.getFont()
                local textbox={x=x+20, y=(y+(font:getHeight()*2)-4)}
                love.graphics.print(prompt, x+(w/2)-(font:getWidth(prompt)/2), y+5)
                self.textEditing=true
                --textbox. 
                local oldColor={}
                oldColor[1], oldColor[2], oldColor[3], oldColor[4]=love.graphics.getColor()
                local b, o=self.windowColors.background, self.windowColors.border

                love.graphics.setColor(b[1], b[2], b[3], 1)
                love.graphics.rectangle("fill", textbox.x, textbox.y, font:getWidth("AAAAAAAAAAAAAAA"), font:getHeight()+8)
                love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
                local cursor="|"
                if not self.blinkCursor.show then cursor="" end 

                love.graphics.print(textBuffer .. cursor, textbox.x+5, textbox.y+4)
                --add okay button here.
                self:drawTextButton("okay", textbox.x+10+font:getWidth("AAAAAAAAAAAAAAA"), textbox.y+2)

                --if pressed, leave textbox.
                return textBuffer
            end,
            drawSmallMsgBox=function(self)
                love.graphics.setColor(0, 0, 0, 0.8)
                love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
                love.graphics.setColor(1, 1, 1, 1)
                local w, h=((love.graphics.getWidth()/self.editorScale.x)*0.5), ((love.graphics.getHeight()/self.editorScale.y)*0.2)
                local x, y=((love.graphics.getWidth()/self.editorScale.x)/2)-w/2, ((love.graphics.getHeight()/self.editorScale.y)/2)-h/2
                self:drawWindow({x=x, y=y, w=w, h=h})
                if self.editorState=="rename" then
                    self.name=self:inputTextBox("-type new name for scene-", x, y, w, h)
                end
                if self.editorState=="new scene" then
                    self:inputTextBox("-type name for new scene-", x, y, w, h)
                end
                if self.editorState=="save scene" then
                    local font=love.graphics.getFont()
                    love.graphics.print("saved to " .. self.name .. ".scene ", x+(w/2)-(font:getWidth("saved to " .. self.name .. ".sceme ")/2), y+13)
                    --okay button.
                    self:drawTextButton("okay", x+(w/2)-((font:getWidth("okay")/2)+8), y+32)
                end
            end,
            updateMsgBox=function(self)
                local w, h=((love.graphics.getWidth()/self.editorScale.x)*0.8), ((love.graphics.getHeight()/self.editorScale.y)*0.8)
                local x, y=((love.graphics.getWidth()/self.editorScale.x)/2)-w/2, ((love.graphics.getHeight()/self.editorScale.y)/2)-h/2
                if self.editorState=="select save" then
                    self:updateSaveSelect({x=x, y=y, w=w, h=h})
                end
                if self.editorState=="select image" then
                    self:updateImageSelect({x=x, y=y, w=w, h=h})
                end
                if self.editorState=="select music" then
                    self:updateMusicSelect({x=x, y=y, w=w, h=h})
                end
            end,
            drawMsgBox=function(self)
                love.graphics.setColor(0, 0, 0, 0.8)
                love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())
                love.graphics.setColor(1, 1, 1, 1)
                local w, h=((love.graphics.getWidth()/self.editorScale.x)*0.8), ((love.graphics.getHeight()/self.editorScale.y)*0.8)
                local x, y=((love.graphics.getWidth()/self.editorScale.x)/2)-w/2, ((love.graphics.getHeight()/self.editorScale.y)/2)-h/2
                self:drawWindow({x=x, y=y, w=w, h=h})
                if self.editorState=="select image" then
                    self:drawImageSelect({x=x, y=y, w=w, h=h})
                end
                if self.editorState=="select save" then
                    self:drawSaveSelect({x=x, y=y, w=w, h=h})
                end
                if self.editorState=="select music" then
                    self:drawMusicSelect({x=x, y=y, w=w, h=h})
                end
                return {x=x, y=y, w=w, h=h}
            end,
            stopAllMusic=function(self)
                for i,v in ipairs(self.sceneMusic) do
                    v.music:stop()
                end
                self.playing=false
            end,
            updateMusicSelect=function(self, window)
                if self.selectMusicPage==nil then self.selectMusicPage=1 end
                local font=love.graphics.getFont()
                local cx, cy=window.x+((window.w/2)-((font:getWidth("CANCEL")+4)/2)), window.y+(window.h-(font:getHeight()+10))
                if self:updateTextButton("CANCEL", cx, cy) then 
                    self.cooldown=1.0
                    self.messageBox=false
                    self.editorState=self.oldState
                    self.oldState=nil
                    self.selectMusicPage=1
                    self:stopAllMusic()
                end
                local listHt=font:getHeight()+(cy-32)
                local listTotal=math.floor(listHt/(font:getHeight()+19))

                --list music here, with play button next to it so you can preview it.
                --add up and down arrows
                local pgTotal=self.selectMusicPage+listTotal 
                if pgTotal>#self.sceneMusic then pgTotal=#self.sceneMusic end

                local y=window.y+13
                
                --y=y+13
                y=y+20
                --add up and down arrows for pagination.
                if self:mouseCollide({x=window.x+((window.w/2)-(self.guiImages.arrow:getWidth()/2)), y=y, width=self.guiImages.arrow:getWidth(), height=self.guiImages.arrow:getHeight()}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                    self.cooldown=1.0
                    self.selectMusicPage=self.selectMusicPage-1
                    if self.selectMusicPage<1 then self.selectMusicPage=1 end
                end
                if self:mouseCollide({x=window.x+((window.w/2)-(self.guiImages.arrow:getWidth()/2)), y=window.y+(window.h-(font:getHeight()+30)), width=self.guiImages.arrow:getWidth(), height=self.guiImages.arrow:getHeight()}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                    self.cooldown=1.0
                    self.selectMusicPage=self.selectMusicPage+1
                    if self.selectMusicPage>#self.sceneMusic then self.selectMusicPage=#self.sceneMusic end
                end
                local i=1
                for offset=self.selectMusicPage, pgTotal do
                    love.graphics.setColor(0.5, 0.5, 0.5, 1)
                    local fname=self.sceneMusic[offset].name
                    if font:getWidth(fname)>(window.w*0.75) then 
                        local t=math.floor((window.w*0.75)/font:getWidth("A"))
                        fname=fname:sub(1, t)
                        fname=fname .. "..."
                    end
                    if self:mouseCollide({x=window.x+13, y=y+(i*(font:getHeight()+6)), width=font:getWidth(fname), height=font:getHeight()+5}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then 
                        --selects the song.
                        self:stopAllMusic()
                        self.cooldown=1.0
                        self.messageBox=false
                        self.editorState=self.oldState
                        self.oldState=nil
                        self.songSelected=nil
                        self.music={name=self.sceneMusic[offset].name, music=offset}
                        self.selectMusicPage=1
                    end
                    local x, y2=window.x+23+(font:getWidth(fname)), y+(i*(font:getHeight()+6))
                    if self.songSelected==offset then
                        if (self:mouseCollide({x=x, y=y2, width=24, height=24}, true)) and self.cooldown==0.0 and love.mouse.isDown(1) then
                            self.cooldown=1.0
                            self:stopAllMusic()
                            self.songSelected=nil 
                        end
                    else
                        if (self:mouseCollide({x=x, y=y2, width=24, height=24}, true)) and self.cooldown==0.0 and love.mouse.isDown(1) then
                            self.cooldown=1.0
                            self:stopAllMusic()
                            self.songSelected=offset
                            self.sceneMusic[offset].music:setLooping(true)
                            self.sceneMusic[offset].music:play()
                        end
                    end
                    i=i+1
                end

            end,
            drawMusicSelect=function(self, window)
                local title="-select scene music-"                
                if self.selectMusicPage==nil then self.selectMusicPage=1 end

                local font=love.graphics.getFont()
                local cx, cy=window.x+((window.w/2)-((font:getWidth("CANCEL")+4)/2)), window.y+(window.h-(font:getHeight()+13))                
                self:drawTextButton("CANCEL", cx, cy)
                local listHt=font:getHeight()+(cy-32)
                local listTotal=math.floor(listHt/(font:getHeight()+19))

                --list music here, with play button next to it so you can preview it.
                --add up and down arrows
                local pgTotal=self.selectMusicPage+listTotal 
                if pgTotal>#self.sceneMusic then pgTotal=#self.sceneMusic end

                local y=window.y+13
                love.graphics.print(title, window.x+((window.w/2)-(font:getWidth(title)/2)), y)

                y=y+20
                if self.selectMusicPage>1 then love.graphics.draw(self.guiImages.arrow, window.x+((window.w/2)-(self.guiImages.arrow:getWidth()/2)), y) end
                if self.selectMusicPage<#self.sceneMusic then love.graphics.draw(self.guiImages.arrow, window.x+((window.w/2)-(self.guiImages.arrow:getWidth()/2)), window.y+(window.h-(font:getHeight()+20)), 0, 1, -1) end

                local yoffset=1
                for i=self.selectMusicPage, pgTotal do
                    love.graphics.setColor(0.5, 0.5, 0.5, 1)
                    local fname=self.sceneMusic[i].name
                    if font:getWidth(fname)>(window.w*0.75) then 
                        local t=math.floor((window.w*0.75)/font:getWidth("A"))
                        fname=fname:sub(1, t)
                        fname=fname .. "..."
                    end
                    if self:mouseCollide({x=window.x+13, y=y+(yoffset*(font:getHeight()+6)), width=font:getWidth(fname), height=font:getHeight()+5}, true) then love.graphics.setColor(1, 1, 1, 1) end
                    love.graphics.print(fname, window.x+13, y+(yoffset*(font:getHeight()+6)))
                    local x, y2=window.x+23+(font:getWidth(fname)), y+(yoffset*(font:getHeight()+6))
                    if self.songSelected==i then
                        self:drawButton(self.guiImages.pause, x, y2, (self:mouseCollide({x=x, y=y2, width=24, height=24}, true)), "play background music")
                    else
                        self:drawButton(self.guiImages.play, x, y2, (self:mouseCollide({x=x, y=y2, width=24, height=24}, true)), "play background music")
                    end
                    yoffset=yoffset+1
                end
                
            end,

            updateSaveSelect=function(self, window)
                if self.selectPage==nil then self.selectPage=1 end
                local endPage=self.selectPage+5
                if endPage>#self.saveImages then endPage=#self.saveImages end
            
                local font=love.graphics.getFont()
                local cx, cy=window.x+((window.w/2)-((font:getWidth("CANCEL")+4)/2)), window.y+(window.h-(font:getHeight()+10))
                local button={w=(window.w+15)/4, h=(window.h+15)/4}
                local ox=x

                
                if self:updateTextButton("CANCEL", cx, cy) then 
                    self.cooldown=1.0
                    self.messageBox=false
                    self.editorState=self.oldState
                    self.oldState=nil
                    self.selectPage=1
                end
            
            
                --left arrow
                if self.selectPage>1 then
                    love.graphics.draw(self.guiImages.arrow, window.x+10, window.y+(window.h/2), math.rad(-90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                    if self:mouseCollide({x=window.x+10, y=window.y+(window.h/2)-8, height=32, width=32}, true)  and self.cooldown==0.0 and love.mouse.isDown(1) then
                        self.cooldown=1.0
                        self.selectPage=self.selectPage-6
                        if self.selectPage<1 then self.selectPage=1 end
                    end
                end
                --right arrow
                if self.selectPage<(#self.saveImages-6) then
                    love.graphics.draw(self.guiImages.arrow, window.x+(window.w-12), window.y+(window.h/2), math.rad(90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                    if self:mouseCollide({x=window.x+(window.w-12), y=window.y+(window.h/2)-8, height=32, width=32}, true)  and self.cooldown==0.0 and love.mouse.isDown(1) then
                        self.cooldown=1.0
                        self.selectPage=self.selectPage+6
                    end
                end
            
            end,
            
            drawSaveSelect=function(self, window)
                local font=love.graphics.getFont()
                local title="-select scene-"
                local button={w=(window.w+15)/4, h=(window.h+15)/4}
                local y,x=window.y+font:getHeight(), (window.x+((window.w/2)-((button.w*3)/2)))-10
                local ox=x
                
                love.graphics.print(title, window.x+((window.w/2)-(font:getWidth(title)/2)), y)
            
                y=y+(font:getHeight()*2)
            
                if self.selectPage==nil then self.selectPage=1 end
                local endPage=self.selectPage+5
                
            
                if endPage>#self.saveImages then endPage=#self.saveImages end
            
                local cx, cy=window.x+((window.w/2)-((font:getWidth("CANCEL")+4)/2)), window.y+(window.h-(font:getHeight()+10))                
                self:drawTextButton("CANCEL", cx, cy)
                
                
                if self.selectPage>1 then
                    love.graphics.draw(self.guiImages.arrow, window.x+10, window.y+(window.h/2), math.rad(-90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                end
                --right arrow
                if self.selectPage<(#self.saveImages-6) then
                    love.graphics.draw(self.guiImages.arrow, window.x+(window.w-12), window.y+(window.h/2), math.rad(90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                end
            
                for i=self.selectPage, endPage do
                    local file=self.saveImages[i]
                    local scale={x=button.w/file.image:getWidth(), y=button.h/(file.image:getHeight()-(self.topMenuSize*self.editorScale.y))}
                    local col=0.5
                    
                    if self:mouseCollide({x=x, y=y, width=button.w, height=button.h}, true) then 
                        col=1 
                        if love.mouse.isDown(1) and self.cooldown==0.0 then
                            self.cooldown=1.0
                            self:load(file.name .. ".scene")
                            self.messageBox=false
                            self.editorState=self.oldState
                            self.oldState=nil
                            self.selectPage=nil
                        end
                    end
                    love.graphics.setColor(col, col, col, 1)
            
                    love.graphics.draw(file.image, self.buttonQuad, x+8, y, 0, scale.x, scale.y)
                    love.graphics.print(file.name, x+((button.w/2)-(font:getWidth(file.name)/2)), y+button.h)
                    x=x+button.w+5
                    if i%3==0 then y=y+button.h+20 x=ox end
                end
            
                love.graphics.setColor(1, 1, 1, 1)
            
            end,
            
            
            updateImageSelect=function(self, window)
                if self.selectPage==nil then self.selectPage=1 end
                local endPage=self.selectPage+5
                if endPage>#self.sceneImages then endPage=#self.sceneImages end

                local font=love.graphics.getFont()
                local cx, cy=window.x+((window.w/2)-((font:getWidth("CANCEL")+4)/2)), window.y+(window.h-(font:getHeight()+10))
                
                if self:updateTextButton("CANCEL", cx, cy) then 
                    self.cooldown=1.0
                    self.messageBox=false
                    self.editorState=self.oldState
                    self.oldState=nil
                    self.selectPage=1
                end


                --left arrow
                if self.selectPage>1 then
                    love.graphics.draw(self.guiImages.arrow, window.x+10, window.y+(window.h/2), math.rad(-90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                    if self:mouseCollide({x=window.x+10, y=window.y+(window.h/2)-8, height=32, width=32}, true)  and self.cooldown==0.0 and love.mouse.isDown(1) then
                        self.cooldown=1.0
                        self.selectPage=self.selectPage-6
                        if self.selectPage<1 then self.selectPage=1 end
                    end
                end
                --right arrow
                if self.selectPage<(#self.sceneImages-6) then
                    love.graphics.draw(self.guiImages.arrow, window.x+(window.w-12), window.y+(window.h/2), math.rad(90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                    if self:mouseCollide({x=window.x+(window.w-12), y=window.y+(window.h/2)-8, height=32, width=32}, true)  and self.cooldown==0.0 and love.mouse.isDown(1) then
                        self.cooldown=1.0
                        self.selectPage=self.selectPage+6
                    end
                end
            end,
            drawImageSelect=function(self, window)
                local font=love.graphics.getFont()
                local title="-select a background image-"
                local button={w=(window.w+15)/4, h=(window.h+15)/4}
                local y,x=window.y+font:getHeight(), (window.x+((window.w/2)-((button.w*3)/2)))-10
                local ox=x
                
                love.graphics.print(title, window.x+((window.w/2)-(font:getWidth(title)/2)), y)

                y=y+(font:getHeight()*2)

                if self.selectPage==nil then self.selectPage=1 end
                local endPage=self.selectPage+5
                

                if endPage>#self.sceneImages then endPage=#self.sceneImages end

                local cx, cy=window.x+((window.w/2)-((font:getWidth("CANCEL")+4)/2)), window.y+(window.h-(font:getHeight()+10))                
                self:drawTextButton("CANCEL", cx, cy)
                
                
                if self.selectPage>1 then
                    love.graphics.draw(self.guiImages.arrow, window.x+10, window.y+(window.h/2), math.rad(-90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                end
                --right arrow
                if self.selectPage<(#self.sceneImages-6) then
                    love.graphics.draw(self.guiImages.arrow, window.x+(window.w-12), window.y+(window.h/2), math.rad(90), 1, 1, self.guiImages.arrow:getWidth()/2, self.guiImages.arrow:getHeight()/2)
                end

                for i=self.selectPage, endPage do
                    local file=self.sceneImages[i]
                    local scale={x=button.w/file.image:getWidth(), y=button.h/file.image:getHeight()}
                    local col=0.5
                    
                    if self:mouseCollide({x=x, y=y, width=button.w, height=button.h}, true) then 
                        col=1 
                        if love.mouse.isDown(1) and self.cooldown==0.0 then
                            self.cooldown=1.0
                            self:setBackgroundImage(self.activeLayer, i)
                            self.messageBox=false
                            self.editorState=self.oldState
                            self.oldState=nil
                            self.selectPage=nil
                        end
                    end
                    love.graphics.setColor(col, col, col, 1)

                    love.graphics.draw(file.image, x, y, 0, scale.x, scale.y)
                    love.graphics.print(file.name, x+((button.w/2)-(font:getWidth(file.name)/2)), y+button.h)
                    x=x+button.w+5
                    if i%3==0 then y=y+button.h+20 x=ox end
                end

                love.graphics.setColor(1, 1, 1, 1)

            end,
            mouseCollide=function(self, col, editor)
                local mx, my = self:scaleMousePosition(editor)

                --if not editor, adjust according to layer offsets. 
                if not editor then
                    local layer=self.layers[self.activeLayer]
                    mx=mx-(layer.x) 
                    my=my-(layer.y)
                end

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
                    if my>(windowH)then
                        mx, my=self:scaleMousePosition(false)
                        love.graphics.setColor(1, 1, 1, 0.7)
                        if self.useGrid then 
                            mx=self.gridSize*(math.floor(mx/self.gridSize)) 
                            my=self.gridSize*(math.floor(my/self.gridSize)) 
                        end

                        local layer=self.layers[self.activeLayer]
                        mx=mx-layer.x
                        my=my-layer.y
                        love.graphics.draw(obj.image, mx-(obj.width/2), my-(obj.height/2))
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
                                    if object.layer==self.activeLayer and self:mouseCollide(object, false) then
                                        if love.mouse.isDown(1) then
                                            self.cooldown=1.0
                                            self.dragNDrop=v.id
                                        end
                                    end
                                end
                        end
                        if self.dragNDrop~=nil and self.editState=="delete" then
                            self:deleteObject(self.dragNDrop)
                            self.dragNDrop=nil
                        end
                        
                        if self.dragNDrop~=nil and self.editState=="move" then
                            local mx, my=self:scaleMousePosition()
                            local windowH=self.topMenuSize
                            if self.topMenuHide==true then windowH=16 end
                            if my>(windowH+32)then
                                local layer=self.layers[self.activeLayer]
                                mx=mx-(layer.x) 
                                my=my-(layer.y)
                                
                                --draw it being moved.
                                local obj=self.objects[self.dragNDrop]
                                obj.x=mx-(obj.width/2) 
                                obj.y=my-(obj.height/2)
                                if self.useGrid then 
                                    obj.x=self.gridSize*(math.floor(obj.x/self.gridSize)) 
                                    obj.y=self.gridSize*(math.floor(obj.y/self.gridSize)) 
                                end
                                --if mouse is let go, drop object there.
                                if  love.mouse.isDown(1)==false and self.cooldown==0.0 then
                                    self.cooldown=1.0
                                    self.dragNDrop=nil
                                end
                            end
                        end
                end
            end,
            drawEditor=function(self)
                love.graphics.setCanvas(self.canvas)
                love.graphics.clear()

                self:drawTopMenu()
                    if self.messageBox==true then
                        self:drawMsgBox()
                    end
                    if self.smallMessageBox==true then
                        if self.editorState=="save scene"  then
                            if self.cooldown==0.0 then
                                self:drawSmallMsgBox()
                            end
                        else
                            self:drawSmallMsgBox()
                        end
                    end
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

                --love.graphics.setColor(0.5, 0.5, 0.5, 1)
                local xspot=windowWidth-(font:getWidth("using:"))
                love.graphics.print("using: ", xspot-32, 0)
                local img=self.guiImages.objDrop
                if self.editState=="move layer" then img=self.guiImages.moveLayer end
                if self.editState=="move camera" then img=self.guiImages.moveLayer end
                if self.editState=="move" then img=self.guiImages.objMove end
                if self.editState=="delete" then img=self.guiImages.objDel end

                love.graphics.draw(img, xspot+15, 0)

                love.graphics.print("layer: " .. self.activeLayer .. "/" .. #self.layers, xspot-32-(font:getWidth("layer:         ")))
                love.graphics.print("-" .. self.name .. "-",  (windowWidth/2)-(font:getWidth("-" .. self.name .. "-")/2))

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
                        self:drawSceneMenu()
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

            updateLayerMenu=function(self)
                
                local font=love.graphics.getFont()
                local x,y=(love.graphics.getWidth()/self.editorScale.x)-52, 20+font:getHeight()
                        local x,y=8, 20+font:getHeight()
                        self.layers[self.activeLayer].alpha=self:updateNumberBox("alpha", x, y, self.layers[self.activeLayer].alpha)
                        if self.layers[self.activeLayer].alpha>1 then self.layers[self.activeLayer].alpha=1 end
        
                        x=8
                        y=y+5
                        local y=y+font:getHeight()
                        self.layers[self.activeLayer].scroll.speed=self:updateNumberBox("scroll speed", x, y, self.layers[self.activeLayer].scroll.speed)
                        if self.layers[self.activeLayer].scroll.speed>5 then self.layers[self.activeLayer].scroll.speed=5 end

                        y=y+5
                        local y=y+font:getHeight()
                        self.layers[self.activeLayer].scroll.constant.x=self:updateCheckbox(" x",  x+font:getWidth("constant scroll "), y, self.layers[self.activeLayer].scroll.constant.x)
                        self.layers[self.activeLayer].scroll.constant.y=self:updateCheckbox(" y",  x+font:getWidth("constant scroll ")+font:getWidth(" x:")+self.guiImages.checkYes:getWidth()+2, y, self.layers[self.activeLayer].scroll.constant.y)

                        self.layers[self.activeLayer].scale=self:updateNumberBox("scale", x, y+font:getHeight()+4, self.layers[self.activeLayer].scale)

                        x,y=(love.graphics.getWidth()/self.editorScale.x)-72, 20
                        if self:mouseCollide({x=x, y=y, width=24, height=24}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                                self.cooldown=1.0
                                self:addLayer({x=0, y=0, type="basic"}, self.activeLayer) 
                                self.activeLayer=self.activeLayer+1
                        end         
                        if self:mouseCollide({x=x+24, y=y, width=24, height=24}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                            self.cooldown=1.0
                            self.activeLayer=self.activeLayer+1
                            if self.activeLayer>#self.layers then self.activeLayer=#self.layers end
                        end
                        if self:mouseCollide({x=x+48, y=y, width=24, height=24}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                            self.cooldown=1.0
                            self.activeLayer=self.activeLayer-1
                            if self.activeLayer<1 then self.activeLayer=1 end
                        end

                        y=y+24
                        if (self:mouseCollide({x=x, y=y, width=24, height=24}, true)) and love.mouse.isDown(1) and self.cooldown==0.0 then
                            self.oldState=self.editorState
                            self.editorState="select image"
                            self.messageBox=true
                        end

                        if  self:mouseCollide({x=x+24, y=y, width=24, height=24}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                            self.cooldown=1.0
                            self.layers[self.activeLayer].tiled=not self.layers[self.activeLayer].tiled
                        end

                        if  self:mouseCollide({x=x+48, y=y, width=24, height=24}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                            self.cooldown=1.0
                            self.editState="move layer"
                        end
                        self.layers[self.activeLayer].visible=self:updateCheckbox("visible",  x, y+24, self.layers[self.activeLayer].visible)

                        local lineup=font:getWidth("reverse")-font:getWidth("visible")
                        self.layers[self.activeLayer].reverse=self:updateCheckbox("reverse ", x-lineup, y+36, self.layers[self.activeLayer].reverse)
                        if self.activeLayer~=1 then 
                            if self:updateTextButton("delete layer", x-lineup, y+58) then
                                self:deleteLayer(self.activeLayer)
                            end
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
            updateNumberBox=function(self, name, x, y, data)
                        local font=love.graphics.getFont()
                        x=x+font:getWidth(name .. ": ")
                        if self:mouseCollide({x=x, y=y, width=16, height=16}, true) then
                            if love.mouse.isDown(1) and self.cooldown==0.0 then
                                self.cooldown=1.0
                                data=data+0.05
                            end
                        end
                        x=x+self.guiImages.plus:getWidth()
                        love.graphics.print(" " .. data, x, y)
                        x=x+font:getWidth(" 0.99")
                        if self:mouseCollide({x=x, y=y, width=16, height=16}, true) then
                            if love.mouse.isDown(1) and self.cooldown==0.0 then
                                self.cooldown=1.0
                                data=data-0.05
                            end
                        end
                        if data<0.00 then data=0.00 end
                return data
            end,
            numberBox=function(self, name, x, y, data)
                local font=love.graphics.getFont()
                love.graphics.print(name ..": ", x, y)
                x=x+font:getWidth(name .. ": ")
                self:drawButton(self.guiImages.plus, x, y, (self:mouseCollide({x=x, y=y, width=16, height=16}, true)), "increase " .. name)
                x=x+self.guiImages.plus:getWidth()
                local toshow=tostring(data)
                if string.len(toshow)==1 then toshow=toshow .. ".00" end
                if string.len(toshow)==3 then toshow=toshow .. "0" end

                love.graphics.print("" .. toshow, x, y)
                x=x+font:getWidth("0.99")
                self:drawButton(self.guiImages.minus, x, y, (self:mouseCollide({x=x, y=y, width=16, height=16}, true)), "decrease " .. name)
            end,
            updateCheckbox=function(self, name, x, y, data)
                local font=love.graphics.getFont()
                x=x+font:getWidth(name .. ": ")
                if self:mouseCollide({x=x, y=y, width=16, height=16}, true) then
                    if love.mouse.isDown(1) and self.cooldown==0.0 then
                        self.cooldown=1.0
                        data=not data
                    end
                end
                return data
            end,
            drawCheckbox=function(self, name, x, y, data)
                local img=self.guiImages.checkNo
                local font=love.graphics.getFont()

                if data==true then img=self.guiImages.checkYes end
                love.graphics.print(name ..": ", x, y)
                x=x+font:getWidth(name .. ": ")
                self:drawButton(img, x, y, ((self:mouseCollide({x=x, y=y, width=16, height=16}, true)) or (data==true)), "set " .. name)
            end,
            updateTextButton=function(self, title, x, y)
                local font=love.graphics.getFont()
                local window={x=x, y=y, width=font:getWidth(title)+8, height=font:getHeight()+6}

                if self:mouseCollide(window, true) and self.cooldown==0.0 and love.mouse.isDown(1) then
                    self.cooldown=1.0
                    return true
                end                    
                return false
            end,
            drawTextButton=function(self, title, x, y)
                local oldColor={}
                local font=love.graphics.getFont()
                local window={x=x, y=y, w=font:getWidth(title)+8, h=font:getHeight()+6}

                oldColor[1], oldColor[2], oldColor[3], oldColor[4]=love.graphics.getColor()
                local b, o={136/255, 136/255, 153/255, 0.8}, {51/255, 51/255, 85/255}
                --if mouse over, reverse colors
                if self:mouseCollide({x=window.x, y=window.y, width=window.w, height=window.h}, true) then
                    local ob=b 
                    b=o 
                    o=ob
                end
                love.graphics.setColor(b[1], b[2], b[3], b[4])
                love.graphics.rectangle("fill", window.x, window.y, window.w, window.h)
                love.graphics.setColor(o[1], o[2], o[3], o[4])
                love.graphics.rectangle("line", window.x, window.y, window.w, window.h)
                love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
                love.graphics.print(title, x+4, y+2)
            end,
            
            updateSceneMenu=function(self)
                local font=love.graphics.getFont()
                self.topMenuSize=135/self.editorScale.y
                local center=(love.graphics.getWidth()/self.editorScale.x)/2

                x=8
                if self:updateTextButton(self.name, center-((font:getWidth("-" .. self.name .. "-")/2)+6), 20) then
                    self.oldState=self.editorState
                    self.editorState="rename"
                    textBuffer=self.name
                    self.smallMessageBox=true
                end

                if self:updateTextButton("new", x, 25) then
                    --make window say new created, with okay button.
                    self.oldState=self.editorState
                    self.editorState="new scene"
                    self.smallMessageBox=true
                end
                if self:updateTextButton("load", x, 47) then
                    self:loadSaveImages()
                    self.oldState=self.editorState
                    self.editorState="select save"
                    self.messageBox=true
                end
                if self:updateTextButton("save", x, 68) then
                    love.graphics.captureScreenshot(self.name .. ".png")
                    self:save()
                    self.oldState=self.editorState
                    self.editorState="save scene"
                    self.smallMessageBox=true
                    self.cooldown=3.0
                end

                x=(love.graphics.getWidth()/self.editorScale.x)-45


                if self:mouseCollide({x=x+24, y=25, width=24, height=24}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                    self.oldState=self.editorState
                    self.editorState="select music"
                    self.messageBox=true
                end
                
                if self.music~=nil then
                                if not self.playing then
                                   if (self:mouseCollide({x=x, y=25, width=24, height=24}, true))  and love.mouse.isDown(1) and self.cooldown==0.0 then
                                        self.cooldown=1.0
                                        self:playMusic()
                                   end
                                else
                                    if (self:mouseCollide({x=x, y=25, width=24, height=24}, true))  and love.mouse.isDown(1) and self.cooldown==0.0 then
                                        self.cooldown=1.0
                                        self:stopAllMusic()
                                        self.playing=false
                                    end
                                end
                 end



                if self:mouseCollide({x=x+24, y=25+24, width=24, height=24}, true) and love.mouse.isDown(1) and self.cooldown==0.0 then
                    self.cooldown=1.0
                    self.editState="move camera"
                end

                self.scale.x=self:updateNumberBox("scale", x-62, 25+24+24, self.scale.x)
                self.scale.y=self.scale.x

            end,
            drawSceneMenu=function(self)
                local font=love.graphics.getFont()
                self.topMenuSize=135/self.editorScale.y
                local center=(love.graphics.getWidth()/self.editorScale.x)/2
                if self.name=="" then self.name="untitled" end

                self:drawTextButton(self.name, center-((font:getWidth("-" .. self.name .. "-")/2)+6), 20)
                love.graphics.print("camera: x:" .. math.floor(self.x) .. " y:" .. math.floor(self.y), center-((font:getWidth("-" .. self.name .. "-")/2)+6), 42)

                local x=8
                self:drawTextButton("new", x, 25)
                self:drawTextButton("load", x, 47)
                self:drawTextButton("save", x, 68)


                local x=(love.graphics.getWidth()/self.editorScale.x)-45

                     self:drawButton(self.guiImages.musicNote, x+24, 25, (self:mouseCollide({x=x+24, y=25, width=24, height=24}, true)), "select background music")  
                                --load sound file, etc
                        if self.music~=nil then
                                if not self.playing then
                                    self:drawButton(self.guiImages.play, x, 25, (self:mouseCollide({x=x, y=25, width=24, height=24}, true)), "play background music") 
                                else
                                    self:drawButton(self.guiImages.pause, x, 25, (self:mouseCollide({x=x, y=25, width=24, height=24}, true)), "pause background music") 
                                end
                        end

                    self:drawButton(self.guiImages.moveLayer, x+24, 25+24,(self.editState=="move camera" or self:mouseCollide({x=x+24, y=25+24, width=24, height=24}, true)), "move scene camera") 
                    self:numberBox("scale", x-62, 25+24+24, self.scale.x)

            end,
            drawLayerMenu=function(self)
                self.topMenuSize=200/self.editorScale.y
                --parallax: x speed, yspeed  constant or relative
                local font=love.graphics.getFont()

                local totalText="layer: " .. self.activeLayer .. " of " .. #self.layers
                love.graphics.print(totalText, 8, 20)                
                local x,y=8, 23+font:getHeight()
                self:numberBox("alpha", x, y, self.layers[self.activeLayer].alpha)

                x=8
                y=y+5
                local y=y+font:getHeight()
                self:numberBox("scroll speed", x, y, self.layers[self.activeLayer].scroll.speed)
 
                y=y+5
                local y=y+font:getHeight()
                love.graphics.print("constant scroll ", x, y)
                self:drawCheckbox(" x", x+font:getWidth("constant scroll "), y, self.layers[self.activeLayer].scroll.constant.x)
                self:drawCheckbox(" y", x+font:getWidth("constant scroll ")+font:getWidth(" x:")+self.guiImages.checkYes:getWidth()+2, y, self.layers[self.activeLayer].scroll.constant.y)
                self:numberBox("scale", x, y+font:getHeight()+4, self.layers[self.activeLayer].scale)

                --draws an object menu for different tools, etc. Placing via grid (or not),
                --deleting or moving instead of placing object
                x,y=(love.graphics.getWidth()/self.editorScale.x)-72, 20
                self:drawButton(self.guiImages.newLayer, x, y, (self:mouseCollide({x=x, y=y, width=24, height=24}, true)), "newlayer")                                
                self:drawButton(self.guiImages.layerUp, x+24, y, (self:mouseCollide({x=x+24, y=y, width=24, height=24}, true)), "up a layer")
                self:drawButton(self.guiImages.layerDown, x+48, y, (self:mouseCollide({x=x+48, y=y, width=24, height=24,}, true)), "down a layer")
                y=y+24
                local backgroundText="change background"
                if self.layers[self.activeLayer].image==nil then backgroundText="set background" end
                self:drawButton(self.guiImages.backgroundImage, x, y, (self:mouseCollide({x=x, y=y, width=24, height=24}, true)), backgroundText)                                
                self:drawButton(self.guiImages.tileLayer, x+24, y, (self.layers[self.activeLayer].tiled or self:mouseCollide({x=x+24, y=y, width=24, height=24}, true)), "tile background")
                self:drawButton(self.guiImages.moveLayer, x+48, y, (self.editState=="move layer" or self:mouseCollide({x=x+48, y=y, width=24, height=24}, true)), "reposition layer")

                self:drawCheckbox("visible ", x, y+24, self.layers[self.activeLayer].visible)
                local lineup=font:getWidth("reverse")-font:getWidth("visible")
                self:drawCheckbox("reverse ", x-lineup, y+36, self.layers[self.activeLayer].reverse)
                if self.activeLayer~=1 then self:drawTextButton("delete layer", x-lineup, y+58) end --can't delete base layer.
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
                self.topMenuSize=100/self.editorScale.y
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
                if total>=#self.editorObject then total=#self.editorObject end

                for i=self.objPageAt, total do
                    v=self.editorObject[i]
                    local obj=self.objectTypes[v]
                    --if object image is larger than window, scale to fit.
                    local scale=1
                    if obj.width>obj.height then scale=objButtonSize/obj.width else scale=objButtonSize/obj.height end

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
                    if self.cooldown>0.0 then self.cooldown=self.cooldown-0.1 else self.cooldown=0.0 end
                    if not self.messageBox and not self.smallMessageBox then
                                            --keypress also move camera
                                        local move={x=0, y=0}
                                        if love.keyboard.isDown("up") then  move.y=move.y-1 end 
                                        if love.keyboard.isDown("down") then move.y=move.y+1 end 
                                        if love.keyboard.isDown("left") then move.x=move.x-1 end
                                        if love.keyboard.isDown("right") then move.x=move.x+1 end
                                        self:moveCamera(move.x, move.y)


                                        self:mouseOverObject()
                                        local mx, my=self:scaleMousePosition(true)

                                        --move layer if that's the tool
                                        if self.editState=="move layer" and love.mouse.isDown(1) and self.cooldown==0.0 then
                                            local mx, my=self:scaleMousePosition(false)
                                            if self.last==nil then self.last={x=mx, y=my} end
                                            self:moveLayer(self.activeLayer, mx-self.last.x, my-self.last.y)
                                            self.last.x=mx
                                            self.last.y=my
                                        else
                                            self.last=nil
                                        end

                                        --move camera if that's the tool
                                        
                                        if self.editState=="move camera" and love.mouse.isDown(1) and self.cooldown==0.0 then
                                            local mx, my=self:scaleMousePosition(false)
                                            if self.last2==nil then self.last2={x=mx, y=my} end
                                            self:moveCamera((mx-self.last2.x)*-2, (my-self.last2.y)*-2)
                                            self.last2.x=mx
                                            self.last2.y=my
                                        else
                                            self.last2=nil
                                        end

                                        --drop an object on the map
                                        if love.mouse.isDown(1) and not self.mousePressed then
                                            if self.dropObject~=nil and self.editState=="drop" then
                                                local type=self.editorObject[self.dropObject]
                                                local obj=self.objectTypes[type]
                                                local windowH=self.topMenuSize+16
                                                if self.topMenuHide==true then windowH=16 end
                                                if my>(windowH+16) then
                                                    mx, my=self:scaleMousePosition(false)
                                                    if self.useGrid then 
                                                        mx=self.gridSize*(math.floor(mx/self.gridSize)) 
                                                        my=self.gridSize*(math.floor(my/self.gridSize)) 
                                                    else
                                                        self.mousePressed=true
                                                    end
                                                    --adjust based on layer offset and scene camera offset)
                                                    local layer=self.layers[self.activeLayer]
                                                    local mx=(mx-layer.x)-(obj.width/2)
                                                    local my=(my-layer.y)-(obj.height/2)
                                                    local tplace=true
                                                    --check to see if an object is already there, and if so, don't put anything down.
                                                    for i,v in ipairs(self.objects) do
                                                        if v.layer==self.activeLayer and mx==v.x and my==v.y then
                                                            tplace=false 
                                                            break
                                                        end
                                                    end
                                                    if tplace then self:addObject({type=type, layer=self.activeLayer, x=mx, y=my}) end
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
                                        if self.topMenuHide==false and self.editorState=="layers" then
                                            self:updateLayerMenu()
                                        end
                                        if self.topMenuHide==false and self.editorState=="scene" then
                                            self:updateSceneMenu()
                                        end
                        else
                            if self.editorState=="select save" then
                                self:updateMsgBox()
                            end
                            if self.editorState=="select image" then
                                self:updateMsgBox()
                            end
                            if self.editorState=="select music" then
                                self:updateMsgBox()
                            end
                            if self.editorState=="save scene" then
                               self:updateSmallMsgBox()
                            end
                            if self.editorState=="rename" then
                                self:updateSmallMsgBox()
                            end
                            if self.editorState=="new scene" then
                                self:updateSmallMsgBox()
                            end
                        end
                        if not love.mouse.isDown(1) then self.mousePressed=false end
            end,
}