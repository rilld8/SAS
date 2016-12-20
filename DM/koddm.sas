/* wkleiæ plik z formatami do folderu wskazanego w bibliotece formlib poni¿ej,
zapisaæ poni¿sze 3 linijki w kodzie uruchomieniowym projektu SAS EM */
libname formlib "C:\Users\rilld8\Documents\My SAS Files\9.4";
options fmtsearch=(formlib work library);
run;


data formlib.de_ess_dm;
set tmp2.de_ess (keep= vote tvtot tvpol polintr psppsgv trstprl trstep stflife stfeco stfgov 
imbgeco happy rlgdgr eimpcnt fclcntr alpfpne alpfpe gndr agea maritalb domicil emplrel estsz hinctnta impsafe impfree
dweight);
where vote in (1:2);
run;
