function [varargout]=plotfkarf(arf,varargin)
%PLOTFKARF    Plots an fk array response function
%
%    Usage:    h=plotfkarf(arf)
%              h=plotfkmap(arf,fgcolor,bgcolor)
%              h=plotfkmap(arf,fgcolor,bgcolor,h)
%
%    Description: H=PLOTFKARF(ARF) plots a slowness map using the struct
%     ARF which was output from FKARF.  See FKARF for details on the
%     struct.  This is mainly so you can save the results and replot them
%     later (because FKARF is slow).  H is the handle to the axes that the
%     map was plotted in.
%
%     H=PLOTFKARF(ARF,FGCOLOR,BGCOLOR) specifies the foreground and
%     background colors of the plot.  The default is 'w' for FGCOLOR and
%     'k' for BGCOLOR.  Note that if one is specified and the other is not,
%     an opposing color is found using INVERTCOLOR.  The color scale is
%     also changed so the noise clip is at BGCOLOR.
%
%     H=PLOTFKARF(ARF,FGCOLOR,BGCOLOR,H) sets the axes that the map is
%     drawn in.  This is useful for subplots, guis, etc.
%
%    Notes:
%
%    Examples:
%     Show a array response function for 12 plane waves:
%      arfpolar=fkarf(stla,stlo,50,201,20,[0:30:330],1/30,true);
%      plotfkarf(arfpolar);
%
%    See also: FKMAP, FKARF, PLOTFKMAP

%     Version History:
%        May  11, 2010 - initial version (outside of FKARF
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated May  11, 2010 at 11:00 GMT

% todo:

% check nargin
error(nargchk(1,4,nargin));

% check fk struct
error(chkfkarfstruct(arf));

% don't allow array/volume
if(~isscalar(arf))
    error('seizmo:plotfkmap:badInput',...
        'ARF must be a scalar FKARF struct!');
end

% plotting function call depends on polar
if(arf.polar)
    varargout{1}=plotfkarfpolarmap(arf,varargin{:});
else % cartesian
    varargout{1}=plotfkarfcartmap(arf,varargin{:});
end

end

function ax=plotfkarfpolarmap(map,fgcolor,bgcolor,ax)

% check colors
if(nargin<2); fgcolor='w'; bgcolor='k'; end
if(nargin<3)
    if(isempty(fgcolor))
        fgcolor='w'; bgcolor='k';
    else
        bgcolor=invertcolor(fgcolor,true);
    end
end
if(nargin<4)
    if(isempty(fgcolor))
        if(isempty(bgcolor))
            fgcolor='w'; bgcolor='k';
        else
            fgcolor=invertcolor(bgcolor,true);
        end
    elseif(isempty(bgcolor))
        if(isempty(fgcolor))
            fgcolor='w'; bgcolor='k';
        else
            bgcolor=invertcolor(fgcolor,true);
        end
    end
end

% change char to something rgb
if(ischar(fgcolor)); fgcolor=name2rgb(fgcolor); end
if(ischar(bgcolor)); bgcolor=name2rgb(bgcolor); end

% check handle
if(nargin<4 || isempty(ax) || ~isscalar(ax) || ~isreal(ax) ...
        || ~ishandle(ax) || ~strcmp('axes',get(ax,'type')))
    figure('color',bgcolor);
    ax=gca;
else
    axes(ax);
end

% pertinent info
smax=max(abs(map.y));

% get nearest neighbor station distances
[clat,clon]=arraycenter(map.stla,map.stlo);
[e,n]=geographic2enu(map.stla,map.stlo,0,clat,clon,0);
tri=delaunay(e,n);
friends=[tri(:,1:2); tri(:,2:3); tri(:,[3 1])];
friends=unique([min(friends,[],2) max(friends,[],2)],'rows');
dist=vincentyinv(map.stla(friends(:,1)),map.stlo(friends(:,1)),...
                 map.stla(friends(:,2)),map.stlo(friends(:,2)));

% get root defaults
defaulttextcolor=get(0,'defaulttextcolor');
defaultaxescolor=get(0,'defaultaxescolor');
defaultaxesxcolor=get(0,'defaultaxesxcolor');
defaultaxesycolor=get(0,'defaultaxesycolor');
defaultaxeszcolor=get(0,'defaultaxeszcolor');
defaultpatchfacecolor=get(0,'defaultpatchfacecolor');
defaultpatchedgecolor=get(0,'defaultpatchedgecolor');
defaultlinecolor=get(0,'defaultlinecolor');
defaultsurfaceedgecolor=get(0,'defaultsurfaceedgecolor');

% set root defaults
set(0,'defaulttextcolor',fgcolor);
set(0,'defaultaxescolor',bgcolor);
set(0,'defaultaxesxcolor',fgcolor);
set(0,'defaultaxesycolor',fgcolor);
set(0,'defaultaxeszcolor',fgcolor);
set(0,'defaultpatchfacecolor',bgcolor);
set(0,'defaultpatchedgecolor',fgcolor);
set(0,'defaultlinecolor',fgcolor);
set(0,'defaultsurfaceedgecolor',fgcolor);

% initialize polar plot
ph=polar([0 2*pi],[0 smax]);
%ph=mmpolar([0 2*pi],[0 smax],'style','compass',...
%    'backgroundcolor','k','bordercolor','w');

% adjust to proper orientation
axis('ij');
delete(ph);
view([-90 90]);
hold on;

% get cartesian coords
nx=numel(map.x);
ny=numel(map.y);
[x,y]=pol2cart(pi/180*map.x(ones(ny,1),:),map.y(:,ones(nx,1)));

% plot polar grid
pcolor(x,y,map.response);

% last plot the nyquist rings about the plane wave locations
titstr=cell(map.npw,1);
for i=1:map.npw
    snyq=snyquist(min(dist),map.f(i)); % closest 2 stations
    [x,y]=circle(snyq);
    x=x+map.s(i)*sin(map.baz(i)*pi/180);
    y=y+map.s(i)*cos(map.baz(i)*pi/180);
    plot(x,y,'r:','linewidth',2,'tag','nyquist_rings');
    titstr{i}=sprintf('SLOWNESS: %gs/deg, BAZ: %gdeg, FREQ: %gHz',...
            map.s(i),map.baz(i),map.f(i));
end

% add title color etc
hold off;
title([{'Array Response Function @ '}; titstr; {''; ''; ''}],...
    'fontweight','bold','color',fgcolor);
set(ax,'clim',[-12 0]);
shading flat;
if(strcmp(bgcolor,'w') || isequal(bgcolor,[1 1 1]))
    colormap(flipud(fire));
elseif(strcmp(bgcolor,'k') || isequal(bgcolor,[0 0 0]))
    colormap(fire);
else
    if(ischar(bgcolor))
        bgcolor=name2rgb(bgcolor);
    end
    hsv=rgb2hsv(bgcolor);
    colormap(hsvcustom(hsv));
end
c=colorbar('eastoutside',...
    'fontweight','bold','xcolor',fgcolor,'ycolor',fgcolor);
set(c,'xaxislocation','top');
xlabel(c,'dB','fontweight','bold','color',fgcolor)

% reset root values
set(0,'defaulttextcolor',defaulttextcolor);
set(0,'defaultaxescolor',defaultaxescolor);
set(0,'defaultaxesxcolor',defaultaxesxcolor);
set(0,'defaultaxesycolor',defaultaxesycolor);
set(0,'defaultaxeszcolor',defaultaxeszcolor);
set(0,'defaultpatchfacecolor',defaultpatchfacecolor);
set(0,'defaultpatchedgecolor',defaultpatchedgecolor);
set(0,'defaultlinecolor',defaultlinecolor);
set(0,'defaultsurfaceedgecolor',defaultsurfaceedgecolor);

end

function ax=plotfkarfcartmap(map,fgcolor,bgcolor,ax)

% check colors
if(nargin<2); fgcolor='w'; bgcolor='k'; end
if(nargin<3)
    if(isempty(fgcolor))
        fgcolor='w'; bgcolor='k';
    else
        bgcolor=invertcolor(fgcolor,true);
    end
end
if(nargin<4)
    if(isempty(fgcolor))
        if(isempty(bgcolor))
            fgcolor='w'; bgcolor='k';
        else
            fgcolor=invertcolor(bgcolor,true);
        end
    elseif(isempty(bgcolor))
        if(isempty(fgcolor))
            fgcolor='w'; bgcolor='k';
        else
            bgcolor=invertcolor(fgcolor,true);
        end
    end
end

% change char to something rgb
if(ischar(fgcolor)); fgcolor=name2rgb(fgcolor); end
if(ischar(bgcolor)); bgcolor=name2rgb(bgcolor); end

% check handle
if(nargin<4 || isempty(ax) || ~isscalar(ax) || ~isreal(ax) ...
        || ~ishandle(ax) || ~strcmp('axes',get(ax,'type')))
    figure('color',bgcolor);
    ax=gca;
else
    axes(ax);
end

% get pertinent info
smax=max(max(abs(map.x)),max(abs(map.y)));

% get nearest neighbor station distances
[clat,clon]=arraycenter(map.stla,map.stlo);
[e,n]=geographic2enu(map.stla,map.stlo,0,clat,clon,0);
tri=delaunay(e,n);
friends=[tri(:,1:2); tri(:,2:3); tri(:,[3 1])];
friends=unique([min(friends,[],2) max(friends,[],2)],'rows');
dist=vincentyinv(map.stla(friends(:,1)),map.stlo(friends(:,1)),...
                 map.stla(friends(:,2)),map.stlo(friends(:,2)));

% first plot the map
imagesc(map.x,map.y,map.response);
set(ax,'xcolor',fgcolor,'ycolor',fgcolor,'ydir','normal',...
    'color',bgcolor,'fontweight','bold','clim',[-12 0]);
hold on

% phase specific bullseye
% Phase:       Rg    Lg    Sn    Pn    Sdiff  Pdiff  PKPcdiff
% Vel (km/s):  3.0   4.0   4.5   8.15  13.3   25.1   54.0
% S (s/deg):   37.0  27.8  24.7  13.6  8.36   4.43   2.06
%if(smax>=37)
%    ph=[37 27.8 24.7 13.6 8.36 4.43];
%elseif(smax>=28)
%    ph=[27.8 24.7 13.6 8.36 4.43];
%elseif(smax>=25)
%    ph=[24.7 13.6 8.36 4.43];
%elseif(smax>=14)
%    ph=[13.6 8.36 4.43 2.06];
%elseif(smax>=8.5)
%    ph=[8.36 4.43 2.06];
%elseif(smax>=4.5)
%    ph=[4.43 2.06];
%else
%    ph=2.06;
%end

% regular rings (want only 3 to 5)
pot=[0.1 0.2 0.3 0.5 1 2 3 5 10 20 50 100];
rings=ceil(smax./pot);
idx=find(rings>=3 & rings<=5,1);
ph=(1:rings(idx))*pot(idx);

% plot the bull's eye
% first the radial lines
[x,y]=circle(0,12);
[x2,y2]=circle(ph(end),12);
plot([x; x2],[y; y2],'color',fgcolor,...
    'linewidth',1,'linestyle',':','tag','bullseye');
% next the rings
for i=ph
    [x,y]=circle(i);
    plot(x,y,'color',fgcolor,'linewidth',1,'linestyle',':',...
        'tag','bullseye');
end

% last plot the nyquist rings about the plane wave locations
titstr=cell(map.npw,1);
for i=1:map.npw
    snyq=snyquist(min(dist),map.f(i)); % closest 2 stations
    [x,y]=circle(snyq);
    x=x+map.s(i)*sin(map.baz(i)*pi/180);
    y=y+map.s(i)*cos(map.baz(i)*pi/180);
    plot(x,y,'r:','linewidth',2,'tag','nyquist_rings');
    titstr{i}=sprintf('SLOWNESS: %gs/deg, BAZ: %gdeg, FREQ: %gHz',...
            map.s(i),map.baz(i),map.f(i));
end
hold off

% finally take care of labels/coloring/etc
title([{'Array Response Function @ '}; titstr],...
    'fontweight','bold','color',fgcolor);
xlabel('East/West Slowness (s/deg)',...
    'fontweight','bold','color',fgcolor);
ylabel('North/South Slowness (s/deg)',...
    'fontweight','bold','color',fgcolor);
if(strcmp(bgcolor,'w') || isequal(bgcolor,[1 1 1]))
    colormap(flipud(fire));
elseif(strcmp(bgcolor,'k') || isequal(bgcolor,[0 0 0]))
    colormap(fire);
else
    if(ischar(bgcolor))
        bgcolor=name2rgb(bgcolor);
    end
    hsv=rgb2hsv(bgcolor);
    colormap(hsvcustom(hsv));
end
c=colorbar('eastoutside',...
    'fontweight','bold','xcolor',fgcolor,'ycolor',fgcolor);
set(c,'xaxislocation','top');
xlabel(c,'dB','fontweight','bold','color',fgcolor)
axis equal tight;

end