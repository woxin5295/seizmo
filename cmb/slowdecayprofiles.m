function [varargout]=slowdecayprofiles(results,azrng,gcrng,odir)
%SLOWDECAYPROFILES    Returns multi-station profile measurements
%
%    Usage:    pf=slowdecayprofiles(results,azrng,gcrng)
%              pf=slowdecayprofiles(results,azrng,gcrng,odir)
%
%    Description:
%     PF=SLOWDECAYPROFILES(RESULTS,AZRNG,GCRNG) takes the relative arrival
%     time and amplitude measurements contained in RESULTS produced by
%     CMB_1ST_PASS, CMB_CLUSTERING, CMB_OUTLIERS, or CMB_2ND_PASS and
%     calculates the slowness and decay rate for a profile of stations
%     within the criteria set by azimuthal range AZRNG and distance range
%     GCRNG.  Note that AZRNG & GCRNG are absolute ranges, meaning an AZRNG
%     of [0 360] will not exclude any stations by azimuth.  AZRNG & GCRNG
%     must both be 2-element vectors of [AZMIN AZMAX] & [GCMIN GCMAX].
%     They are by default [0 360] & [0 180] (ie no exclusion) and are
%     optional.  The output PF is a struct with as many elements as there
%     are profiles found (depends on number of clusters and how many
%     elements the input RESULTS struct had).  The format of the PF struct
%     is described in the Notes section below.
%
%     PF=SLOWDECAYPROFILES(RESULTS,AZRNG,GCRNG,ODIR) sets the output
%     directory where the PF struct is saved.  By default ODIR is '.' (the
%     current directory.
%
%    Notes:
%     - The PF struct has the following fields:
%       .gcdist         - degree distance difference between stations
%       .azwidth        - azimuthal difference between stations
%       .slow           - horizontal slowness (s/deg)
%       .slowerr        - horizontal slowness standard error
%       .decay          - decay rate
%       .decayerr       - decay rate standard error
%       .cslow          - corrected horizontal slowness***
%       .cslowerr       - corrected horizontal slowness standard error
%       .cdecay         - corrected decay rate
%       .cdecayerr      - corrected decay rate standard error
%       .cluster        - cluster id
%       .kname          - {net stn stream cmp}
%       .st             - [lat lon elev(m) depth(m)]
%       .ev             - [lat lon elev(m) depth(m)]
%       .delaz          - [degdist az baz kmdist]
%       .corrections    - traveltime & amplitude correction values
%       .corrcoef       - max correlation coefficient between waveforms
%       .synthetics     - TRUE if synthetic data (only reflect synthetics)
%       .earthmodel     - model used to make synthetics or 'DATA'
%       .freq           - filter corners of bandpass
%       .phase          - core-diffracted wave type
%       .runname        - name of this run, used for naming output
%       .dirname        - directory containing the waveforms
%       .time           - date string of time of this struct's creation
%
%      *** Correction is different between data and synthetics.  For data
%          the .cslow value is found by subtracting out the corrections
%          (and hence attempts to go from 3D to 1D by removing the lateral
%          heterogeniety).  For synthetics the .cslow value is essentially
%          the opposite (it is corrected to 3D).  So basically:
%                     +----------+---------------+
%                     |   DATA   |   SYNTHETICS  |
%            +--------+----------+---------------+
%            |  .slow |    3D    |       1D      |
%            +--------+----------+---------------+
%            | .cslow |    1D    |       3D      |
%            +--------+----------+---------------+
%
%          To compare the data & sythetics you should compare 3D values or
%          1D values.  Drawing conclusions from comparison of 3D to 1D is
%          not recommended.
%
%    Examples:
%     % Return station profiles with an azimuth
%     % of 200-220deg and a distance of 90-160deg:
%     pf=slowdecayprofiles(results,[200 220],[90 160])
%
%    See also: SLOWDECAYPAIRS, CMB_2ND_PASS, CMB_OUTLIERS, CMB_1ST_PASS,
%              CMB_CLUSTERING, PREP_CMB_DATA

%     Version History:
%        Dec. 12, 2010 - initial version
%        Jan. 18, 2011 - update for results struct standardization, added
%                        corrections & correlation coefficients to output,
%                        time is now a string, require common event
%        Jan. 23, 2011 - fix indexing bug
%        Jan. 26, 2011 - pass on new .synthetics & .earthmodel fields,
%                        .cslow depends on .synthetics, added Notes
%                        about PF struct format
%        Jan. 29, 2011 - save output, fix corrections bug
%        Jan. 31, 2011 - allow no output, odir input, better checks
%        Feb.  5, 2011 - fix bug when no output specified
%
%     Written by Garrett Euler (ggeuler at wustl dot edu)
%     Last Updated Feb.  5, 2011 at 13:35 GMT

% todo:

% check nargin
error(nargchk(1,4,nargin));

% check results struct
error(check_cmb_results(results));

% default azrng, gcrng, odir
if(nargin<2 || isempty(azrng)); azrng=[0 360]; end
if(nargin<3 || isempty(gcrng)); gcrng=[0 180]; end
if(nargin<4 || isempty(odir)); odir='.'; end

% check azrng & gcrng
if(~isreal(azrng) || numel(azrng)~=2)
    error('seizmo:slowdecayprofiles:badInput',...
        'AZRNG must be [AZMIN AZMAX]!');
elseif(any(abs(azrng)>540))
    error('seizmo:slowdecayprofiles:badInput',...
        'Keep AZRNG within +/-540deg!');
elseif(~isreal(gcrng) || numel(gcrng)~=2)
    error('seizmo:slowdecayprofiles:badInput',...
        'GCRNG must be [GCMIN GCMAX]!');
elseif(~isstring(odir))
    error('seizmo:slowdecayprofiles:badInput',...
        'ODIR must be a string!');
end

% make sure odir exists (create it if it does not)
[ok,msg,msgid]=mkdir(odir);
if(~ok)
    warning(msgid,msg);
    error('seizmo:slowdecayprofiles:pathBad',...
        'Cannot create directory: %s',odir);
end

% verbosity
%verbose=seizmoverbose;

% loop over every result
for a=1:numel(results)
    % skip if results.useralign is empty
    if(isempty(results(a).useralign)); continue; end
    
    % number of records
    %nrecs=numel(results(a).useralign.data);
    
    % extract header details
    [st,ev,delaz,kname]=getheader(results(a).useralign.data,...
        'st','ev','delaz','kname');
    
    % check event info matches
    ev=unique(ev,'rows');
    if(size(ev,1)>1)
        error('seizmo:slowdecaypairs:badInput',...
            'EVENT location varies between records!');
    end
    
    % corrected relative arrival times and amplitudes
    rtime=results(a).useralign.solution.arr;
    if(results(a).synthetics)
        % we add corrections here to go from 1D to 3D
        switch results(a).phase
            case 'Pdiff'
                crtime=results(a).useralign.solution.arr...
                    +results(a).corrections.ellcor...
                    +results(a).corrections.crucor.prem...
                    +results(a).corrections.mancor.hmsl06p.upswing;
            case {'SHdiff' 'SVdiff'}
                crtime=results(a).useralign.solution.arr...
                    +results(a).corrections.ellcor...
                    +results(a).corrections.crucor.prem...
                    +results(a).corrections.mancor.hmsl06s.upswing;
        end
    else % data
        % we subtract corrections here to go from 3D to 1D
        switch results(a).phase
            case 'Pdiff'
                crtime=results(a).useralign.solution.arr...
                    -results(a).corrections.ellcor...
                    -results(a).corrections.crucor.prem...
                    -results(a).corrections.mancor.hmsl06p.upswing;
            case {'SHdiff' 'SVdiff'}
                crtime=results(a).useralign.solution.arr...
                    -results(a).corrections.ellcor...
                    -results(a).corrections.crucor.prem...
                    -results(a).corrections.mancor.hmsl06s.upswing;
        end
    end
    rtimeerr=results(a).useralign.solution.arrerr;
    rampl=results(a).useralign.solution.amp;
    crampl=results(a).useralign.solution.amp...
        ./results(a).corrections.geomsprcor;
    ramplerr=results(a).useralign.solution.amperr;
    
    % get cluster indexing
    cidx=results(a).usercluster.T;
    good=results(a).usercluster.good';
    
    % get outliers
    outliers=results(a).outliers.bad;
    
    % loop over "good" clusters
    cnt=0;
    for b=find(good)
        % indices of members
        m=cidx==b & ~outliers;
        
        % get stations in range (need the indices)
        delaz(:,2)=delaz(:,2)-360*ceil((delaz(:,2)-azrng(2))/360);
        idx=find(m & delaz(:,1)>=gcrng(1) & delaz(:,1)<=gcrng(2) ...
            & delaz(:,2)>=azrng(1) & delaz(:,2)<=azrng(2));
        nsta=numel(idx);
        
        % skip if none/one
        if(nsta<2); continue; end
        
        % initialize struct
        cnt=cnt+1;
        tmp(cnt)=struct('gcdist',[],'azwidth',[],...
            'slow',[],'slowerr',[],'decay',[],'decayerr',[],...
            'cslow',[],'cslowerr',[],'cdecay',[],'cdecayerr',[],...
            'cluster',b,'kname',[],'st',[],'ev',[],'delaz',[],...
            'corrections',[],'corrcoef',[],...
            'synthetics',results(a).synthetics,...
            'earthmodel',results(a).earthmodel,...
            'freq',results(a).filter.corners,'phase',results(a).phase,...
            'runname',results(a).runname,'dirname',results(a).dirname,...
            'time',datestr(now));
        
        % insert known info
        tmp(cnt).kname=kname(idx,:);
        tmp(cnt).st=st(idx,:);
        tmp(cnt).ev=ev;
        tmp(cnt).delaz=delaz(idx,:);
        
        % great circle distance and width
        tmp(cnt).gcdist=max(delaz(idx,1))-min(delaz(idx,1));
        tmp(cnt).azwidth=max(delaz(idx,2))-min(delaz(idx,2));
        
        % corrections
        tmp(cnt).corrections=fixcorrstruct(results(a).corrections,idx);
        
        % correlation coefficients
        tmp(cnt).corrcoef=...
            submat(ndsquareform(results(a).useralign.xc.cg),1:2,idx,3,1);
        
        % find slowness & decay rate
        [m,covm]=wlinem(delaz(idx,1),rtime(idx),1,diag(rtimeerr(idx).^2));
        tmp(cnt).slow=m(2);
        tmp(cnt).slowerr=sqrt(covm(2,2));
        [m,covm]=wlinem(delaz(idx,1),crtime(idx),1,diag(rtimeerr(idx).^2));
        tmp(cnt).cslow=m(2);
        tmp(cnt).cslowerr=sqrt(covm(2,2));
        [m,covm]=wlinem(delaz(idx,1),log(rampl(idx)),1,...
            diag(log(rampl(idx)+ramplerr(idx).^2)-log(rampl(idx))));
        tmp(cnt).decay=m(2);
        tmp(cnt).decayerr=sqrt(covm(2,2));
        [m,covm]=wlinem(delaz(idx,1),log(crampl(idx)),1,...
            diag(log(crampl(idx)+ramplerr(idx).^2)-log(crampl(idx))));
        tmp(cnt).cdecay=m(2);
        tmp(cnt).cdecayerr=sqrt(covm(2,2));
    end
    
    % skip if none
    if(~cnt); continue; end
    
    % save profiles
    save(fullfile(odir,[datestr(now,30) '_' ...
        results(a).runname '_profiles.mat']),'tmp');
    
    % output
    if(nargout)
        if(~exist('varargout','var'))
            varargout{1}=tmp;
        else
            varargout{1}=[varargout{1}; tmp];
        end
    end
end

% check for output
if(nargout && ~exist('varargout','var'))
    error('seizmo:slowdecayprofiles:noPairs',...
        'Not enough stations meet the specified profile criteria!');
end

end


function [s]=fixcorrstruct(s,good)
fields=fieldnames(s);
for i=1:numel(fields)
    if(isstruct(s.(fields{i})))
        s.(fields{i})=fixcorrstruct(s.(fields{i}),good);
    else
        s.(fields{i})=s.(fields{i})(good);
    end
end
end
