# SimpleEddyDetection

Simple Oceanic Mesoscale Eddy Detection based on sea level anomaly (sla)

## Inputs:

  lon: longitude, vector or matrix generated by "meshgrid" with range between [-180,180]
  
  lat: latitude, vector or matrix generated by "meshgrid" with range between [-90,90]
  
  sla: (spatial high-pass filtered) sea level anomaly (unit: meter) falls within the area defined by viarable "lon" and "lat". Continent or no value at grid point is masked with "NaN".
  
  upperFolderName: a string to signify the upper folder name or path.
  
  whichYear: The year of data "sla". Only an integer is accepted.
  
  whichMonth: The month of data "sla". Only an integer is accepted.
  
  whichDay: The day of data "sla". Only an integer is accepted. Can be replaced by "[]".
  
  whichHour: The hour of data "sla". Only an integer is accepted. Can be replaced by "[]".
  
  amplitudeThreshold (optional): unit: cm. Default is 3 cm. Note: this is an artificial threshold that an detected eddy is required to meet this criterion.
  
  radiusThreshold (optional): unit: Km. Default is 45 Km, designed for altimetry data due to its resolving capability. Note: this is an artificial threshold that an detected eddy is required to meet this criterion.
  
## Outputs:

  ### Eddy: a structure array contains the properties of detected eddies:
  
    Eddy.type: polarity of detected eddy. -1 for cyclonic while 1 for anticyclonic.
    
    Eddy.center: longitude and latitude of eddy centroid.
    
    Eddy.amplitude: longitude and latitude of eddy's sla extreme as well as eddy's amplitude (set to positive no matter if it is cyclonic or anticyclonic. Unit: cm)
    
    Eddy.radius: radius of an circle that has the same area as the eddy area enclosed by the eddy edge. Unit: Km
    
    Eddy.edge: two vectors specify the longitudes and latitudes of eddy edge defined by the largest closed sla contour.
    
 ###  A NetCDF file will be generated if successful detection.
   
## Author:

  Dr. Chi Xu (SCSIO, CAS)
  
  SEP 07 2020
  
  http://data.scsio.ac.cn/characteristic/zhongchiduwo

This function is provided "as is" without warranty of any kind.
