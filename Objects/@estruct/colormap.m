function h = colormap(varargin)
% COLORMAP Show multiple 2D objects with different colormaps.
%   H=COLORMAP(Z1, Z2, ...) plots series of 2D objects, each with a different
%   colormap. Surface handles are returned.
%
%   H=COLORMAP(Z1,CM1, Z2,CM2, ...) produces surfaces with different colormaps.
%   2D object Z1 is plotted as a surface coloured with map CM1 (Nx3), ...
%
%   H=COLORMAP(..., OPTIONS) specifies the type of plot rendering (same as used 
%   Any string argument will be interpreted as an 'option' for the 2D estruct/plot
%
%                 surf, mesh, contour, contour3, surfc, surfl, contourf
%                 plot3, scatter3 (colored points), stem3, pcolor, waterfall
%                 flat, interp, faceted (for shading), view2, view3
%                 transparent, light, clabel, colorbar, shifted (overlayed 2D)
%                 axis tight, axis auto, hide_axes (compact layout)
%                 painters (bitmap drawing), zbuffer (vectorial drawing)
%                 whole (do not reduce large object size for plotting)
%
%   In addition, the 'log' option can be used to employ a log-scale color set
%   which enhances contrast on low signal values in the plot.
%
%   Available colormaps are:
%    hsv        - Hue-saturation-value color map.
%    hot        - Black-red-yellow-white color map.
%    gray       - Linear gray-scale color map.
%    bone       - Gray-scale with tinge of blue color map.
%    copper     - Linear copper-tone color map.
%    pink       - Pastel shades of pink color map.
%    white      - All white color map.
%    flag       - Alternating red, white, blue, and black color map.
%    lines      - Color map with the line colors.
%    colorcube  - Enhanced color-cube color map.
%    vga        - Windows colormap for 16 colors.
%    jet        - Variant of HSV.
%    prism      - Prism color map.
%    cool       - Shades of cyan and magenta color map.
%    autumn     - Shades of red and yellow color map.
%    spring     - Shades of magenta and yellow color map.
%    winter     - Shades of blue and green color map.
%    summer     - Shades of green and yellow color map.
%
% Example: a=estruct(peaks); h=colormap(a,jet,a+1,hsv,'log transparent'); ...
%          tf = all(ishandle(h)); delete(gcf); tf
% Version: $Date$ $Version$ $Author$
% See also estruct, estruct/plot, estruct/surf, estruct/caxis

tic
z=[]; cm = []; options='';
for index=1:length(varargin)
  this = varargin{index};
  if     isa(this, 'estruct') % objects to plot (single or array)
    for n=1:numel(this), z = [ z this(n) ]; end
  elseif ~isa(this, 'estruct') && isnumeric(this) && size(this,2)==3 % colormap matrix
    cm = [ cm {this} ];
  elseif ischar(this), options=[ options ' ' this ]; 
  end
end
clear varargin

if prod(size(z(1))) > 1e6 
  if isempty([ strfind(options,'whole') strfind(options,'full') ])
    estruct_private_warning(mfilename, [ 'Object ' z(1).Tag ' "' z(1).Title '" is large (numel=' num2str(prod(size(z(1)))) ...
      ').\n\tNow rebinning for display purposes with e.g. z=reducevolume(z);' ...
      '\n\tUse e.g colormap(z, ''whole'') to plot the whole data set and be able to zoom tiny regions.' ]);
    z=reducevolume(z);
  end
end

% default colormaps at the end in case too few are defined
if length(cm) < numel(z)
  cm_list={'hsv' 'jet' 'hot' 'cool' 'autumn' 'spring' 'winter' 'summer' 'copper' 'pink' 'gray' 'bone'  };
  for index=(length(cm)+1):numel(z)
    this_cm = feval( cm_list{rem(index,length(cm_list))+1}, 64 );
    cm= [ cm {this_cm}  ];
  end
  clear this_cm
end

% Build the actual colormap by catenation
if numel(cm) > 1
  cmap = cat(1, cm{:});
else
  cmap=cm{1};
end

% Now we make up the color indices.
sumcm = 0;
ci= {};
for index=1:numel(z)
  if ndims(z(index))~=2, continue; end   % only for 2D objects
  % compute local colormap so that it matches the object values
  this = double(z(index)); 
  % do we need log scale color map ? (to enhance low signal)
  if ~isempty(strfind(options, 'log'))
    if any(this < 0) this = this-min(this(:)); end
    this_min=min(this(find(this > 0)));
    this(find(this<=0)) = this_min/2;
    this = log(this);
  end
  zscale = linspace(min(this(:)),max(this(:)), size(cm{index},1));
  cindex = zeros(size(this));
  % count elements which are lower than each colormap value zscale
  
  for k=1:length(zscale)
    to_add         = find(zscale(k)<=this);
    cindex(to_add) = cindex(to_add)+1;
  end
  % sum up all colormaps on top of each other
  cindex    = cindex+sumcm;
  ci{index} = cindex;
  sumcm     = sumcm+size(cm{index},1);
  
  clear this cindex zscale
end
clear cm

% And now we make the surfaces
h = surf(z, options);

for index=1:numel(z)
  if index==1
    this = z(index);
    title(title(this));
    xlabel(xlabel(this));
    if ndims(this) >= 2, ylabel(ylabel(this)); end
    clear this
  end
  if ndims(z(index))~=2, continue; end   % only for 2D objects
  try
    set(h(index), 'CDataMapping','direct', 'CData', ci{index});
  end
  
end

colormap(cmap);


