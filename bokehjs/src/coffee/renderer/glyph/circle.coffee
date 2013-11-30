
define [
  "underscore",
  "renderer/properties",
  "./glyph",
], (_, Properties, Glyph) ->

  glyph_properties = Properties.glyph_properties
  line_properties  = Properties.line_properties
  fill_properties  = Properties.fill_properties

  class CircleView extends Glyph.View

    initialize: (options) ->
      super(options)
      ##duped in many classes
      @glyph_props = @init_glyph(@mget('glyphspec'))
      if @mget('selection_glyphspec')
        spec = _.extend({}, @mget('glyphspec'), @mget('selection_glyphspec'))
        @selection_glyphprops = @init_glyph(spec)
      if @mget('nonselection_glyphspec')
        spec = _.extend({}, @mget('glyphspec'), @mget('nonselection_glyphspec'))
        @nonselection_glyphprops = @init_glyph(spec)
      @have_new_data = false

    init_glyph: (glyphspec) ->
      glyph_props = new glyph_properties(
        @,
        glyphspec,
        ['x', 'y', 'radius']
        {
          fill_properties: new fill_properties(@, glyphspec),
          line_properties: new line_properties(@, glyphspec)
        }
      )
      return glyph_props

    _set_data: (@data) ->
      @x = @glyph_props.data_v_select('x', data)
      @y = @glyph_props.data_v_select('y', data)
      @mask = new Uint8Array(data.length)
      @selected_mask = new Uint8Array(data.length)
      for i in [0..@mask.length-1]
        @mask[i] = true
        @selected_mask[i] = false
      @have_new_data = true

    set_data: (request_render=true) ->
      source = @mget_obj('data_source')
      if source.type == 'ColumnDataSource'
        @x = @source_v_select('x', @glpyhprops, source)
        @y = @source_v_select('y', @glyphprops, source)
        @mask = new Uint8Array(data.length)
        @selected_mask = new Uint8Array(data.length)
        for i in [0..@mask.length-1]
          @mask[i] = true
          @selected_mask[i] = false
        @have_new_data = true
  
      if request_render
        @request_render()


    source_v_select: (attrname, glyphprops, datasource) ->
      # if the attribute is not on this property object at all, log a bad request
      if not (attrname of glpyhprops)
        console.log("requested vector selection of unknown property '#{ attrname }' on objects")
        return

      prop = glyphprops[attrname]
      # if prop.typed?
      #   result = new Float64Array(objs.length)

      # if the attribute specifies a field, and the field exists on
      # the column source, return the column from the column source


      if prop.field? and (prop.field of datasource.get('data'))
        console.log("source_v_select")
        return source.getcolumn(prop.field)
      else
        result = new Array(objs.length)
      '''
      objs = []
      for i in [0..objs.length-1]
        obj = objs[i]


        # If the user gave an explicit value, that should always be returned
        else if glyphprops[attrname].value?
          result[i] = glyphprops[attrname].value

        # otherwise, if the attribute exists on the object, return that value
        else if obj[attrname]?
          result[i] = obj[attrname]

        # finally, check for a default value on this property object that could be returned
        else if glyphprops[attrname].default?
          result[i] = glyphprops[attrname].default

        # failing that, just log a problem
        else
          console.log "vector selection for attribute '#{ attrname }' failed on object: #{ obj }"
          return

      return result
      '''

    _render: (plot_view, have_new_mapper_state=true) ->
      [@sx, @sy] = @plot_view.map_to_screen(@x, @glyph_props.x.units, @y, @glyph_props.y.units)

      ow = @plot_view.view_state.get('outer_width')
      oh = @plot_view.view_state.get('outer_height')

      if @have_new_data or have_new_mapper_state
        @radius = @distance(@data, 'x', 'radius', 'edge')
        @have_new_data = false

      ow = @plot_view.view_state.get('outer_width')
      oh = @plot_view.view_state.get('outer_height')
      for i in [0..@mask.length-1]
        if (@sx[i]+@radius[i]) < 0 or (@sx[i]-@radius[i]) > ow or (@sy[i]+@radius[i]) < 0 or (@sy[i]-@radius[i]) > oh
          @mask[i] = false
        else
          @mask[i] = true

      ds = @mget_obj('data_source')
      selected = ds.get('selected')
      for idx in selected
        @selected_mask[idx] = true
      ctx = @plot_view.ctx

      ctx.save()
      if @glyph_props.fast_path
        if selected and selected.length and @nonselection_glyphprops
          if @selection_glyphprops
            props =  @selection_glyphprops
          else
            props = @glyph_props
          @_fast_path(ctx, props, true)
          @_fast_path(ctx, @nonselection_glyphprops, false)
        else
          @_fast_path(ctx)
      else
        if selected and selected.length and @nonselection_glyphprops
          if @selection_glyphprops
            props =  @selection_glyphprops
          else
            props = @glyph_props
          @_full_path(ctx, props, true)
          @_full_path(ctx, @nonselection_glyphprops, false)
        else
          @_full_path(ctx)
      ctx.restore()

    _fast_path: (ctx, glyph_props, use_selection) ->
      if not glyph_props
        glyph_props = @glyph_props
      if glyph_props.fill_properties.do_fill
        glyph_props.fill_properties.set(ctx, @glyph_props)
        ctx.beginPath()
        for i in [0..@sx.length-1]
          if isNaN(@sx[i] + @sy[i] + @radius[i]) or not @mask[i]
            continue
          if use_selection and not @selected_mask[i]
            continue
          if use_selection == false and @selected_mask[i]
            continue
          ctx.moveTo(@sx[i], @sy[i])
          ctx.arc(@sx[i], @sy[i], @radius[i], 0, 2*Math.PI, false)
        ctx.fill()

      if glyph_props.line_properties.do_stroke
        glyph_props.line_properties.set(ctx, @glyph_props)
        for i in [0..@sx.length-1]
          if isNaN(@sx[i] + @sy[i] + @radius[i]) or not @mask[i]
            continue
          if use_selection and not @selected_mask[i]
            continue
          if use_selection == false and  @selected_mask[i]
            continue
          ctx.moveTo(@sx[i], @sy[i])
          ctx.beginPath()
          ctx.arc(@sx[i], @sy[i], @radius[i], 0, 2*Math.PI, false)
          ctx.stroke()

    _full_path: (ctx, glyph_props, use_selection) ->
      if not glyph_props
        glyph_props = @glyph_props
      for i in [0..@sx.length-1]
        if isNaN(@sx[i] + @sy[i] + @radius[i]) or not @mask[i]
          continue
        if use_selection and not @selected_mask[i]
          continue
        if use_selection == false and @selected_mask[i]
          continue
        ctx.beginPath()
        ctx.arc(@sx[i], @sy[i], @radius[i], 0, 2*Math.PI, false)

        if glyph_props.fill_properties.do_fill
          glyph_props.fill_properties.set(ctx, @data[i])
          ctx.fill()

        if glyph_props.line_properties.do_stroke
          glyph_props.line_properties.set(ctx, @data[i])
          ctx.stroke()

    select: (xscreenbounds, yscreenbounds) ->
      xscreenbounds = [@plot_view.view_state.sx_to_device(xscreenbounds[0]),
        @plot_view.view_state.sx_to_device(xscreenbounds[1])]
      yscreenbounds = [@plot_view.view_state.sy_to_device(yscreenbounds[0]),
        @plot_view.view_state.sy_to_device(yscreenbounds[1])]
      xscreenbounds = [_.min(xscreenbounds), _.max(xscreenbounds)]
      yscreenbounds = [_.min(yscreenbounds), _.max(yscreenbounds)]
      selected = []
      for i in [0..@sx.length-1]
        if xscreenbounds
          if @sx[i] < xscreenbounds[0] or @sx[i] > xscreenbounds[1]
            continue
        if yscreenbounds
          if @sy[i] < yscreenbounds[0] or @sy[i] > yscreenbounds[1]
            continue
        selected.push(i)
      return selected

    draw_legend: (ctx, x1, x2, y1, y2) ->
      glyph_props = @glyph_props
      line_props = glyph_props.line_properties
      fill_props = glyph_props.fill_properties
      ctx.save()
      reference_point = @get_reference_point()
      if reference_point?
        glyph_settings = reference_point
        data_r = @distance([reference_point], 'x', 'radius', 'edge')[0]
      else
        glyph_settings = glyph_props
        data_r = glyph_props.select('radius', glyph_props).default
      border = line_props.select(line_props.line_width_name, glyph_settings)
      ctx.beginPath()
      d = _.min([Math.abs(x2-x1), Math.abs(y2-y1)])
      d = d - 2 * border
      r = d / 2
      if data_r?
        r = if data_r > r then r else data_r
      ctx.arc((x1 + x2) / 2.0, (y1 + y2) / 2.0, r, 2*Math.PI,false)
      if fill_props.do_fill
        fill_props.set(ctx, glyph_settings)
        ctx.fill()
      if line_props.do_stroke
        line_props.set(ctx, glyph_settings)
        ctx.stroke()

      ctx.restore()

  class Circle extends Glyph.Model
    default_view: CircleView
    type: 'Glyph'

    display_defaults: () ->
      return _.extend(super(), {
        fill_color: 'gray'
        fill_alpha: 1.0
        line_color: 'red'
        line_width: 1
        line_alpha: 1.0
        line_join: 'miter'
        line_cap: 'butt'
        line_dash: []
        line_dash_offset: 0
      })

  return {
    "Model": Circle,
    "View": CircleView,
  }
