undef("isArray")
function isArray(var)
begin
  dim = dimsizes(var)
  ndim = dimsizes(dim)
  if(ndim .eq. 1)
    return(dim .ne. 1)
  else
    return(True)
  end if
end

undef("delete_attrs")
procedure delete_attrs(res:logical,att_name:string)
begin
  do i = 0, dimsizes(att_name)-1
    if(isatt(res,att_name(i)))
      delete(res@$att_name(i)$)
    end if
  end do
end

undef("copy_res_eq_with_index")
procedure copy_res_eq_with_index(res_from:logical, res_to:logical, att:string, index:integer)
begin 
  atts = get_res_eq(res_from, att)
  atts_name = getvaratts(atts)
  do i = 0, dimsizes(atts_name)-1
    att_value := res_from@$atts_name(i)$
    isAttArray = isArray(att_value)
    dim_att = dimsizes(att_value)
    if(isAttArray) then
      if(index .lt. dim_att)
        res_to@$atts_name(i)$ := att_value(index)
      else
        printc("the index is larger than size of the attribute, using the last element: "+att_value(dim_att-1),True)
        res_to@$atts_name(i)$ := att_value(dim_att-1)
      end if
    else
      res_to@$atts_name(i)$ := att_value
    end if
  end do
end

undef("get_res_value_with_index")
function get_res_value_with_index(res:logical, att:string, index:integer, default)
begin
  att_value = get_res_value_keep(res, att, default)
  isAttArray = isArray(att_value)
  dim_att = dimsizes(att_value)
  if(isAttArray) then
    if(index .lt. dim_att)
      return(att_value(index))
    else
      printc("the index is larger than size of the attribute, using the last element: "+att_value(dim_att-1),True)
      return(att_value(dim_att-1))
    end if
  else
    return(att_value)
  end if
end

undef("gsn_panel_return")
function gsn_panel_return(wks:graphic,plot[*]:graphic,dims[*]:integer,\
                          resources:logical)
local res, nrows, ncols, ddims, is_row_spec, row_spec, npanels, nplots, \
      perim_on
begin
  res = get_resources(resources)           ; Make copy of resources
;
; First check if paneling is to be specified by (#rows x #columns) or
; by #columns per row.  The default is rows x columns, unless 
; resource gsnPanelRowSpec is set to True, in which case "dims"
; will represent number of plots per row.
; 
  is_row_spec = get_res_value(res,"gsnPanelRowSpec",False)
;
; Check to see if we have enough plots to fit panels, and vice versa.
;
  ddims = dimsizes(dims)
  if(is_row_spec)
    row_spec = dims
    npanels = 0
    nrows = ddims
    ncols = max(row_spec)
    do i=0,nrows-1
      if(row_spec(i).lt.0)
        print("gsn_panel: Error: you have specified a negative value for the number of plots in a row.")
        exit
      end if
      npanels = npanels + row_spec(i)
    end do
  else
    if(ddims.ne.2)
      print("gsn_panel: Error: for the third argument of gsn_panel, you must either specify # rows by # columns or set gsnPanelRowSpec to True and set the number of plots per row.")
      exit
    end if
    nrows    = dims(0)
    ncols    = dims(1)
    npanels  = nrows * ncols
    row_spec = new(nrows,integer)
    row_spec = ncols
  end if
 
  nplots  = dimsizes(plot)      ; Total number of plots.

  if(nplots.gt.npanels)
    print("gsn_panel: warning: you have more plots than you have panels.")
    print("Only " + npanels + " plots will be drawn.")
    nplots = npanels
  end if

;
; Check for special resources.
; 
  panel_save     = get_res_value_keep(res,"gsnPanelSave",True)
  panel_debug    = get_res_value_keep(res,"gsnPanelDebug",False)
  panel_center   = get_res_value_keep(res,"gsnPanelCenter",True)
  panel_labelbar = get_res_value_keep(res,"gsnPanelLabelBar",False)
  panel_plotid   = get_res_value_keep(res,"gsnPanelScalePlotIndex",-1)
  panel_lbarid   = get_res_value_keep(res,"gsnPanelLabelBarPlotIndex",-1)
  calldraw       = get_res_value_keep(res,"gsnDraw",True)
  callframe      = get_res_value_keep(res,"gsnFrame",True)
  xwsp_perc      = get_res_value_keep(res,"gsnPanelXWhiteSpacePercent",1.)
  ywsp_perc      = get_res_value_keep(res,"gsnPanelYWhiteSpacePercent",1.)
  draw_boxes     = get_res_value_keep(res,"gsnPanelBoxes",False)
  x_lft          = get_res_value_keep(res,"gsnPanelLeft",0.)
  x_rgt          = get_res_value_keep(res,"gsnPanelRight",1.)
  y_bot          = get_res_value_keep(res,"gsnPanelBottom",0.)
  y_top          = get_res_value_keep(res,"gsnPanelTop",1.)
  main_string    = get_res_value_keep(res,(/"gsnPanelMainString","txString"/),"")
  maxbb          = get_bb_res(res)

  lft_pnl        = isatt(res,"gsnPanelLeft")
  rgt_pnl        = isatt(res,"gsnPanelRight")
  bot_pnl        = isatt(res,"gsnPanelBottom")
  top_pnl        = isatt(res,"gsnPanelTop")


;
; Check if a main string has been specified. If so, we need to make sure
; we leave some room for it by computing y_top (if the user hasn't set
; it). Also, we have to check if the font height has been set, because
; this could affect the title position.
; 
  if(main_string.ne."") then
    main_string_on = True
    main_font_hgt  = get_res_value_keep(res,(/"gsnPanelMainFontHeightF","txFontHeightF"/),0.02)
;
; By default, we want a distance of 0.01 between top of title and the
; frame, and a distance of 0.03  between the bottom of the title (txPosYF)
; and the top of the panel box (gsnPanelTop).
;
    if(y_top.eq.1.) then
      if(isatt(res,"gsnPanelMainPosYF"))
        y_top = min((/1.,res@gsnPanelMainPosYF - 0.03/))
      elseif(isatt(res,"txPosYF"))
        y_top = min((/1.,res@txPosYF - 0.03/))
      else
        y_top = min((/1.,0.96-main_font_hgt/))
      end if
    end if
  else
    main_string_on = False
  end if
;
; Calculate number of plot objects that will actually be drawn.
; This include the panel plots, the labelbar (if any), and 
; main string (if any).
;
  nnewplots = nplots
  if(panel_labelbar) then
    is_multi_lb = isArray(panel_lbarid)
    if(is_multi_lb) then
      nnewplots = nnewplots + dimsizes(panel_lbarid)
    else
      nnewplots = nnewplots + 1
    end if
  end if
  if(main_string_on) then
    nnewplots = nnewplots + 1
  end if

  newplots = new(nnewplots,graphic)   ; Create array to save these plots
                                      ; objects.
;
; We only need to set maxbb to True if the plots are being drawn to
; a PostScript or PDF workstation, because the bounding box is already
; maximized for an NCGM/X11 window.
; 
  if(maxbb) then
    class = NhlClassName(wks)
    if(.not.any(class(0).eq.(/"psWorkstationClass", "pdfWorkstationClass", \
                              "documentWorkstationClass"/)))
      maxbb = False
    end if
    delete(class)
  end if
;
; Get some resources for the figure strings, if they exist.
;
  if(isatt(res,"gsnPanelFigureStrings"))
    is_figure_strings = True
    panel_strings = get_res_value(res,"gsnPanelFigureStrings","")      
;
; Get and set resource values for figure strings on the plots.
;
    justs = (/"bottomright", "topright", "topleft", "bottomleft"/)
    paras = (/     1.0,           1.0,      -1.0,       -1.0/)
    orths = (/     1.0,          -1.0,      -1.0,        1.0/)

    amres = get_res_eq(res,"am")
    just = str_lower(get_res_value(res,(/"gsnPanelFigureStringsJust","amJust"/),"bottomright"))
;
; Look for all resources that start with gsnPanelFigureStrings, and replace
; this with just "tx". This is what allows us to sneak in text resources
; and have them only apply to the figure strings, and not the main string.
;
    txres    = get_res_eq_replace(res,"gsnPanelFigureStrings","tx")
    perim_on = get_res_value(txres,"txPerimOn",True)
    bkgrn    = get_res_value(txres,"txBackgroundFillColor",0)
  else
    is_figure_strings = False
  end if
;
; Error check the values that the user has entered, to make sure
; they are valid. 
;  
  if(xwsp_perc.lt.0.or.xwsp_perc.ge.100.)
    print("gsn_panel: Warning: attribute gsnPanelXWhiteSpacePercent must be >= 0 and < 100.")
    print("Defaulting to 1.")
    xwsp_perc = 1.
  end if

  if(ywsp_perc.lt.0.or.ywsp_perc.ge.100.)
    print("gsn_panel: Warning: attribute gsnPanelYWhiteSpacePercent must be >= 0 and < 100.")
    print("Defaulting to 1.")
    ywsp_perc = 1.
  end if

  if(x_lft.lt.0..or.x_lft.ge.1.)
    print("gsn_panel: Warning: attribute gsnPanelLeft must be >= 0.0 and < 1.0")
    print("Defaulting to 0.")
    x_lft = 0.0
  end if

  if(x_rgt.le.0..or.x_rgt.gt.1.)
    print("gsn_panel: Warning: attribute gsnPanelRight must be > 0.0 and <= 1.0")
    print("Defaulting to 1.")
    x_rgt = 1.0
  end if

  if(y_top.le.0..or.y_top.gt.1.)
    print("gsn_panel: Warning: attribute gsnPanelTop must be > 0.0 and <= 1.0")
    print("Defaulting to 1.")
    y_top = 1.0
  end if

  if(y_bot.lt.0..or.y_bot.ge.1.)
    print("gsn_panel: Warning: attribute gsnPanelBottom must be >= 0.0 and < 1.0")
    print("Defaulting to 0.")
    y_bot = 0.0
  end if

  if(x_rgt.le.x_lft)
    print("gsn_panel: Error: attribute gsnPanelRight ("+x_rgt+") must be greater")
    print("than gsnPanelLeft ("+x_lft+").")
    exit
  end if

  if(y_top.le.y_bot)
    print("gsn_panel: Error: attribute gsnPanelTop ("+y_top+") must be greater")
    print("than gsnPanelBottom ("+y_bot+").")
    exit
  end if

;
; Get the plot object id that we will use to determine the scale factor
; for resizing all of the plots. If gsnPanelScalePlotId was set
; (panel_id), then use this. Otherwise, we will start at the first
; plot and keep going until we find a "valid" (non missing) plot.
;
; We assume all plots are the same size, so if we get the size of
; one of them, then this should represent the size of the rest
; of them. Also, count the number of non-missing plots for later.
;
  ind_nomsg = ind(.not.ismissing(plot(0:nplots-1)))
  if(all(ismissing(ind_nomsg))) then
    print("gsn_panel: Error: all of the plots passed to gsn_panel appear to be invalid")
    exit
  end if
  if(panel_plotid.ge.0.and.panel_plotid.le.(nplots-1).and. \
     .not.ismissing(plot(panel_plotid))) then
    valid_plot = panel_plotid
  else
    valid_plot = ind_nomsg(0)
  end if
;
; In NCL V6.6.0, we added a new resource, gsnPanelLabelBarPlotIndex 
; which allows you to specify which plot to base the panel labelbar
; on. If none is specified, then the first non-missing plot in the
; list will be used.
;

  bb     = NhlGetBB(plot(valid_plot))   ; Get bounding box of this plot
  top    = bb(0)
  bottom = bb(1)
  left   = bb(2)
  right  = bb(3)
  delete(bb)
  nvalid_plots = dimsizes(ind_nomsg)
  delete(ind_nomsg)

  if(panel_debug) then
    print("There are " + nvalid_plots + " valid plots out of " + nplots + " total plots")
  end if

;
; Get the type of plots we have. "plot" can be a map, in which case
; the contour, vector, streamine plot overlaid on it will be indicated
; by an attribute, for example, "plot@contour" or "plot@vector".
;
  new_plot     = get_plot_not_loglin(plot(valid_plot))


;
; Get the font height of a particular plot element, so we can
; use this for panel plot elements, like the size of the 
; common labelbar labels, the main title, etc.
;
  if(is_figure_strings.or.panel_labelbar) then
    if(new_plot@plot_type.eq."contour") then
      getvalues new_plot
        "cnInfoLabelFontHeightF" : font_height
      end getvalues
    elseif(new_plot@plot_type.eq."vector") then
      getvalues new_plot
        "vcRefAnnoFontHeightF" : font_height
      end getvalues
    elseif(new_plot@plot_type.eq."xy") then
      getvalues new_plot
        "tiXAxisFontHeightF" : font_height
      end getvalues
      font_height = 0.6*font_height
    elseif(new_plot@plot_type.eq."streamline") then
;
; There's no equivalent font height resource for streamline to 
; retrieve, so just set it here.
;
      font_height = 0.01
    else
      font_height = 0.01
    end if
;
; Use this font height for the panel figure strings, if any, unless
; the user has set gsnPanelFigureStringsFontHeightF.
;
    pfont_height = get_res_value(res,"gsnPanelFigureStringsFontHeightF",\
                                 font_height)
  end if


;
; This section calculates the scale factor needed to rescale the 
; plots so they fit on one page.  It has to account for white 
; space between each plot, and space for the labelbar and main title, 
; if any.
;
; plot_width  : total width of plot with all of its annotations
; plot_height : total height of plot with all of its annotations
; total_width : plot_width plus white space on both sides
; total_height: plot_height plus white space on top and bottom
;
  plot_width  = right - left     ; Calculate total width of plot.
  plot_height = top - bottom     ; Calculate total height of plot.

  xwsp = xwsp_perc/100. * plot_width  ; White space is a percentage of total
  ywsp = ywsp_perc/100. * plot_height ; width and height.

  total_width  = 2.*xwsp + plot_width   ; Calculate total width and height
  total_height = 2.*ywsp + plot_height  ; with white space added.
;
; If we are putting a global labelbar at the bottom (right), make 
; it 0.2x the height (width) of the plot.
;
  lbhor = True
  if(panel_labelbar) then
    lbres = get_res_eq(res,(/"lb","pmLabelBar","vp"/))  ; Get labelbar resources.
    if(check_attr_enum_value(lbres,"lbOrientation","vertical")) then
      lbhor = False
      labelbar_width = 0.20 * plot_width + 2.*xwsp
;
; Adjust height depending on whether we have one row or multiple rows.
;
      if(nplots.gt.1.and.nrows.gt.1) then
        labelbar_height  = (nrows-1) * (2.*ywsp + plot_height)
      else
        labelbar_height  = plot_height
      end if
    else         
      set_attr(lbres,"lbOrientation","Horizontal")

      labelbar_height = 0.20 * plot_height + 2.*ywsp
;
; Adjust width depending on whether we have one column or multiple 
; columns.
;
      if(nplots.gt.1.and.ncols.gt.1) then
        labelbar_width  = (ncols-1) * (2.*xwsp + plot_width)
      else
        labelbar_width  = plot_width
      end if
    end if
  else
    labelbar_height = 0.
    labelbar_width  = 0.
  end if
;
; We want:
;
;   ncols * scale * total_width  <= x_rgt - x_lft (the viewport width)
;   nrows * scale * total_height <= y_top - y_bot (the viewport height)
;   [or scale * (nrows * total_height + labelbar_height) if a labelbar
;    is being drawn]
;
; By taking the minimum of these two, we get the scale
; factor that we need to fit all plots on a page.
;
  xrange = x_rgt - x_lft
  yrange = y_top - y_bot

  if(lbhor) then
;
; Previously, we used to include xrange and yrange as part of the min
; statement. This seemed to cause problems if you set one of
; gsnPanelTop/Bottom/Right/Left however, so I removed it.
;
    row_scale = yrange/(nrows*total_height+labelbar_height)
    col_scale = xrange/(ncols*total_width)
    scale     = min((/col_scale,row_scale/))
    yrange    = yrange - scale * labelbar_height
  else
;
; See above comments.
;
    row_scale = yrange/(nrows*total_height)
    col_scale = xrange/(ncols*total_width+labelbar_width)
    scale     = min((/col_scale,row_scale/))
    xrange    = xrange - scale * labelbar_width
  end if
  new_plot_width  = scale*plot_width    ; Calculate new width
  new_plot_height = scale*plot_height   ; and height.

  xwsp = xwsp_perc/100. * new_plot_width   ; Calculate new white space.
  ywsp = ywsp_perc/100. * new_plot_height

  new_total_width  = 2.*xwsp + new_plot_width  ; Calculate new total width
  new_total_height = 2.*ywsp + new_plot_height ; and height w/white space.

  xsp = xrange - new_total_width*ncols  ; Calculate total amt of white space
  ysp = yrange - new_total_height*nrows ; left in both X and Y directions.

  getvalues plot(valid_plot)
    "vpXF"      : vpx
    "vpYF"      : vpy
    "vpWidthF"  : vpw
    "vpHeightF" : vph
  end getvalues

  dxl = scale * (vpx-left)           ; Distance from plot's left
                                     ; position to its leftmost annotation
  dxr = scale * (right-(vpx+vpw))    ; Distance from plot's right
                                     ; position to its rightmost annotation
  dyt = scale * (top-vpy)            ; Distance from plot's top
                                     ; position to its topmost annotation.
  dyb = scale * ((vpy-vph)-bottom)   ; Distance from plot's bottom
                                     ; position to its bottommost annotation.

  ypos = y_top - ywsp - dyt -(ysp/2.+new_total_height*ispan(0,nrows-1,1))

;
; If we have figure strings, then determine white spacing around 
; the text box.
;
  if(is_figure_strings) then
    fig_index = ind(just.eq.justs)
    if(ismissing(fig_index))
      fig_index = 0
      just      = justs(fig_index)
    end if

    len_pct = 0.025           ; Percentage of width/height of plot
                              ; for white space around text box.
    if(vpw .lt. vph) then
      wsp_hpct = (len_pct * vpw) / vph
      wsp_wpct = len_pct
    else
      wsp_hpct = len_pct
      wsp_wpct = (len_pct * vph) / vpw
    end if
    para  = get_res_value(amres,"amParallelPosF",  paras(fig_index) * \
                                                   (0.5 - wsp_wpct))
    orth  = get_res_value(amres,"amOrthogonalPosF", orths(fig_index) * \
                                                    (0.5 - wsp_hpct))
  end if
;
; Variable to store rightmost location of rightmost plot, and topmost
; location of top plot.
;
  max_rgt = 0.
  max_top = 0.
;
; Variable to hold original viewport coordinates, and annotations (if
; they exist).
;
  old_vp = new((/nplots,4/),float)
  anno   = new(nplots, graphic)
;
; Loop through each row and create each plot in the new scaled-down
; size. We will draw plots later, outside the loop.
;
  num_plots_left = nplots
  nplot          = 0
  nr             = 0
  added_anno     = False             ; For figure strings

  do while(num_plots_left.gt.0)
    vpy_new = ypos(nr)
    new_ncols = min((/num_plots_left,row_spec(nr)/))

    if(panel_center)
      xsp = xrange - new_total_width*new_ncols  ; space before plots. 
    else
      xsp = xrange - new_total_width*ncols      ; space before plots. 
    end if
;
; Calculate new x positions.
;
    xpos = x_lft + xwsp + dxl +(xsp/2.+new_total_width*ispan(0,new_ncols-1,1))

    do nc = 0,new_ncols-1
      vpx_new = xpos(nc)
      if(.not.ismissing(plot(nplot)))
        pplot = plot(nplot)
        getvalues pplot
          "vpXF"      : old_vp(nplot,0)
          "vpYF"      : old_vp(nplot,1)
          "vpWidthF"  : old_vp(nplot,2)
          "vpHeightF" : old_vp(nplot,3)
        end getvalues
;
; If user setting gsnPanelXF or gsnPanelYF resources, then use these instead.
; They must be set as an array of the same length as you have plots.
; If any of these are negative, then use the calculated values.
;
        vpx_new = xpos(nc)
        if(isatt(res,"gsnPanelXF").and.dimsizes(res@gsnPanelXF).eq.nplots.and.\
          res@gsnPanelXF(nplot).ge.0.and.res@gsnPanelXF(nplot).le.1) then
          vpx_new = res@gsnPanelXF(nplot)
        end if

        vpy_new = ypos(nr)
        if(isatt(res,"gsnPanelYF").and.dimsizes(res@gsnPanelYF).eq.nplots.and.\
          res@gsnPanelYF(nplot).ge.0.and.res@gsnPanelYF(nplot).le.1) then
          vpy_new = res@gsnPanelYF(nplot)
        end if
;
; Print out values used.
;
        if(panel_debug) then
          print("-------Panel viewport values for each plot-------")
          print("    plot #" + nplot)
          print("    new x,y      = " + vpx_new + "," + vpy_new)
          print("    orig wdt,hgt = " + old_vp(nplot,2) + "," + old_vp(nplot,3))
          print("    new wdt,hgt  = " + scale*old_vp(nplot,2) + "," + scale*old_vp(nplot,3))
        end if

        setvalues pplot
          "vpXF"      : vpx_new
          "vpYF"      : vpy_new
          "vpWidthF"  : scale*old_vp(nplot,2)
          "vpHeightF" : scale*old_vp(nplot,3)
        end setvalues

        if(is_figure_strings) then
          if(nplot .lt. dimsizes(panel_strings).and. \
            panel_strings(nplot).ne."")
            text = create "string" textItemClass wks
              "txString"              : panel_strings(nplot)
              "txFontHeightF"         : pfont_height
              "txPerimOn"             : perim_on
              "txBackgroundFillColor" : bkgrn
            end create
;
; Set some text resources for figure strings, if any.
;
            attsetvalues_check(text,txres)
;
; Add annotation to plot.
;
            anno(nplot) = NhlAddAnnotation(pplot,text)
            added_anno = True
            setvalues anno(nplot)
              "amZone"           : 0
              "amJust"           : just
              "amParallelPosF"   : para
              "amOrthogonalPosF" : orth
              "amResizeNotify"   : True
            end setvalues
            attsetvalues_check(anno(nplot),amres)
            delete(text)
          end if
        end if
;
; Save this plot.
;
        newplots(nplot) = pplot
;
; Info for possible labelbar or main_string
;
        if(main_string_on.or.panel_labelbar.or.draw_boxes) then
          bb  = NhlGetBB(pplot) ; Get bounding box of plot.
          top = bb(0)
          lft = bb(2)
          bot = bb(1)
          rgt = bb(3)
          max_rgt = max((/rgt,max_rgt/))
          max_top = max((/top,max_top/))

          if(draw_boxes)
            draw_bb(pplot,False)
          end if
        end if
      end if      ;   if(.not.ismissing(plot(nplot)))
;
; Retain the smallest and largest x and y positions.
;
      if(nplot.eq.0) then
        min_xpos = vpx_new
        max_xpos = vpx_new
        min_ypos = vpy_new
        max_ypos = vpy_new
      else
        min_xpos = min( (/vpx_new,min_xpos/) )
        max_xpos = max( (/vpx_new,max_xpos/) )
        min_ypos = min( (/vpy_new,min_ypos/) )
        max_ypos = max( (/vpy_new,max_ypos/) )
      end if

      nplot = nplot + 1    ; Increment plot counter
    end do  ; end of columns

    num_plots_left = nplots - nplot
    nr = nr + 1   ; increment rows
    delete(xpos)
  end do    ; end of plots

;
; Print min/max information.
;
  if(panel_debug) then
    print("-------min/max X,Y viewport positions for plots-------")
    print("min/max x viewport position = " + min_xpos + "/" + max_xpos)
    print("min/max y viewport position = " + min_ypos + "/" + max_ypos)
  end if
;
; Calculate the biggest rescaled widths and heights (technically, they
; should all be the same).  These values will be used a few times 
; throughout the rest of the code.
;
  scaled_width  = scale*max(old_vp(:,2))
  scaled_height = scale*max(old_vp(:,3))
if(panel_labelbar) then
  ;
  ; Set labelbar height, width, and font height.
  ;
    labelbar_height      = scale * labelbar_height
    labelbar_width       = scale * labelbar_width
    labelbar_font_height = font_height
    tem = lbres
      ; tem@lbLabelFontHeightF = get_res_value_keep()
    ; if(isatt(lbres,"lbLabelFontHeightF"))
    ;   tem@lbLabelFontHeightF = lbres@lbLabelFontHeightF
    ;   delete(lbres@lbLabelFontHeightF)
    ; end if
  ; draw multi labelbar
  do i = 0, dimsizes(panel_lbarid)-1
    lbres = tem
    if(panel_lbarid(i).ge.0.and.panel_lbarid(i).le.(nplots-1).and. \
       .not.ismissing(plot(panel_lbarid(i)))) then
      valid_plot_lbar = panel_lbarid(i)
    else
      valid_plot_lbar = valid_plot
    end if
    new_plot_lab = get_plot_labelbar(plot(valid_plot_lbar))
    ;---If plot type is unknown or xy, then we can't create a labelbar.
    if(panel_labelbar.and.(new_plot_lab@plot_type.eq."unknown".or.  new_plot_lab@plot_type.eq."xy")) then
      print("Warning: gsn_panel: unrecognized plot type for getting   labelbar information. Ignoring labelbar request.")
      panel_labelbar = False
    end if
  ;---Get information needed for reconstructing a labelbar from scratch.
    lbar_list = get_panel_labelbar_info(new_plot_lab)
    panel_labelbar = lbar_list[0]
    lb_label_strings = lbar_list[1]
    lb_fill_colors = lbar_list[2]
    lb_fill_patterns = lbar_list[3]
    lb_fill_scales = lbar_list[4]
    lb_mono_fill_color = lbar_list[5]
    lb_mono_fill_pattern = lbar_list[6]
    lb_mono_fill_scale = lbar_list[7]
    lb_end_style = lbar_list[8]
    lb_cap_style = lbar_list[9]
    lb_label_alignment = lbar_list[10]
    lb_subset_stuff = lbar_list[11]
  ;
  ; Check if a labelbar is to be drawn.
  ;
    lbres@lbLabelFontHeightF := labelbar_font_height
    lbres@lbLabelAlignment := lb_label_alignment
    lbres@lbMonoFillColor := lb_mono_fill_color
    lbres@vpWidthF = get_res_value_with_index(lbres,  "pmLabelBarWidthF",i,labelbar_width)
    lbres@vpHeightF = get_res_value_with_index(lbres, "pmLabelBarHeightF",i,labelbar_height)
    if(isvar("lb_cap_style"))
      lbres@lbBoxEndCapStyle := lb_cap_style
    end if

    ; set_attr(lbres,"lbMonoFillColor",lb_mono_fill_color)
    if(.not.lb_mono_fill_pattern)
      set_attr(lbres,"lbMonoFillPattern", False)
      set_attr(lbres,"lbFillPatterns", lb_fill_patterns)
    end if
    if(.not.lb_mono_fill_scale)
      set_attr(lbres,"lbMonoFillScale", False)
      set_attr(lbres,"lbFillScales", lb_fill_scales)
    end if
      lbres@EndStyle = lb_end_style
  ; Set position of labelbar depending on whether it's horizontal or
  ; vertical.
    if(lbhor)
      lbres@vpYF = max ((/ywsp+labelbar_height,bot-ywsp/))
      if(ncols.eq.1.and.lbres@vpWidthF.le.scaled_width)
        lbres@vpXF = min_xpos + (scaled_width-lbres@vpWidthF)/2.
      else
        tmp_range = x_rgt - x_lft
        lbres@vpXF = x_lft + (tmp_range - lbres@vpWidthF)/2.
      end if
      lbres@vpYF = lbres@vpYF + get_res_value_with_index(lbres, "pmLabelBarOrthogonalPosF",i,0)
      lbres@vpXF = lbres@vpXF + get_res_value_with_index(lbres, "pmLabelBarParallelPosF",i,0)
    else
      lbres@vpXF = min ((/1.-(xwsp+labelbar_width),max_rgt+xwsp/))
      if(nrows.eq.1.and.lbres@vpHeightF.le.scaled_height)
        lbres@vpYF = max_ypos-(scaled_height - lbres@vpHeightF)/2.
      else
        tmp_range = y_top - y_bot
        lbres@vpYF = y_top-(tmp_range - lbres@vpHeightF)/2.
      end if
      lbres@vpXF = lbres@vpXF + get_res_value_with_index(lbres, "pmLabelBarOrthogonalPosF",i,0.)
      lbres@vpYF = lbres@vpYF + get_res_value_with_index(lbres, "pmLabelBarParallelPosF",i,0.)
    end if

  ;   if(isvar("lb_levels"))
  ;     lb_label_strings = fix_zero_contour(lb_levels)   ; Make sure  level 0 is not something like 1e-8
  ;   end if
      lbres@SubsetStuff = lb_subset_stuff
  ;---Create the labelbar.
    copy_res_eq_with_index(tem,lbres,"lb",i)
    if(isatt(lbres,"lbTitleString"))
      print(lbres@lbTitleString .eq. "")
      lbTitleOn = False
    end if
    if(isatt(lbres,"lbLabelFormat"))
      lb_values = stringtofloat(lb_label_strings)
      lb_label_strings := sprintf(lbres@lbLabelFormat, lb_values)
    end if
    if(isatt(lbres,"lbLabelStrings"))
      lb_label_strings := res@lbLabelStrings
    end if
    res_to_delete = (/"pmLabelBarHeightF","pmLabelBarWidthF","pmLabelBarOrthogonalPosF","pmLabelBarParallelPosF","lbLabelFormat"/)
    delete_attrs(lbres,res_to_delete)
    newplots(nplot) = create_labelbar(wks,dimsizes(lb_fill_colors), lb_fill_colors, lb_label_strings,lbres)
    nplot = nplot + 1
  end do
end if
delete([/top,bottom,right,left/])
; lbres@lbLabelFontHeightF = tem@lbLabelFontHeightF
;
; Create the main string, if exists.
;
  if(main_string_on) then
    y_top     = min((/y_top,max_top/))
    main_ypos = get_res_value_keep(res,(/"gsnPanelMainPosYF","txPosYF"/),y_top + 0.03)
    main_xpos = get_res_value_keep(res,(/"gsnPanelMainPosXF","txPosXF"/),0.5)
    if(panel_debug) 
      print("-------Panel title values-------")
      print("    title                = " + main_string)
      print("    top of paneled plots = " + y_top)
      print("    y location of title  = " + main_ypos)
    end if

    if((main_ypos+main_font_hgt).gt.1)
       print("gsn_panel: Warning: font height (" + main_font_hgt + ") of main string is too large to fit in space provided. Either decrease font size or set gsnPanelTop.")
    end if

;
; Look for all resources that start with gsnPanelMain, and replace
; this with just "tx". This is is for backwards compatibility in
; V6.3.0 and earlier, where "gsnPanelMain" resources weren't
; recognized, but "tx" resources were.
;
    mntxres               = get_res_eq_replace(res,"gsnPanelMain","tx")
    mntxres               = True
    mntxres@gsnDraw       = False
    mntxres@gsnFrame      = False
    mntxres@txFontHeightF = main_font_hgt
    newplots(nplot) = gsn_create_text_ndc(wks, main_string, main_xpos, \
                      main_ypos, mntxres)
    mntxres = get_res_eq(res,"tx")   ; This is a kludge to remove any tx*** resources from "res"
  end if
;
; If some of the paneled plots are missing, we need to take these into
; account so that the maximization will still work properly.  For
; example, if we ask for a 2 x 2 configuration, but plots 1 and 3 (the
; rightmost plots) are missing, then we need to set a new resource
; called gsnPanelInvsblRight to whatever approximate X value it 
; would have been if those plots weren't missing.  Setting just gsnPanelRight
; won't work in this case, because that resource is only used to control
; where the plots are drawn in a 0 to 1 square, and *not* to indicate the
; rightmost location of the rightmost graphic (which could be a vertical 
; labelbar).
;
; Not dealing with the case of gsnPanelRowSpec = True yet.
;  
  if(.not.is_row_spec) then
    newbb  = new((/dimsizes(newplots),4/),float)
;
; Have to deal with special case of only having one plot.
;
    if(dimsizes(newplots).eq.1)
      newbb(0,:)  = NhlGetBB(newplots)  ; Get bounding boxes of plots, plus
                                        ; labelbar and text string if they
                                        ; exist.  
    else
      newbb  = NhlGetBB(newplots)       ; Get bounding boxes of plots, plus
                                        ; labelbar and text string if they
                                        ; exist.  
    end if
    getvalues newplots(valid_plot)
      "vpXF"      : vpx
      "vpYF"      : vpy
      "vpWidthF"  : vpw
      "vpHeightF" : vph
    end getvalues
    dxl = vpx-newbb(valid_plot,2)
    dxr = newbb(valid_plot,3)-(vpx+vpw)
    dyt = (newbb(valid_plot,0)-vpy)
    dyb = (vpy-vph)-newbb(valid_plot,1)
;
; Get largest bounding box that encompasses all non-missing graphical
; objects.
;
    newtop = max(newbb(:,0))
    newbot = min(newbb(:,1))
    newlft = min(newbb(:,2))
    newrgt = max(newbb(:,3))
    delete(newbb)

;
; This section checks to see if all plots along one side are 
; missing, because if they are, we have to pretend like they
; are just invisible (i.e. do the maximization as if the invisible
; plots were really there).  This section needs to take
; place even if no plots are missing, because it's possible the
; user specified fewer plots than panels.
;
    xlft = min_xpos - dxl
    xrgt = max_xpos + vpw + dxr
    xtop = max_ypos + dyt
    xbot = min_ypos - vph - dyb
    if(.not.rgt_pnl.and.xrgt.gt.newrgt) then
      maxbb@gsnPanelInvsblRight = xrgt
      if(panel_debug)
        print("gsnPanelInvsblRight = " + maxbb@gsnPanelInvsblRight)
      end if
    end if

    if(.not.lft_pnl.and.xlft.lt.newlft) then
      maxbb@gsnPanelInvsblLeft = xlft
      if(panel_debug)
        print("gsnPanelInvsblLeft = " + maxbb@gsnPanelInvsblLeft)
      end if
    end if

    if(.not.top_pnl.and.xtop.gt.newtop) then
      maxbb@gsnPanelInvsblTop = xtop
      if(panel_debug)
        print("gsnPanelInvsblTop = " + maxbb@gsnPanelInvsblTop)
      end if
    end if

    if(.not.bot_pnl.and.xbot.lt.newbot) then
      maxbb@gsnPanelInvsblBottom = xbot
      if(panel_debug)
        print("gsnPanelInvsblBottom = " + maxbb@gsnPanelInvsblBottom)
      end if
    end if
  end if
; 
; Draw plots plus labelbar and main title (if they exists). This is
; also where the plots will be maximized for PostScript output,
; if so indicated.
;
  if(draw_boxes)
    draw_and_frame(wks,newplots,calldraw,False,1,maxbb)
  else
    draw_and_frame(wks,newplots,calldraw,callframe,1,maxbb)
  end if  
;
; Draw bounding boxes around each plot object for debugging purposes.
;
  if(draw_boxes)
    do i=0,dimsizes(newplots)-1
      if(.not.ismissing(newplots(i)))
        draw_bb(newplots(i),False)
      end if
    end do
    if(callframe) then
      frame(wks)
    end if
  end if
;
; Debug information
;
  if(panel_debug) then
    bb_dbg = NhlGetBB(newplots)
    if(dimsizes(newplots).gt.1) then
      print("-------min/max NDC values for all objects in panel-------")
      print("min/max x position = " + min(bb_dbg(:,2)) + "/" + max(bb_dbg(:,3)))
      print("min/max y position = " + min(bb_dbg(:,1)) + "/" + max(bb_dbg(:,0)))
    else
      print("-------min/max NDC values for the object in panel-------")
      print("min/max x position = " + min(bb_dbg(2)) + "/" + max(bb_dbg(3)))
      print("min/max y position = " + min(bb_dbg(1)) + "/" + max(bb_dbg(0)))
    end if
    delete(bb_dbg)
  end if
    
;
; Restore plots to original size.
;
  if(.not.panel_save) then
    do i=0,nplots-1
      if(.not.ismissing(plot(i)))
        if(added_anno.and..not.ismissing(anno(i)))
          NhlRemoveAnnotation(plot(i),anno(i))
        end if
        setvalues plot(i)
          "vpXF"      : old_vp(i,0)
          "vpYF"      : old_vp(i,1)
          "vpWidthF"  : old_vp(i,2)
          "vpHeightF" : old_vp(i,3)
        end setvalues
      end if
    end do
  end if

  return(newplots)
end
