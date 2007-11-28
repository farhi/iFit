function loaders = iData_load_ini
% formats = iData_load_ini
%
% User definitions of specific import formats to be used by iData/load
%
% Each format is specified as a structure with the following fields
%   method:   function name to use, called as method(filename, options...)
%   patterns: list of strings to search in data file. If all found, then method
%             is qualified
%   name:     name of the method/format
%   options:  additional options to pass to the method.
%             If given as a string they are catenated with file name
%             If given as a cell, they are given to the method as additional arguments
%   postprocess: function to call after file import, to assign aliases, ...
%             called as iData=postprocess(iData)
%
% formats should be sorted from the most specific to the most general.
% Formats will be tried one after the other, in the given order.
% System wide loaders are tested after user definitions.
%
% See also: iLoad, save, iData/saveas

    format1.name       ='ILL Data (normal integers)';
    format1.patterns   ={'RRRR','AAAA','FFFF','SSSS','IIII'};
    format1.options    ='--headers --fortran --catenate --fast --binary --makerows=IIII --makerows=FFFF';
    format1.method     ='looktxt';
    format1.postprocess='';
    
    format2.name       ='ILL Data (large integers)';
    format2.patterns   ={'RRRR','AAAA','FFFF','SSSS','JJJJ'};
    format2.options    ='--headers --fortran --catenate --fast --binary --makerows=JJJJ --makerows=FFFF';
    format2.method     ='looktxt';
    format2.postprocess='';
    
    format3.name       ='ILL Data (floats only)';
    format3.patterns   ={'RRRR','AAAA','FFFF','SSSS'};
    format3.options    ='--headers --fortran --catenate --fast --binary --makerows=FFFF';
    format3.method     ='looktxt';
    format3.postprocess='';
    
    format4.name       ='ILL Data (general)';
    format4.patterns   ={'SSSS'};
    format4.options    ='--headers --fortran --catenate --fast --binary --makerows=FFFF --makerows=JJJJ --makerows=IIII';
    format4.method     ='looktxt';
    format4.postprocess='';
    
    format5.name       ='ILL TAS Data (polarized)';
    format5.patterns   ={'ILL TAS data','RRRR','AAAA','VVVV','POLAN'};
    format5.options    ='--headers --section=PARAM --section=VARIA --section=ZEROS --section=POLAN --metadata=DATA';
    format5.method     ='looktxt';
    format5.postprocess='';
    
    format6.name       ='ILL TAS Data';
    format6.patterns   ={'ILL TAS data','RRRR','AAAA','VVVV'};
    format6.options    = '--headers --section=PARAM --section=VARIA --section=ZEROS --metadata=DATA';
    format6.method     ='looktxt';
    format6.postprocess='';
    
    format7.name       ='SPEC';
    format7.patterns   ={'#F','#D','#S'};
    format7.options    ='--headers --metadata="#S " --comment= ';
    format7.method     ='looktxt';
    format7.postprocess='';
 
    loaders= { format1, format2, format3, format4, format5, format6, format7 };
    




