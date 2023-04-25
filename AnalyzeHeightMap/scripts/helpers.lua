local function getDeco(rgba, lineWidth, pointSize, fillAlpha)
  if not rgba[4] then
    rgba[4] = 255
  end

  local deco = View.ShapeDecoration.create()
  deco:setLineColor(rgba[1], rgba[2], rgba[3], rgba[4])
  deco:setFillColor(rgba[1], rgba[2], rgba[3], fillAlpha)
  if lineWidth then
    deco:setLineWidth(lineWidth)
  end
  if pointSize then
    deco:setPointSize(pointSize)
  end
  return deco
end

local function graphDeco(color, headline, overlay)
  local deco = View.GraphDecoration.create()
  deco:setGraphColor(color[1], color[2], color[3], color[4] or 255)
  deco:setTitle(headline or '')
  deco:setGraphType('LINE')
  deco:setDynamicSizing(true)
  deco:setAspectRatio('EQUAL')
  deco:setYBounds(-10, 32)
  deco:setXBounds(0, 100)
  if overlay then
    deco:setAxisVisible(false)
    deco:setBackgroundVisible(false)
    deco:setGridVisible(false)
    deco:setLabelsVisible(false)
    deco:setTicksVisible(false)
  end
  return deco
end

local helper = {}
helper.getDeco = getDeco
helper.graphDeco = graphDeco
return helper
