--this allows people to move this file + binser to other directories
--and not have to update the file by hand, etc.
local folderOfThisFile = (...):match("(.-)[^%.]+$")
local function drawSort(a,b) return a.y+a.h < b.y+b.h end

return {
            sceneTypes={},
            layerTypes={},
            name="",
            objectTypes={},
            layers={},
            objects={},
            editing=false,
            windowColors={background={63/256, 63/256, 116/256, 149/256}, border={1, 1, 1, 1}},
            scale={x=1, y=1},
            path=love.filesystem.getSource(),
            binser=require(folderOfThisFile .. "binser"),
            cooldown=0.0, --so mousepresses don't repeat a ton.
           setWindowColor=function(self, background, border)
                self.windowColors.background=background
                self.windowColors.border=border 
           end,
           drawWindow=function(self, window)
                local oldColor={}
                oldColor[1], oldColor[2], oldColor[3], oldColor[4]=love.graphics.getColor()
                local b, o=self.windowColors.background, self.windowColors.border
                love.graphics.setColor(b[1], b[2], b[3], b[4])
                love.graphics.rectangle("fill", window.x, window.y, window.w, window.h)
                love.graphics.setColor(o[1], o[2], o[3], o[4])
                love.graphics.rectangle("line", window.x, window.y, window.w, window.h)
                love.graphics.setColor(oldColor[1], oldColor[2], oldColor[3], oldColor[4])
           end,
           setScale=function(self, scalex, scaley)
                --mostly for mouse functions.
                self.scale={x=scalex, y=scaley}
            end,
            startEditing=function(self) self.editing=true end,
            endEditing=function(self) self.editing=true end,
            addSceneType=function(self, type)
                self.sceneTypes[type.type]=type
            end,
            addObjectType=function(self, type)
                self.objectTypes[type.type]=type
            end,
            addLayerType=function(self, type)
                self.layerTypes[type.type]=type
            end,
            newScene=function(self, name, type, vars)
                self:clean()
                self.name=name
                self.type=type
                self.vars=vars
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
                binser.writeFile(self.path .. "/" .. self.name, binser.serialize({layers=self.layers, objects=self.objects}))
            end,
            addLayer=function(self, data)
                self.layers[#self.layers+1]=data
            end,
            addObject=function(self, data)
                self.objects[#self.objects+1]=data
            end,
            update=function(self, dt)
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
                if self.editing==true then
                    --do editing update stuff here, with mouse, etc.
                end
            end,
            drawButton=function(self)
                --draw all the editor buttons on the main screen.
            end,
            drawMsgBox=function(self)
                --this draws the mssg box when adding layer or dropping an object
                --so that you can specify additional variables, based on a vars variable
                --added when creating the object type or the layer type or the scene type.
            end,
            drawIcon=function(self, x, y, obj)
                --draw an object icon at x/y
                --for selecting and dropping objects.
            end,
            drawObjects=function(self, layer, x, y)
                --zsorting
                local zsort={}
                for i,v in ipairs(self.objects) do
                    zsort[#zsort+1]={id=i, x=v.x, y=v.y, h=v.height, w=v.width}
                end
                table.sort(zsort, drawSort)
                for i,v in ipairs(zsort) do
                    local object=self.objects[v.id]
                    local type=self.objectTypes[object.type]
                    if self.editing==false and type.draw~=nil then
                            type:draw(object, x, y) 
                    --if in the editor, and the type icon is set
                    elseif self.editing==true and type.icon~=nil then
                        love.graphics.draw(type.icon, object.x+x, object.y+y)
                    end                    
                end
            end,
            drawLayer=function(self, x, y, layer)
                --if it's passing the layer number...
                if type(layer)~="table" then layer=self.layers[layer] end
                local type=self.layerTypes[layer.type]
                if type.draw~=nil then
                    type:draw(layer, x, y)
                else
                    --if there is no draw function and there is an image, just draw the image relative to camera coords.
                    if layer.image~=nil then
                        love.graphics.draw(layer.image, x, y)
                    end
                end
                self:drawObjects(il, x, y)   
            end,
            draw=function(self, x, y)
                if x==nil then x=0 end
                if y==nil then y=0 end

                love.graphics.scale(self.scale.x, self.scale.y)
                for il,layer in ipairs(self.layers) do 
                        self:drawLayer(x, y, layer)
                end

                if self.sceneTypes[self.type]~=nil and self.sceneTypes[self.type].draw~=nil then
                    self.sceneTypes[self.type]:draw()
                end
            end,
            ------------------EDITOR FUNCTIONALITY-----------------------
            drawEditor=function(self, scalex, scaley)

            end,
            updateEditor=function(self, scalex, scaley)

            end,
}