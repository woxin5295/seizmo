function [ok]=install_seizmo_optional(mypath,varargin)
%INSTALL_SEIZMO_OPTIONAL    Install optional SEIZMO components
%
%    Usage:    ok=install_seizmo_optional(mypath)
%              ok=install_seizmo_optional(mypath,type)
%
%    Description:
%     OK=INSTALL_SEIZMO_OPTIONAL(MYPATH) installs optional SEIZMO
%     components to the path.  Most of these are quite essential, but are
%     still not core functions.  The path is saved to the pathdef.m file
%     that the path was loaded from at startup.
%
%     OK=INSTALL_SEIZMO_OPTIONAL(MYPATH,TYPE) allows editing the pathdef.m
%     save preference.  See SAVEPATH_SEIZMO for details.  The default is
%     no input to SAVEPATH_SEIZMO.
%
%    Notes:
%     - Some optional components are better than others.  You may remove
%       some directories but be wary as there may be interdependancies!
%
%    Examples:
%
%    See also: INSTALL_SEIZMO, INSTALL_SEIZMO_MATTAUP, INSTALL_SEIZMO_WW3,
%              INSTALL_SEIZMO_CORE, INSTALL_SEIZMO_MMAP

%     Version History:
%        Dec. 30, 2010 - initial version
%        Jan.  2, 2011 - update for new directory layout
%        Feb. 10, 2011 - map => mapping
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Feb. 10, 2011 at 15:25 GMT

% todo:

% check nargin
error(nargchk(0,2,nargin));

% default path input
if(nargin<1 || isempty(mypath)); mypath='.'; end

% check path
fs=filesep;
if(~exist(mypath,'dir'))
    error('seizmo:install_seizmo_optional:badPath',...
        ['SEIZMO directory (' mypath ') does not exist!']);
end

% add optional seizmo components to path
addpath(...
    [mypath fs 'audio'],...
    [mypath fs 'behavior'],...
    [mypath fs 'cmap'],...
    [mypath fs 'cmb'],...
    [mypath fs 'cmt'],...
    [mypath fs 'decon'],...
    [mypath fs 'event'],...
    [mypath fs 'filtering'],...
    [mypath fs 'fixes'],...
    [mypath fs 'fk'],...
    [mypath fs 'ftran'],...
    [mypath fs 'gui'],...
    [mypath fs 'intdif'],...
    [mypath fs 'invert'],...
    [mypath fs 'mapping'],...
    [mypath fs 'models'],...
    [mypath fs 'multi'],...
    [mypath fs 'noise'],...
    [mypath fs 'pick'],...
    [mypath fs 'plotting'],...
    [mypath fs 'resampling'],...
    [mypath fs 'response'],...
    [mypath fs 'shortnames'],...
    [mypath fs 'solo'],...
    [mypath fs 'sphpoly'],...
    [mypath fs 'synth'],...
    [mypath fs 'tomo'],...
    [mypath fs 'topo'],...
    [mypath fs 'tpw'],...
    [mypath fs 'ttcorrect'],...
    [mypath fs 'win'],...
    [mypath fs 'ww3'],...
    [mypath fs 'xcalign']);
bad=savepath_seizmo(varargin{:});
if(~bad); ok=true; end

end
