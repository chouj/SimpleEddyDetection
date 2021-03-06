function Eddy=eddyDetection_output(lon,lat,sla,upperFolderName,whichYear,whichMonth,whichDay,whichHour,varargin)
% Eddy Detection based on sea level anomaly (sla)
% Inputs:
%   lon: longitude, vector or matrix generated by "meshgrid" with range
%        between [-180,180]
%   lat: latitude, vector or matrix generated by "meshgrid" with range
%        between [-90,90]
%   sla: (spatial high-pass filtered) sea level anomaly (unit: meter) falls
%        within the area defined by viarable "lon" and "lat". Continent or
%        no value at grid point is masked with "NaN".
%   upperFolderName: a string to signify the upper folder name or path.
%   whichYear: The year of data "sla". Only an integer is accepted.
%   whichMonth: The month of data "sla". Only an integer is accepted.
%   whichDay: The day of data "sla". Only an integer is accepted. Can be
%             replaced by "[]".
%   whichHour: The hour of data "sla". Only an integer is accepted. Can be
%              replaced by "[]".
%   amplitudeThreshold (optional): unit: cm. Default is 3 cm. Note: this is
%                                  an artificial threshold that an detected
%                                  eddy is required to meet this criterion.
%   radiusThreshold (optional): unit: Km. Default is 45 Km, designed for
%                              altimetry data due to its resolving 
%                              capability. Note: this is an artificial 
%                              threshold that an detected eddy is required 
%                              to meet this criterion.
% Outputs:
%   Eddy: a structure array contains the properties of detected eddies:
%     Eddy.type: polarity of detected eddy. -1 for cyclonic while 1 for
%                anticyclonic.
%     Eddy.center: longitude and latitude of eddy centroid.
%     Eddy.amplitude: longitude and latitude of eddy's sla extreme as well
%                     as eddy's amplitude (set to positive no matter if it
%                     is cyclonic or anticyclonic. Unit: cm)
%     Eddy.radius: radius of an circle that has the same area as the eddy
%                  area enclosed by the eddy edge. Unit: Km
%     Eddy.edge: two vectors specify the longitudes and latitudes of eddy
%                edge defined by the largest closed sla contour.
%
% Author:
%   Dr. Chi Xu (SCSIO, CAS)
%   SEP 07 2020
%   http://data.scsio.ac.cn/characteristic/zhongchiduwo
%
% This function is provided "as is" without warranty of any kind.

% Inputs validation process
if nargin<8
    error('Not Enough Inputs. 8 inputs are required.');
end
if nargin>10
    error('Too Many Inputs. No more than 10 inputs please.');
end

p = inputParser;

p.addRequired('lon',@(x)validateattributes(x,{'numeric'},...
    {'nonempty'},'eddyDetection_output','lon',1));
p.addRequired('lat',@(x)validateattributes(x,{'numeric'},...
    {'nonempty'},'eddyDetection_output','lat',2));
p.addRequired('sla',@(x)validateattributes(x,{'numeric'},...
    {'2d'},'eddyDetection_output','sla',3));
% p.addRequired('upperFolderName',@(x)any(validatestring(x,{'char'},...
%     {'nonempty'},'eddyDetection_output','upperFolderName',4));

p.addRequired('upperFolderName',@(x)validateattributes(x,{'char'},...
    {'nonempty'},'eddyDetection_output','upperFolderName',4));

p.addRequired('whichYear',@(x)validateattributes(x,{'numeric'},...
    {'nonempty','positive','integer'},'eddyDetection_output','whichYear',5));
p.addRequired('whichMonth',@(x)validateattributes(x,{'numeric'},...
    {'nonempty','positive','integer','>=',1,'<=',12},'eddyDetection_output','whichMonth',6));
p.addRequired('whichDay',@(x)validateattributes(x,{'numeric'},...
    {'positive','integer'},'eddyDetection_output','whichDay',7));
p.addRequired('whichHour',@(x)validateattributes(x,{'numeric'},...
    {'integer'},'eddyDetection_output','whichHour',8));
defaultAmplitudeThreshold=3; % unit: cm
p.addOptional('amplitudeThreshold',defaultAmplitudeThreshold,...
    @(x)validateattributes(x,{'numeric'},...
    {'nonzero','integer','positive'},'eddyDetection_output','amplitudeThreshold',9));
defaultRadiusThreshold=45; % unit: Km
p.addOptional('radiusThreshold',defaultRadiusThreshold,...
    @(x)validateattributes(x,{'numeric'},...
    {'nonzero','positive'},'eddyDetection_output','radiusThreshold',10));

p.parse(lon,lat,sla,upperFolderName,whichYear,whichMonth,whichDay,whichHour,varargin{:});

% Test whether "lon" and "lat" are vectors or matrixes.
if size(p.Results.lon,2)==1&size(p.Results.lat,2)==1
    [X,Y]=meshgrid(lon,lat);
elseif size(p.Results.lon,1)==1&size(p.Results.lat,1)==1
    [X,Y]=meshgrid(lon,lat);
else
    X=lon;Y=lat;
end

% test whether sla marix should be rotated
if isequal(size(p.Results.sla),size(X))==0
    sla=p.Results.sla;
    sla=sla';
else
    sla=p.Results.sla;
end
if isequal(size(sla),size(X))==0
    error('The zonal or meridional grid points of "sla" do not match those of "lon" or "lat".');
end

% specify the area for M_Map toolbox
m_proj('miller','lon',[min(p.Results.lon(:)) max(p.Results.lon(:))],...
    'lat',[min(p.Results.lat(:)) max(p.Results.lat(:))]);

% angular speed of earth rotation: omega
omg=2*pi/24/3600;

f=2*omg*sin(Y/180*pi); % coriolis parameter
% the coriolis parameter within the equator band should not be zero in order to avoid obtaining INF in calculation.
f(f<=1.2676e-005&f>=0)=1.2676e-005;
f(f<0&f>-1.2676e-005)=-1.2676e-005;

% Central Differences to compute numerical derivatives
% distance between grid points (x1,y1) and (x1,y3), unit: meters
disy2(1:size(X,1),1:size(X,2))=m_lldist([X(1,1) X(3,1)],[Y(1,1) Y(3,1)])*1000;
disy2(1,:)=m_lldist([X(1,1) X(2,1)],[Y(1,1) Y(2,1)])*1000;
disy2(size(X,1),:)=disy2(1,:);

% distance between (x1,y1) and (x3,y1), unit:meters
for cc=1:length(X(:,1))
    disx2(cc,1:size(X,2))=m_lldist([X(cc,1) X(cc,3)],[Y(cc,1) Y(cc,3)]).*1000;
end

i=1; % index for the scenario that 'sla' is a 3-D matrix. Here as it is 2-D matrix, we set 'i' to 1;
clear hhh1
hhh1=sla(:,:,i)*100; % sea level anomaly unit from meter to centimeter
ampThreshold=p.Results.amplitudeThreshold;
radThreshold=p.Results.radiusThreshold;
upperFolderPath=p.Results.upperFolderName;
n=0; % stands for the numbers of detected eddies that meet all the identification thresholds. At first, set it to zero.

for j=100:-1:-100 % for cyclonic eddy detection, scan from positive 100 cm sea level anomaly to negative 100 cm.
    levels=[j 1000];cf=figure('visible','off');
    [c1,ch1]=contour(X,Y,hhh1,levels); % draw the contours of sea level anomalies that equal to j.
    
    % The elements of each contour are stored in 'c1', including how many location points there are in a certain contour and associated 'lon' and 'lat'.
    wz=find(c1(1,:)==j); % Each contour's information starts with c1(1,?)==j. Thus, 'wz' is an index for each contour.
    
    for k=1:length(wz) % length(wz) tells how many contours have been generated.
        
        clear in ky kx bx by in hmeanw EKEmean EKEkg area XX YY U V UV fuqi depth_thermo rr WOeke1 WOgpe1 WOeke2 WOgpe2 tempe jd wd EKEunitmass AGPEunitmass alpha con Dis kmianx kmiany
        
        if c1(2,wz(k))==floor(c1(2,wz(k))) % to insure 'c1(2,wz(k))' is an integer.
            if c1(1,wz(k)+1)==c1(1,wz(k)+c1(2,wz(k))) & c1(2,wz(k)+1)==c1(2,wz(k)+c1(2,wz(k)))&c1(2,wz(k))~=2 % to ensure the contour is closed and not only made of two [lon,lat] points.
                % to ensure the zonal and meridinal range of this closed contour not less than 0.5 degree. Note that this is an artificial threshold.
                if (max(c1(1,wz(k)+1:wz(k)+c1(2,wz(k))-1))-min(c1(1,wz(k)+1:wz(k)+c1(2,wz(k))-1)))>=0.5&(max(c1(2,wz(k)+1:wz(k)+c1(2,wz(k))-1))-min(c1(2,wz(k)+1:wz(k)+c1(2,wz(k))-1)))>=0.5
                    
                    % Then record the lon/lat coordinates of the contour meet the criterion above.
                    kmianx=(c1(1,wz(k)+1:wz(k)+c1(2,wz(k))));
                    kmiany=(c1(2,wz(k)+1:wz(k)+c1(2,wz(k))));
                    
                    % Calculate the distance between arbitrary pair of points on the contour.
                    for p=0:length(kmianx)-1;
                        for q=1:length(kmianx)
                            Dis(p*length(kmianx)+q)=m_lldist([kmianx(p+1) kmianx(q)],[kmiany(p+1) kmiany(q)]);
                        end
                    end
                    
                    if max(Dis)<=400 % the distance between arbitrary pair of points on the contour should be not longer than 400 km. Note that this is an artificial threshold.
                        
                        % "b" here means "boundary". Generate the vector contains the location coordinates of closed contour.
                        bx=[kmianx';kmianx(1)]';
                        by=[kmiany';kmiany(1)]';
                        in=inpolygon(X,Y,bx,by); % if value at certain grid point in matrix "in" equals 1, it means that grid point falls within the range of area enclosed by the closed contour.
                        
                        n1=length(X(in)); % how many grid points have been enclosed by the closed contour.
                        
                        %                        sumupx=0;
                        %                        sumdownx=0;
                        %                        sumupy=0;
                        %                        sumdowny=0;
                        %                        for k1=wz(k)+1:(wz(k)+c1(2,wz(k))-1)
                        %                            sumupx=sumupx+c1(1,k1);
                        %                            sumdownx=sumdownx+1;
                        %                            sumupy=sumupy+c1(2,k1);
                        %                            sumdowny=sumdowny+1;
                        %                        end
                        %                        xxjd=sumupx/sumdownx;% longitude of eddy centroid
                        %                        xxwd=sumupy/sumdowny;% latitude of eddy centroid
                        % As no eddy exsits in the band of equator due to the requirement of geostrophic balance, the lon/lat of eddy centroid is simply the average of coordinates of the closed countour.
                        xxjd=mean(kmianx);% longitude of eddy centroid
                        xxwd=mean(kmiany);% latitude of eddy centroid
                        
                        if inpolygon(xxjd,xxwd,bx,by)~=0 % to ensure the eddy centroid is enclosed by the closed contour.
                            
                            XX=X(in); % "XX" contains the longitudes of grid points that enclosed by the closed contour.
                            YY=Y(in); % "YY" contains the latitudes of grid points that enclosed by the closed contour.
                            for i1=1:length(XX)
                                jd(i1)=find(X(1,:)==XX(i1)); % index (of lon/lat grid) for longitudes of grid points that enclosed by the closed contour.
                                wd(i1)=find(Y(:,1)==YY(i1)); % index (of lon/lat grid) for latitudes of grid points that enclosed by the closed contour.
                            end
                            fuqi=hhh1(in); % sea surface anomaly vector enclosed by the closed contour. unit: cm
                            if min(fuqi)<=j % for cyclonic eddy, its extreme value of sea surface height anomaly should be smaller than the SSHA value of the enclosed contour.
                                tempe=find(fuqi==min(fuqi)); % find the index for the extreme value of SSHA in this cyclonic eddy.
                                if length(tempe)>1 % in case 2 or more extremes with same value are found.
                                    tempe=floor(mean(tempe));
                                end
                                if j-fuqi(tempe)>=ampThreshold % to ensure the amplitude of this eddy is not less than the input threshold. Note that this is an artificial threshold with default value of 3 cm.
                                    area=disx2(in).*disy2(in)/4;% calculat the area of ocean surface enclosed by the closed contour.
                                    if sqrt(sum(sum(area/1000/1000))/pi)>radThreshold % to ensure the equivalent radius of the eddy is larger than 45 km. This threshold is established due to the spatial resolving capability of altimetry data.
                                        n=n+1; % If all these thresholds are met, finally the procedure successfully found a mesoscale cyclonic eddy.
                                        disp(sprintf('%d%s',n,' eddy(eddies) found.')); % procedure can't wait to tell you the good news.
                                        hhh1(in)=NaN; % wipe out the SSHA information that covered by this new detected eddy for next-round scanning.
                                        Eddy(n).type=-1; % -1 for cyclonic eddy
                                        Eddy(n).center(1)=mean(kmianx); % longitude of eddy centroid
                                        Eddy(n).center(2)=mean(kmiany); % latitude of eddy centroid
                                        Eddy(n).amplitude(1)=XX(tempe); % longitude coordinate of extreme value of eddy's SSHA.
                                        Eddy(n).amplitude(2)=YY(tempe); % latitude coordinate of extreme value of eddy's SSHA.
                                        Eddy(n).amplitude(3)=j-fuqi(tempe); % the amplitude of eddy. unit: cm
                                        Eddy(n).amplitude(4)=ampThreshold; % the amplitude threshold value. unit: cm
                                        Eddy(n).radius(1)=sqrt(sum(sum(area/1000/1000))/pi); % the radius (unit: Km) of a circle which has the same area as the enclosed region by the eddy boundary.
                                        Eddy(n).radius(2)=radThreshold; % the radius threshold value (unit: Km)
                                        Eddy(n).edge(1,1:length(bx))=bx; % the longitude coordinates of points on the eddy boundary.
                                        Eddy(n).edge(2,1:length(by))=by; % the latitude coordinates of points on the eddy boundary.
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    close(cf);close all; % because the procedure produced an invisible picture of contours.
    close all hidden
end
% now start detecting anticyclones
clear hhh1
hhh1=sla(:,:,i)*100; % sea level anomaly unit from meter to centimeter
clear c1 ch1 wz
for j=-100:100 % this time we scan from -100 cm sea level anomaly to 100 cm.
    levels=[j 1000];cf=figure('visible','off');
    [c1,ch1]=contour(X,Y,hhh1,levels);
    wz=find(c1(1,:)==j);
    
    for k=1:length(wz)
        
        clear in ky kx bx by in hmeanw EKEmean EKEkg area XX YY U V UV fuqi depth_thermo rr WOeke1 WOgpe1 WOeke2 WOgpe2 tempe jd wd EKEunitmass AGPEunitmass alpha con Dis
        
        if c1(2,wz(k))==floor(c1(2,wz(k)))
            if c1(1,wz(k)+1)==c1(1,wz(k)+c1(2,wz(k)))&c1(2,wz(k)+1)==c1(2,wz(k)+c1(2,wz(k)))&c1(2,wz(k))~=2
                if (max(c1(1,wz(k)+1:wz(k)+c1(2,wz(k))-1))-min(c1(1,wz(k)+1:wz(k)+c1(2,wz(k))-1)))>=0.5&(max(c1(2,wz(k)+1:wz(k)+c1(2,wz(k))-1))-min(c1(2,wz(k)+1:wz(k)+c1(2,wz(k))-1)))>=0.5%2*2
                    
                    kmianx=(c1(1,wz(k)+1:wz(k)+c1(2,wz(k))-1));
                    kmiany=(c1(2,wz(k)+1:wz(k)+c1(2,wz(k))-1));
                    
                    for p=0:length(kmianx)-1;
                        for q=1:length(kmianx)
                            Dis(p*length(kmianx)+q)=m_lldist([kmianx(p+1) kmianx(q)],[kmiany(p+1) kmiany(q)]);
                        end
                    end
                    
                    if max(Dis)<=400
                        
                        bx=[kmianx';kmianx(1)]';
                        by=[kmiany';kmiany(1)]';
                        in=inpolygon(X,Y,bx,by);
                        
                        n1=length(X(in));
                        
                        %                        sumupx=0;
                        %                        sumdownx=0;
                        %                        sumupy=0;
                        %                        sumdowny=0;
                        %                        for k1=wz(k)+1:(wz(k)+c1(2,wz(k))-1)
                        %                            sumupx=sumupx+c1(1,k1);
                        %                            sumdownx=sumdownx+1;
                        %                            sumupy=sumupy+c1(2,k1);
                        %                            sumdowny=sumdowny+1;
                        %                        end
                        %                        xxjd=sumupx/sumdownx;
                        %                        xxwd=sumupy/sumdowny;
                        xxjd=mean(kmianx);
                        xxwd=mean(kmiany);
                        
                        if inpolygon(xxjd,xxwd,bx,by)~=0
                            
                            XX=X(in);
                            YY=Y(in);
                            for i1=1:length(XX)
                                jd(i1)=find(X(1,:)==XX(i1));
                                wd(i1)=find(Y(:,1)==YY(i1));
                            end
                            fuqi=hhh1(in);
                            if min(fuqi)>=j
                                tempe=find(fuqi==max(fuqi)); % for anticyclonic eddy, its extreme value of sea surface height anomaly should be larger than the SSHA value of the enclosed contour.
                                if length(tempe)>1
                                    tempe=floor(mean(tempe));
                                end
                                if fuqi(tempe)-j>=ampThreshold
                                    area=disx2(in).*disy2(in)/4;
                                    if sqrt(sum(sum(area/1000/1000))/pi)>radThreshold
                                        n=n+1;
                                        disp(sprintf('%d%s',n,' eddy(eddies) found.'));
                                        hhh1(in)=NaN;
                                        Eddy(n).type=1; % 1 for eddy polarity: anticyclonic
                                        Eddy(n).center(1)=mean(kmianx);
                                        Eddy(n).center(2)=mean(kmiany);
                                        Eddy(n).amplitude(1)=XX(tempe);
                                        Eddy(n).amplitude(2)=YY(tempe);
                                        Eddy(n).amplitude(3)=fuqi(tempe)-j;
                                        Eddy(n).amplitude(4)=ampThreshold; % the amplitude threshold value. unit: cm
                                        Eddy(n).radius(1)=sqrt(sum(sum(area/1000/1000))/pi);
                                        Eddy(n).radius(2)=radThreshold;
                                        Eddy(n).edge(1,1:length(bx))=bx;
                                        Eddy(n).edge(2,1:length(by))=by;
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    close(cf);close all;
    close all hidden
end

% Output folder establishing
if isempty(whichDay)==0 & isempty(whichHour)==0
    if whichMonth<10 & whichDay<10 & whichHour<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            '0',num2str(whichMonth),'0',num2str(whichDay),'0',num2str(whichHour)]);
    elseif whichMonth<10 & whichDay<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            '0',num2str(whichMonth),'0',num2str(whichDay),num2str(whichHour)]);
    elseif whichMonth<10 & whichHour<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            '0',num2str(whichMonth),num2str(whichDay),'0',num2str(whichHour)]);
    elseif whichDay<10 & whichHour<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            num2str(whichMonth),'0',num2str(whichDay),'0',num2str(whichHour)]);
    elseif whichMonth<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            '0',num2str(whichMonth),num2str(whichDay),num2str(whichHour)]);
    elseif whichDay<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            num2str(whichMonth),'0',num2str(whichDay),num2str(whichHour)]);
    elseif whichHour<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            num2str(whichMonth),num2str(whichDay),'0',num2str(whichHour)]);
    end
elseif isempty(whichDay)==0 & isempty(whichHour)==1
    if whichMonth<10 & whichDay<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            '0',num2str(whichMonth),'0',num2str(whichDay)]);
    elseif whichMonth<10 & whichDay<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            '0',num2str(whichMonth),'0',num2str(whichDay)]);
    elseif whichMonth<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            '0',num2str(whichMonth),num2str(whichDay)]);
    elseif whichDay<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            num2str(whichMonth),'0',num2str(whichDay)]);
    end
elseif isempty(whichDay)==1 & isempty(whichHour)==1
    if whichMonth<10
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            '0',num2str(whichMonth)]);
    else
        outputFolderPath=fullfile(upperFolderPath,[num2str(whichYear),...
            num2str(whichMonth)]);
    end
end
mkdir(outputFolderPath);
for i=1:length(Eddy)
    nccreate(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'type','Dimensions',{'type',1});
    ncwrite(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'type',Eddy(i).type);
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'type', 'standard_name', 'Eddy polarity');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'type', 'long_name', 'Eddy polarity, cyclonic or anticyclonic');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'type', 'description', '-1 for cyclonic eddy while 1 for anticyclonic eddy');
    
    nccreate(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'center','Dimensions',{'center',2});
    ncwrite(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'center',Eddy(i).center);
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'center', 'standard_name', 'Eddy centroid');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'center', 'long_name', 'Longitude and latitude coordinate of eddy centroid');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'center', 'description', '[longitude latitude]');
    
    nccreate(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'amplitude','Dimensions',{'amplitude',4});
    ncwrite(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'amplitude',[Eddy(i).amplitude]);
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'amplitude', 'standard_name', 'Eddy amplitude');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'amplitude', 'long_name', 'The sea suface height (SSH) difference (positive with unit of centimeters) between extreme value of SSH falls within the range of eddy and the SSH on eddy edge. Company with the lon/lat coordinate of that extreme value of SSH and value of the minimum amplitude threshold.');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'amplitude', 'description', '[longitude latitude amplitude amplitude_threshold]');
    
    nccreate(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'radius','Dimensions',{'radius',2});
    ncwrite(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'radius',Eddy(i).radius);
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'radius', 'standard_name', 'Eddy radius');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'radius', 'long_name', 'Radius of an circle that has the same area as the eddy area enclosed by the eddy edge as well as value of the minimum radius threshold. Unit: Km');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'radius', 'description', '[radius radius_threshold]');
    
    nccreate(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'edge','Dimensions',{'edge_row',2,'edge_col',length(Eddy(i).edge)});
    ncwrite(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']),'edge',Eddy(i).edge);
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'edge', 'standard_name', 'Eddy edge');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'edge', 'long_name', 'The longitudes and latitudes of eddy edge defined by the largest closed sla contour.');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), 'edge', 'description', 'Longitudes are in the 1st row while the 2nd row is filled with latitudes');
    
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), '/', 'dataset_name', 'Preliminary Mesoscale Eddy Detection Results based on Sea Surface Height');
    ncwriteatt(fullfile(outputFolderPath,['eddy',num2str(i),'.nc']), '/', 'dataset_description', 'Outputs are eddy polarity, coordinates of eddy centroid, eddy amplitude and according coordinates, eddy radius and coordinates of eddy edge.');
end
end