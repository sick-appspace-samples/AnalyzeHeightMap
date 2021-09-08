
--Start of Global Scope---------------------------------------------------------

local helper = require 'helpers'

local GREEN = {0, 200, 0}
local RED = {200, 0, 0}
local BLUE = {59, 156, 208}
local GREY = {220, 220, 220}
local FILL_ALPHA = 100

local MM_TO_PROCESS = 10 -- 10mm slices
local CROP_DISTANCE_TO_PEAK = 20 -- mm

local DELAY = 150

local VOLUMERANGE_TO_PASS = {170, 220} -- The triangle is accepted, for the cylinder use {330, 380}

local v2D = View.create('Viewer2D')
local v3D = View.create('Viewer3D')

local function viewHeightMap()
  local heightMap = Object.load('resources/heightMap.json')
  local minZ, maxZ = Image.getMinMax(heightMap)
  local zRange = maxZ - minZ
  local pixelSizeX, pixelSizeY = Image.getPixelSize(heightMap)
  local heightMapW, heightMapH = Image.getSize(heightMap)

  local deco3D = View.ImageDecoration.create()
  deco3D:setRange(heightMap:getMin(), heightMap:getMax() / 1.01)

  -- Correct the heightMaps origin, so it is centered on the x-axis
  local stepsize = math.ceil(MM_TO_PROCESS / pixelSizeY) -- convert mm to pixel steps

  -- Rotate 90° around x axis and translate to the base of the scanned image
  local rectangleBaseTransformation = Transform.createRigidAxisAngle3D({1, 0, 0}, math.pi / 2, 0, MM_TO_PROCESS / 2, minZ + zRange / 2)
  local scanBox = Shape3D.createBox(heightMapW * pixelSizeX, zRange * 1.2, MM_TO_PROCESS, rectangleBaseTransformation)

  -------------------------------------------------
  -- Process data and start over if finished ------
  -------------------------------------------------

  local coords = {}
  for i = 0, 495 do
    coords[#coords + 1] = i * 100 / 495
  end

  while true do
    for i = 0, heightMapH - 1, stepsize do
      local profilingTime = DateTime.getTimestamp()

      -------------------------------------------------
      -- Aggregate a number of profiles together ------
      -------------------------------------------------

      local profilesToAggregate = {}
      for j = 0, stepsize - 1 do -- stepize = MM_TO_PROCESS / pixelSizeY
        if i + j < heightMapH then
          profilesToAggregate[#profilesToAggregate + 1] = Image.extractRowProfile(heightMap, i + j)
        end
      end
      local frameProfile = Profile.aggregate(profilesToAggregate, 'MEAN')
      local values, _, valids = frameProfile:toVector()
      frameProfile = Profile.createFromVector(values, coords, valids)

      -------------------------------------------------
      -- Crop profile to region of interrest ----------
      -------------------------------------------------

      local _, indexOfMaxZVal = frameProfile:getMax()
      local cropDistance = CROP_DISTANCE_TO_PEAK / pixelSizeX

      indexOfMaxZVal = math.min(indexOfMaxZVal, frameProfile:getSize() - cropDistance)
      indexOfMaxZVal = math.max(indexOfMaxZVal, cropDistance)

      local searchProfile = frameProfile:crop( indexOfMaxZVal - cropDistance, indexOfMaxZVal + cropDistance )

      -------------------------------------------------
      -- Fix missing data -----------------------------
      -------------------------------------------------

      searchProfile = searchProfile:blur(11, true)
      searchProfile:setValidFlagsEnabled(false)

      -------------------------------------------------
      -- Calculate second derivative and detect edges -
      -------------------------------------------------

      local secondDerivative = searchProfile:gaussDerivative(45, 'SECOND')
      secondDerivative = secondDerivative:multiplyConstant(100)

      local extremas = secondDerivative:findLocalExtrema('MAX', 15, 0.5)
      local edges = {extremas[1], extremas[#extremas]} --only use the first and last edge
      --edges = extremas

      -------------------------------------------------
      -- Evaluate gained data -------------------------
      -------------------------------------------------
      local valid = false
      local failPassColor = RED

      if #edges == 2 then
        -------------------------------------------------
        -- Crop to detected Edges and postprocess -------
        -------------------------------------------------

        local croppedProfile = searchProfile:crop(edges[1], edges[2])

        -- Translate cropped profile to z = 0
        local cropedOffProfile = croppedProfile:addConstant(-croppedProfile:getMin())

        local height = cropedOffProfile:getMax()
        local mean = cropedOffProfile:getMean()
        local sum = cropedOffProfile:getSum()
        local volumePerMM = sum * pixelSizeX

        -------------------------------------------------
        -- Evaluate if the current area is valid or not -
        -------------------------------------------------

        if  volumePerMM > VOLUMERANGE_TO_PASS[1] and volumePerMM < VOLUMERANGE_TO_PASS[2] then
          valid = true
          failPassColor = GREEN
        end

        print('')
        print('Height: ' .. height .. 'mm')
        print('MeanHeight:   ' .. mean .. 'mm')
        print('Volume per mm: ' .. volumePerMM .. 'mm²')
        print('Valid:  ' .. tostring(valid))
        print( 'Time for processing: ' .. DateTime.getTimestamp() - profilingTime .. 'ms' )

        local extremaLines = {}
        for ind, extrema in pairs(edges) do
          local xExtrema = searchProfile:getCoordinate(extrema)
          extremaLines[ind] =
            Shape.createLineSegment(
            Point.create(xExtrema, minZ),
            Point.create(xExtrema, maxZ)
          )
        end

        v2D:clear()
        v2D:addProfile(frameProfile, helper.graphDeco(BLUE))
        v2D:addProfile(secondDerivative, helper.graphDeco(GREY, '', true))
        v2D:addProfile(croppedProfile, helper.graphDeco(failPassColor, '', true) )
        v2D:addShape(extremaLines)
      end

      local scannedFrame = scanBox:translate(0, i * pixelSizeY, 0) -- Move scan box to the current frame

      v3D:clear()
      local heightmapID = v3D:addHeightmap(heightMap, deco3D)
      v3D:addShape(scannedFrame, helper.getDeco(failPassColor, 1, 1, FILL_ALPHA), nil, heightmapID)
      v3D:present()
      v2D:present()
      print( 'Time for processing + visualization: ' .. DateTime.getTimestamp() - profilingTime .. 'ms' )
      Script.sleep(DELAY)
    end
  end
end
Script.register('Engine.OnStarted', viewHeightMap)
-- serve API in global scope
