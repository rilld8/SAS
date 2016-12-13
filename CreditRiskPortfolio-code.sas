/*Projekt SAS - analiza vintage*/
/*Autorzy - Anna Karowiec, Szymon Ptaszyñski, Karol Szerszeñ*/


/*deklaracje bibliotek potrzebnych do kodow dr Przanowskiego*/
%let dir=C:\Apps\SAS projekt\Source\danewyj\;
%let dir_projekt=C:\Apps\SAS projekt\Source\danewyj\Dane\;

libname wej "&dir_projekt" compress=yes;
libname wyj "&dir.wyj" compress=yes;

%let zb1 = wej.Production;
%let zb = wyj.vin;
%let tar=vin3;


/*poczatek definicji zmiennych - kod definicja_zmiennych dr Przanowskiego*/

/*tworzymy tabele zmienne_definicja do przechowywania nazw zmiennych*/
/*za pomoca funkcji dictionary.columns wyciagamy wszystkie zmienne*/
/*do zmienne_definicja wrzucamy zmienne numeryczne dla interesujacych nas kategorii AGR, ACT, AGS, APP*/
proc sql noprint;
	create table wyj.zmienne_definicja as
	select 
			name as zmienna, 
			'int' as typ, 
			'y' as wer
	from dictionary.columns 
	where
		libname=upcase("%scan(&zb1,1,.)") 
		and memname=upcase("%scan(&zb1,2,.)")
		and 
		(
		    upcase(name) like 'AGR%'
		 or upcase(name) like 'ACT%'
		 or upcase(name) like 'AGS%'
		 or upcase(name) like 'APP%')
		and  type='num'
		; 
quit; 
/*stworzenie tabeli nom zawierajacej zmienne nominalne*/
proc sql noprint;
	create table nom as
	select 
		name as zmienna, 
		'nom' as typ, 
		'y' as wer
	from dictionary.columns 
	where
		libname=upcase("%scan(&zb1,1,.)") 
		and memname=upcase("%scan(&zb1,2,.)")
		and (upcase(name) like 'APP%' 
		  or upcase(name) like 'AGR%'
		  or upcase(name) like 'AGS%'
		  or upcase(name) like 'ACT%')
		and  type='char'; 

	select zmienna 
	into :zm separated by ' '
	from nom;
quit; 
%let il=&sqlobs;
%put &il***&zm;
/*makro tworzace zbior uni zawierajacy wszystkie zmienne nominalne oraz ich ilosc w zbiorze production*/
%macro licz;
	data uni;
		length zmienna $32 il 8;
		delete;
	run;

	%do i=1 %to &il;
		%let z=%scan(&zm,&i,%str( ));
		proc sql;
			insert into uni
			select "&z" as zmienna, count(distinct &z) as il
			from &zb1;
		quit;
	%end;
%mend;
%licz;
/*do tabeli zmienne_definicja zawierajacej zmienne numeryczne dorzucamy zmienne nominalne*/
proc sql;
	insert into wyj.zmienne_definicja 
	select 
		zmienna, 
		'nom' as typ, 
		'y' as wer
	from uni 
	where il<=220 and il>=2
	;
quit;

proc sort data=wyj.zmienne_definicja;
by zmienna;
run;
/*tworzymy makrozmienna zmienne_int_ord w której przechowywane s¹ wszystkie nasze zmienne*/
proc sql noprint;
	select upcase(zmienna) 
	into :zmienne_int_ord separated by ' '
	from wyj.zmienne_definicja 
	where typ in ('int', 'nom');
quit;
%let il_zm=&sqlobs;


%put ***&il_zm.***&zmienne_int_ord;
/*powy¿sze makrozmienne przechowuja liczbe zmiennych oraz ich nazwy*/
/*koniec definicji zmiennych*/

%macro produkty_wszystkie;

%global produkt;
%global ilosc_prod;
%global nr_produktu;
data produkty;
	format product $10. product_where $30.;
	if product = "" then delete;
run;

/*dodanie unikalnych produktow i total do listy produktow*/	
proc sql;
	insert into produkty
	select distinct product, strip("where product="||strip(product)) as 
	product_where from wej.Transactions; 
	insert into produkty values ("total", "where 1=1");
quit;
/*numeracja produktow*/
data produkty;
	set produkty;
	lp = _N_;
run;

proc sql noprint;
select strip(product) 
	into :produkt separated by ' '
	from produkty;
quit;

proc sql noprint;
select lp into :nr_produktu separated by ' ' from produkty;
quit;

proc sql noprint;
	select count(*) into :ilosc_prod from produkty;
quit;

%put &ilosc_prod;
%put &produkt;
%put &nr_produktu;

%mend produkty_wszystkie;
/*koniec produktow*/
%produkty_wszystkie;
%put &produkt;
%macro stworz_zbior(produkt2);

%do i = 1 %to &ilosc_prod;
	%let produkt=%scan(&produkt2,&i,%str( )); 

data vin0;
set wej.Transactions;
seniority=intck('month',input(fin_period,yymmn6.),input(period,yymmn6.));
vin3=(due_installments>=3);
output;
if status in ('B','C') and period<='200812' then do;
	n_steps=intck('month',input(period,yymmn6.),input('200812',yymmn6.));
	do i=1 to n_steps;
		period=put(intnx('month',input(period,yymmn6.),1,'end'),yymmn6.);
		seniority=intck('month',input(fin_period,yymmn6.),input(period,yymmn6.));
		output;
	end;
end;
where product="&produkt.";
keep aid fin_period vin3 seniority;
run;

data vin12;
	set vin0;
	where seniority = 12;
run;

proc sort data=vin12 nodupkey;
by aid;
run;


data vin02;
	set wej.Production;
	array Var _numeric_;
	do over Var;
		if Var =.M then Var = .;
	end;
run;

proc sort data=vin02 (keep=aid &zmienne_int_ord) out=prod;
by aid;
run;

data wyj.vin_&produkt;
merge vin12(in=z) prod;
by aid;
if z;
run;
%end;
%mend stworz_zbior;

%stworz_zbior(&produkt);


data wyj.vin;
merge wyj.vin_ins wyj.vin_css;
by aid;
run;


/*poczatek kategoryzacji zmiennych za pomoca kodu tree dr Przanowskiego*/
/*kod skopiowany, bez zmian poza iloscia podzialow ustalona na 3-1 = 2 
i minimalna liczba obserwacji na 2 procent, w celu zwiekszenia liczby kategorii
dla wiekszosci zmiennych do 3*/

libname t (wyj);
%let kat_tree=%sysfunc(pathname(wyj));
%put &kat_tree;

/*maksymalna liczba podzia³ów minus 1*/
%let max_il_podz=2;
/*minimalna liczba obs w liœciu*/
%let min_percent=2;

data _null_;
	set &zb(obs=1 keep=&tar) nobs=il;
	min_il=int(&min_percent*il/100);
	call symput('min_il',trim(put(min_il,best12.-L)));
run;
%put &min_il;
/*kyterium albo h albo g;*/
%let crit=h;



%macro zrob_podz(zm);
	/*obcinanie skrajnych*/
	%let cent=1;
	%let dop=%eval(100-&cent);

	data zzm;
		set &zb(keep=&tar &zm);
	run;

	proc means data=zzm nway noprint;
		var &zm;
		output out=cen p&cent=p1 p&dop=p99;
	run;
	data _null_;
		set cen;
		call symput("p1",put(p1,best12.));
		call symput("p99",put(p99,best12.));
	run;
	%put ***&p1***&p99***;

	proc means data=zzm nway noprint;
		class &zm;
		var &tar;
		output out=t.stat(drop= _freq_ _type_) sum()=sum n()=n;
	run;

	/*Tu w tym zbiorze bed¹ liœcie*/
	data t.warunki;
		length g_l g_p war $300 zmienna $32;
		g_l='low'; g_p='high'; criterion=0; dzielic=1;nrobs=1;glebokosc=1;
		length  il_jed_at il_at 8;
		war="not missing(&zm)";
		zmienna="&zm";
	run;

%macro krok(nr_war);
	proc sql noprint;
		select war,criterion 
		into :war,:c 
		from t.warunki(obs=&nr_war firstobs=&nr_war);

		%let zb_krok=t.stat(where=(&war));

		select 
			sum(n) as il,
			sum(sum) as il_jed, 
			calculated il - calculated il_jed
		into :il,:il_jed,:il_zer
		from &zb_krok;
	quit;
	%put &il;
	%put &war;
	%global jest;
	%let jest=.;
	data krok;
		retain il_zer &il_zer il_jed &il_jed il &il;
		retain max_h max_g -10;
		retain max_h_v max_g_v;
		retain max_g_poww max_g_pon max_h_poww max_h_pon;
		retain 
		opt_g_il_jed_poww 
		opt_g_il_jed_pon  
		opt_g_il_poww     
		opt_g_il_pon      

		opt_h_il_jed_poww 
		opt_h_il_jed_pon  
		opt_h_il_poww     
		opt_h_il_pon
		;

		set &zb_krok end=e;

		cum_sum+sum;
		cum_n+n;
		il_jed_poww=cum_sum;
		il_jed_pon=il_jed-cum_sum;
		il_zer_poww=cum_n-cum_sum;
		il_zer_pon=il_zer-il_zer_poww;
		il_poww=cum_n;
		il_pon=il-cum_n;

		g_poww=(1-((il_jed_poww/il_poww)**2+(il_zer_poww/il_poww)**2));
		g_pon=(1-((il_jed_pon/il_pon)**2+(il_zer_pon/il_pon)**2));
		g=1-((il_jed/il)**2+(il_zer/il)**2)
		-g_poww*il_poww/il
		-g_pon*il_pon/il;

		h_poww=-((il_jed_poww/il_poww)*log2(il_jed_poww/il_poww)+(il_zer_poww/il_poww)*log2(il_zer_poww/il_poww));
		h_pon=-((il_jed_pon/il_pon)*log2(il_jed_pon/il_pon)+(il_zer_pon/il_pon)*log2(il_zer_pon/il_pon));
		h=-((il_jed/il)*log2(il_jed/il)+(il_zer/il)*log2(il_zer/il))     
		-h_poww*il_poww/il
		-h_pon*il_pon/il;


		if il_poww<&min_il or il_pon<&min_il then do;
			h=.;
			g=.;
		end;


		if h>max_h and h ne . then do;
			max_h=h;
			max_h_v=&zm;
			max_h_poww=h_poww;
			max_h_pon=h_pon;

			opt_h_il_jed_poww =il_jed_poww ;
			opt_h_il_jed_pon  =il_jed_pon  ;
			opt_h_il_poww     =il_poww     ;
			opt_h_il_pon      =il_pon      ;

		end;

		if g>max_g and g ne . then do;
			max_g=g;
			max_g_v=&zm;
			max_g_poww=g_poww;
			max_g_pon=g_pon;

			opt_g_il_jed_poww =il_jed_poww ;
			opt_g_il_jed_pon  =il_jed_pon  ;
			opt_g_il_poww     =il_poww     ;
			opt_g_il_pon      =il_pon      ;

		end;

		if _error_=1 then _error_=0;

		if e;

		if max_&crit._v eq . then call symput('jest','.');
		else do;
			if max_&crit._poww>=&c or max_&crit._pon>=&c then call symput('jest','ok');
			else call symput('jest','.');
		end;
		keep max_h_v max_g_v max_g_poww max_g_pon max_h_poww max_h_pon
		opt_g_il_jed_poww 
		opt_g_il_jed_pon  
		opt_g_il_poww     
		opt_g_il_pon      

		opt_h_il_jed_poww 
		opt_h_il_jed_pon  
		opt_h_il_poww     
		opt_h_il_pon
		;
	run;
	%put jest***&jest;

	%if "&jest" ne "." %then %do; 
	/*%if "&jest" ne ".           " %then %do; */

	data t.warunki;
		length prawy $300;
		obs=&nr_war;
		modify t.warunki point=obs;
		prawy=g_p;
		set krok;
		g_p=put(max_&crit._v,best12.-L);
		criterion=max_&crit._poww;
		if g_l ne 'low' then war=trim(g_l)||" < &zm <= "||trim(g_p);
		else war="not missing(&zm) and &zm <= "||trim(g_p);
		dzielic=1;
		glebokosc=glebokosc/2;

		il_jed_at=opt_&crit._il_jed_poww;
		il_at=opt_&crit._il_poww;

		replace;
		g_l=put(max_&crit._v,best12.-L);
		g_p=trim(prawy);
		criterion=max_&crit._pon;
		if g_p ne 'high' then war=trim(g_l)||" < &zm <= "||trim(g_p);
		else war=trim(g_l)||" < &zm ";
		dzielic=1;
		nrobs=nrobs+0.5;

		il_jed_at=opt_&crit._il_jed_pon;
		il_at=opt_&crit._il_pon;

		output;
		stop;
	run;

	proc sort data=t.warunki;
		by nrobs;
	run;

	data t.warunki;
		modify t.warunki;
		nrobs=_n_;
		replace;
	run;

	%end; %else %do;
	data t.warunki;
	obs=&nr_war;
	modify t.warunki point=obs;
	dzielic=0;
	replace;
	stop;
	run;
	%end;

%mend krok;

%macro podzialy;
	%do i=1 %to &max_il_podz;

		%let nr_war=pusty;
		proc sql noprint;
			select nrobs 
			into :nr_war
			from t.warunki
			where dzielic=1
			order by glebokosc desc, criterion;
		quit;
		%if "&nr_war" ne "pusty" %then %do;
			%krok(&nr_war);
		%end;

	%end;
%mend podzialy;
%podzialy;
%mend;


%macro dla_wszystkich_zm;

data t.podzialy;
length g_l g_p war $300 zmienna $32;
g_l='low'; g_p='high'; criterion=0; dzielic=1;nrobs=1;glebokosc=1;
length  il_jed_at il_at 8;
delete;
run;

/*%do nr_zm=1 %to 1;*/
%do nr_zm=1 %to &il_zm;


%zrob_podz(%upcase(%scan(&zmienne_int_ord,&nr_zm,%str( ))));

proc append base=t.podzialy data=t.warunki;
run;
%end;

%mend;

%dla_wszystkich_zm;

data t.podzialy_int_niem;
set t.podzialy;
keep zmienna war nrobs;
rename nrobs=grp;
run;


/*stworzenie zbioru z zmiennymi skategoryzowanymi z dodatkowa zmienna do petli
kategoryzujacej dane*/
data t.podzialy_int_niem_lp;
set t.podzialy_int_niem;
lp = _N_;
run;
/*okreslenie ilosci zmiennych skategoryzowanych*/
proc sql noprint;
select war into :ilosc_obs_kat separated by " " from t.podzialy_int_niem_lp; 
quit;
%let ilosc_obs_kat=&sqlobs;
%put &ilosc_obs_kat;
/*makro tworzace zbior z danymi ze skategoryzowanymi wartosciami*/


%macro dane_skat;
data &zb._kat;
	set &zb;
run;
%do i=1 %to &ilosc_obs_kat;
	
	data _null_;
		set t.podzialy_int_niem_lp  (where=(lp=&i));
		call symput("war_kat", strip(war));
		call symput("zmienna_kat", strip(zmienna));
		call symput("grp_kat", strip(grp));
	run;
/*makrozmienna jest tekstowa, war_kat jest warunkiem typu: wartosc < zmienna < wartosc2*/
/*linijke z if czytamy: jesli zmienna jest miedzy wartosc a wartosc 2 to za wartosc zmiennej
podstaw numer jej grupy po kategoryzacji*/
	
	data &zb._kat;
		set &zb._kat;
		if &war_kat then &zmienna_kat = &grp_kat;
	run;
%end;
%mend dane_skat;

%dane_skat
/**/
/*/*tworzenie zbioru wejsciowego z podzialem na produkty*/*/
/*%macro po_produktach(produkt11);*/
/*	%do i =1 %to &ilosc_prod;*/
/*	*/
/*		%let produkt1=%scan(&produkt11,&i,%str( ));*/
/*		%put &produkt1;			*/
/*		*/
/*		%stworz_zbior(&produkt1);*/
/*		*/
/*		data wyj.vin_&produkt1._kat;*/
/*			set wyj.vin_&produkt1;*/
/*		run;*/
/*	*/
/*		*/
/*	%end;*/
/*%mend po_produktach;*/
/*%po_produktach(&produkt);*/
/**/
/*/*tworzenie grup zmiennych*/*/


/*stworzenie grup dla zmiennych*/;
%global etykiety_grup=act ags app agr;
%put &etykiety_grup;

/*makro liczace korelacje dla danej grupy zmiennych*/
%macro korelacja(grupa);

data wej_korr_&grupa;
set wyj.vin_kat (keep=&grupa.: vin3);
run;	

proc corr data=wej_korr_&grupa. spearman vardef=df noprint out=wyj_korr_&grupa.;
run;

data wyj_korr_&grupa._sort;
	set wyj_korr_&grupa;
	vinabs=abs(vin3);
	where _name_ is not null and _name_ ne 'vin3';
	keep _name_ vinabs;
run;

proc sort data=wyj_korr_&grupa._sort out=corr_best_&grupa; 
	by descending vinabs;
run;

/*wybranie 5 najlepszych zmiennych dla kazdej z grup*/
data corr_best_&grupa._5;
set corr_best_&grupa(obs=5);
run;
%mend korelacja;


/*obliczenie najlepszych wsp. korelacji dla kazdej z grup zmiennych*/
%macro po_grupach(produkty, n_grupy);
		%let produkt1=%scan(&produkty,&i,%str( ));
			
				
			%let il_grup=4;
			%do j=1 %to &il_grup;
			%let grupa=%scan(&n_grupy,&j,%str( ));
					
			%korelacja(&grupa);
				
			%put &grupa;
		%end;
%mend;

%po_grupach(&produkt, &etykiety_grup);

/*stworzenie zbiorów (makrozmiennych) z iloscia i nazwami najlepszych zmiennych*/
%macro besties;
%global zmienna_best_1;
%global ilosc_best_zmienne1;

data best_zmienne;
set corr_best_act_5 corr_best_ags_5 corr_best_agr_5 corr_best_app_5;
where vinabs is not missing;
run;

proc sql noprint;
select _name_ into :zmienna_best_1 separated by ' ' from best_zmienne;
quit;
%put &zmienna_best_1;

proc sql noprint;
select count(*) into :ilosc_best_zmienne1 from best_zmienne;
quit;

%put &ilosc_best_zmienne1;
/*koniec korelacji*/
%mend besties;

%besties;

/*raport z danymi do wykresów*/
%macro raport_dane(nazwa_zbioru);

/*przygotowanie danych do prognozy*/
proc means data=vin noprint nway;
	class fin_period seniority;
	var vin3;
	output out=vintagr(drop=_freq_ _type_) n()=production mean()=vintage3;
	format vintage3 nlpct12.2;
	
run;

proc means data=vin noprint nway;
	class fin_period;
	var vin3;
	output out=production(drop=_freq_ _type_) n()=production;
	where seniority=0;
run;

proc transpose data=vintagr out=vintage prefix=months_after_;
	by fin_period;
	var vintage3;
	id seniority;
run;

/*stworzenie zbioru do prognozy*/
data prediction;
	format data_spr yymmdd10.;
	set vintage (keep=fin_period months_after_12);
	data_spr = input(fin_period, yymmn6.);
	drop fin_period;
run;	

/*prognoza na podstawie szeregu czasowego, procesu ARMA(1,1)*/

/*okreslenie stacjonarnosci - szereg niestacjonarny :( */
proc arima data=prediction plots=all;
  	identify var=months_after_12 stationarity=(DICKEY) SCAN ESACF;
quit;
/*roznicowanie szeregu w celu 
otrzymania stacjonarnego szeregu czasowego potrzebnego do prognozy*/
data prediction_lag;
	set prediction;
	dif_months_after_12 = months_after_12 -lag1(months_after_12);
run;
/*okreœlenie stacjonarnoœci szeregu zró¿nicowanego - jest stacjonarny; 
okreslenie modelu za pomoca SCAN ESACF - proces ARMA(1,1)*/
proc arima data=prediction_lag plots=all;
  	identify var=dif_months_after_12 stationarity=(DICKEY) SCAN ESACF;
quit;

/*estymacja i prognoza zroznicowanego szeregu*/
proc arima data=prediction_lag plots=all;
	identify var=dif_months_after_12;
	estimate p=1 q=1 method=ml;
forecast lead = 12 id=data_spr interval=month out=prediction_lag1;
format dif_months_after_12 percent8.2;
quit; 

/*przygotowanie szeregu do integracji i integracja*/
data forecast_final;
	set prediction_lag1;
	if dif_months_after_12 = . then dif_months_after_12 = forecast;
run;

data merged_forecast;
	merge prediction forecast_final;
	retain forecast_123 0;
	if data_spr <= "01DEC2007"d then forecast_123 = months_after_12;
	else do;zmienna_lag=lag1(forecast);
	if  data_spr >= "01JAN2008"d then zmienna+forecast;else zmienna = zmienna_lag+forecast;
	end;
	total_forecast=forecast_123+zmienna;	
	format months_after_12 best12.;
	by data_spr;
run;

data prediction1 (rename=(months_after_12=forecast_12));
	format fin_period $10.;
	set merged_forecast;
	if data_spr >= "01DEC2007"d then months_after_12 = total_forecast;
	else months_after_12 = .;
	fin_period = put(data_spr, yymmn6.);
	keep fin_period months_after_12;
run;

data wyj.rap_&nazwa_zbioru;
	retain fin_period production forecast_12 months_after_0-months_after_35;
	merge vintage (drop=_name_) production prediction1;
	by fin_period;
run;

%mend raport_dane;
/*koniec raportu z danymi do wykresow*/

/*ustalamy ilosc opoznien w splacie na 3*/
%let il_due =3;
%put &il_due;

%put &ilosc_prod;

/*raport w htmlu*/
%macro raport_html(nazwa_zbioru);
%let	path_html=C:\Apps\SAS projekt\Source\Danewyj\raporty\html\;
	%put &path_html;
	%put &nazwa_zbioru;
	ods listing close;
	ods html path="&path_html" body="&nazwa_zbioru..html" file="&nazwa_zbioru..html" style=htmlblue;
	title;
	ods html text="<center><font size = 25> Raport vintage dla &nazwa_zbioru. </font></center>";
	ods html text="<center><a href='../excel/rap_&nazwa_zbioru..xlsx'>Link do raportu w Excelu</center>";		
	ods html text="<center><a href='../pdf/rap_&nazwa_zbioru..pdf'>Link do raportu w Pdfie</a href></center>";
	 					
			ods graphics on / imagename="rap_&nazwa_zbioru.";
			/*wykres do uzycia w htmlu i pdfie*/
			proc sgplot data=wyj.rap_&nazwa_zbioru. (where=(mod(month(input(fin_period, yymmn6.)), 3) = 0));
						vbar fin_period / response=production y2axis;
			   			vline fin_period / response=months_after_3;
						vline fin_period / response=months_after_6;
						vline fin_period / response=months_after_9;
						vline fin_period / response=months_after_12;
						vline fin_period / response=forecast_12;
						yaxis min=0 label="Vintage &i.+";
			run;
			ods graphics off;

	
	ods html close;	
	ods listing;

%mend raport_html;

%macro raport_pdf(nazwa_zbioru);
%let path_pdf=C:\Apps\SAS projekt\Source\Danewyj\raporty\pdf\;
ods listing gpath= "&path_pdf.";
ods graphics on / imagefmt=pdf imagename="rap_&nazwa_zbioru.";
			proc sgplot data=wyj.rap_&nazwa_zbioru. (where=(mod(month(input(fin_period, yymmn6.)), 3) = 0));
						title "Vintage dla &nazwa_zbioru";
						vbar fin_period / response=production y2axis;
			   			vline fin_period / response=months_after_3;
						vline fin_period / response=months_after_6;
						vline fin_period / response=months_after_9;
						vline fin_period / response=months_after_12;
						vline fin_period / response=forecast_12;
						yaxis min=0 label="Vintage &i.+";
			run;
			ods graphics off;
ods listing;

%mend raport_pdf;

%macro raport_excel(nazwa_zbioru);
%let path_excel=C:\Apps\SAS projekt\Source\Danewyj\raporty\excel\;
ods listing gpath= "&path_excel.";
ods excel file="&path_excel.\rap_&nazwa_zbioru..xlsx" style=pearl;
		ods graphics on;	
		proc sgplot data=wyj.rap_&nazwa_zbioru. (where=(mod(month(input(fin_period, yymmn6.)), 3) = 0));
						title "Vintage dla &nazwa_zbioru.";
						vbar fin_period / response=production y2axis;
			   			vline fin_period / response=months_after_3;
						vline fin_period / response=months_after_6;
						vline fin_period / response=months_after_9;
						vline fin_period / response=months_after_12;
						vline fin_period / response=forecast_12;
						yaxis min=0 label="Vintage &i+";
			run;
			ods graphics off;

ods excel close;
ods listing ;

%mend raport_excel;


%macro raporty_wszystkie;
%produkty_wszystkie;
%let il_due = 3;
	%put &ilosc_prod;
	%put &produkt;
%do j =1 %to &il_due;
%put &il_due;
%put &j;
	%do i = 1 %to &ilosc_prod;
		%let po_produktach=%scan(&produkt, &i, %str( ));
		%put &po_produktach;
		%if "&po_produktach" = "total" %then %do;
			
			proc sql noprint;
			create table wejscie_produkt as select * from wej.Transactions
			where aid in 
			(			select aid from wej.Production
						 
			);
			quit;
		%end;
		%else %do;
			
			proc sql noprint;
			create table wejscie_produkt as select * from wej.Transactions
			where aid in 
			(	select aid from wej.Production
				where product="&po_produktach"
			);
			quit;
		%end;
		
						data vin;
							set wejscie_produkt;
							seniority=intck('month',input(fin_period,yymmn6.),input(period,yymmn6.));
							vin3=(due_installments>=&j);
							output;
							if status in ('B','C') and period<='200812' then do;
								n_steps=intck('month',input(period,yymmn6.),input('200812',yymmn6.));
								do i=1 to n_steps;
									period=put(intnx('month',input(period,yymmn6.),1,'end'),yymmn6.);
									seniority=intck('month',input(fin_period,yymmn6.),input(period,yymmn6.));
									output;
								end;
							end;
							keep aid fin_period vin3 seniority;
						run;
						
			%let nazwa_zbioru1 = &j._&po_produktach;
			%put &nazwa_zbioru1;
			%raport_dane(&nazwa_zbioru1);
/*			%let nazwa_zbioru1 = &j._&po_produktach;*/
/*			%put &nazwa_zbioru1;*/
			%raport_html(&nazwa_zbioru1);
/*			%raport_excel(&nazwa_zbioru1);	*/
			%raport_pdf(&nazwa_zbioru1);


			%put &ilosc_best_zmienne1;
	%do k = 1 %to &ilosc_best_zmienne1;
	
	%let zmienne_best=%scan(&zmienna_best_1,&k,%str( ));
	
			proc sql noprint;
				create table zmienna_kat as select war, zmienna, grp, monotonic() as lp
				 from wyj.podzialy_int_niem
				where lowcase(zmienna) = strip(lowcase("&zmienne_best."));
				select count(*) into :liczba_kat from zmienna_kat;
			quit;
			
			%put &zmienne_best;
						
						%if "&po_produktach" = "total" %then %do;
						proc sql noprint;
								create table wejscie_produkt2 as
								select * from wej.Transactions
								where aid in
									(
										select aid from wej.Production
										where not missing (&zmienne_best.)
									);
						quit;
						%end;
						%else %do;
							proc sql noprint;
								create table wejscie_produkt2 as
								select * from wej.Transactions
								where aid in
									(
										select aid from wej.Production
										where product="&po_produktach" and not missing (&zmienne_best.)
									);
							quit;
						%end;


						data vin;
							set wejscie_produkt2;
							seniority=intck('month',input(fin_period,yymmn6.),input(period,yymmn6.));
							vin3=(due_installments>=&j);
							output;
							if status in ('B','C') and period<='200812' then do;
								n_steps=intck('month',input(period,yymmn6.),input('200812',yymmn6.));
								do i=1 to n_steps;
									period=put(intnx('month',input(period,yymmn6.),1,'end'),yymmn6.);
									seniority=intck('month',input(fin_period,yymmn6.),input(period,yymmn6.));
									output;
								end;
							end;
							keep aid fin_period vin3 seniority;
						run;
						%let nazwa_zbioru1=&j._&po_produktach._&zmienne_best;
						%raport_dane(&nazwa_zbioru1);
/*						%let nazwa_zbioru1=&j._&po_produktach._&zmienne_best;*/
/*						%put &nazwa_zbioru1;*/
						%raport_html(&nazwa_zbioru1);
/*						%raport_excel(&nazwa_zbioru1);*/
						%raport_pdf(&nazwa_zbioru1);

	%put &liczba_kat;
	%do m = 1 %to &liczba_kat;
	
				data _null_;
					set zmienna_kat (where=(lp=&m));
					Call Symput("zmienna", strip(zmienna));
					Call Symput("var_nr_kat", strip(grp));
					Call Symput("zmienna_warunek", strip(war));
				run;	
				%put &zmienna;
				%put &zmienna_warunek;
				%put &var_nr_kat;
						
						%if "&po_produktach"="total" %then %do;
							
							proc sql noprint;
									create table wejscie_produkt3 as
									select * from wej.Transactions
									where aid in
										(
											select aid from wej.Production
											where &zmienna_warunek. 
										);
							quit;
						%end;
						%else %do;
						
						proc sql noprint;
								create table wejscie_produkt3 as
								select * from wej.Transactions
								where aid in
									(
										select aid from wej.Production
										where &zmienna_warunek. and product = "&po_produktach" 
									);
						quit;
						%end;
						data vin;
							set wejscie_produkt3;
							seniority=intck('month',input(fin_period,yymmn6.),input(period,yymmn6.));
							vin3=(due_installments>=&j);
							output;
							if status in ('B','C') and period<='200812' then do;
								n_steps=intck('month',input(period,yymmn6.),input('200812',yymmn6.));
								do i=1 to n_steps;
									period=put(intnx('month',input(period,yymmn6.),1,'end'),yymmn6.);
									seniority=intck('month',input(fin_period,yymmn6.),input(period,yymmn6.));
									output;
								end;
							end;
							keep aid fin_period vin3 seniority;
						run;
						
			%let nazwa_zbioru1 = &j._&po_produktach._&zmienne_best._&var_nr_kat;
			%put &nazwa_zbioru1;
			%raport_dane(&nazwa_zbioru1);
			%let nazwa_zbioru1 = &j._&po_produktach._&zmienne_best._&var_nr_kat;
			%put &nazwa_zbioru1;
			%raport_html(&nazwa_zbioru1);
			%raport_excel(&nazwa_zbioru1);
			%raport_pdf(&nazwa_zbioru1);
	%end;
%end;
	%end;
%end;
%mend raporty_wszystkie;
%raporty_wszystkie;



proc means data=wyj.vin mean std median min max nmiss;
	var act_age app_income app_spendings app_number_of_children app_loan_amount;
run;
