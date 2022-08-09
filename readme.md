# 支持多色标的gsn_panel

#### 动机：

   原来的`gsn_panel`函数只能添加一个总的色标，对于需要两个色标的情况（如下图，两张子图使用一个色标），要么在子图里面直接画色标，要么调用两次`gsn_panel`（需要额外设置多个属性），总的来讲都有些麻烦，于是去扒了一下源码，修改了部分功能，使其支持多个色标（理论上无数个都可以）。

![Image.png](example.png)

#### 使用方法：

   无需对代码做大量修改，下载`gsn_panel.ncl`，如果跟你的主代码文件在同一个目录下，那么在你主代码第一行（begin）前，添加：`load "gsn_panel.ncl"`即可

   也可以放在某个路径下，使用绝对路径`load "your_path/gsn_panel.ncl"`，即可。

#### 原理：

   `gsn_panel`函数只是直接调用了`gsn_panel_return`这一函数，`gsn_panel.ncl`会覆盖`gsn_panel_return`，取消加载该文件后，就会默认使用原有的函数

```haskell
undef("gsn_panel")
procedure gsn_panel(wks:graphic,plot[*]:graphic,dims[*]:integer,\
                    resources:logical)
local res2
begin
  res2 = get_resources(resources)
  set_attr(res2,"gsnPanelSave",False )
  plots = gsn_panel_return(wks,plot,dims,res2)
end
```

#### 更新内容：

   增加`lbLabelFormat`属性，如`"%0.1f"`表示保留小数点后一位

   通过`gsnPanelLabelBarPlotIndex`指定绘制多个子图的`labelbar`，如`(/0,1/)`，表示绘制两个`labelbar`, 分别使用第一个和第二个子图的色标信息

   修改后支持多值的属性：

   若某个属性只有一个值，则为所有`labelbar`都指定该属性

   举个🌰：

      `resp@pmLabelBarWidthF = 0.5`表示所有`labelbar`的宽度为0.5

      `resp@pmLabelBarWidthF = (/0.3,0.7/)`表示所有第一个`labelbar`的宽度为0.3，第二个`labelbar`的宽度为0.7

   属性的值请尽量保持使用单个值或者与`labelbar`个数相同的数组，对于其他情况的处理：

      若数组大小大于`labelbar`个数，如指定2个`labelbar`，但`pmLabelBarWidthF`给了三个值，则会按顺序赋值，多出来的值不会生效

      若数组大小小于`labelbar`个数，如指定3个`labelbar`，但`pmLabelBarWidthF`只给了两个值，则按顺序赋值，缺少的值直接使用数组的最后一个值

#### 目前支持多值的属性（理论上`lb`开头的都支持，没有测试）：

| 属性                       | 备注                                       |
| ------------------------ | ---------------------------------------- |
| pmLabelBarWidthF         |                                          |
| pmLabelBarHeightF        |                                          |
| pmLabelBarParallelPosF   |                                          |
| pmLabelBarOrthogonalPosF |                                          |
| lbLabelFontHeightF       |                                          |
| lbLabelFormat            |                                          |
| lbLabelAlignment         |                                          |
| lbBoxEndCapStyle         |                                          |
| lbMonoFillColor          |                                          |
| lbTitleOn                | 如果lbTitleString的值为"", 则lbTitle也会设置成False |
| lbTitleString            |                                          |
| lbTitlePosition          |                                          |
| lbTitleDirection         |                                          |
| lbTitleFontHeightF       |                                          |
| lbTitleOffsetF           |                                          |


