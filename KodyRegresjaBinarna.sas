libname essout 'C:\Users\rilld8\Documents\My SAS Files\9.4\RL';
libname out 'C:\Users\rilld8\Documents\My SAS Files\9.4\RL';

/*Wczytanie zbioru danych dla Niemczech */
data Essout.DE_Ess;
set Out.Ess7e02_0_f1(keep= idno --region dweight) ;
where cntry='DE';
run;

/* Stworzenie interesuj¹cego nas zbioru danych z uwzglêdnieniem zmiennych objaœniaj¹cych */
data Out.zbior;
set essout.de_ess
(keep=health gndr agea domicil cgtsmke dosprt eatveg alcfreq slprl dweight);
where (health in (1:5)); /* Wybór obserwacji dla których nie brakuje zmiennej celu - health */
run;

/* Czêstoœci dla zmiennej celu, 
pomagaj¹ okreœliæ podzia³ zbioru.
Otrzymujemy informacje, ¿e 62% respondentów odpowiedzia³o, 
¿e ich stan zdrowia jest dobry lub bardzo dobry */
proc freq data=out.zbior;
tables health;
weight dweight;
run;

/* Przekodowanie zmiennej health na binarn¹,
 interesuj¹ce nas zdarzenie to pozytywna ocena stanu zdrowia - 1 */
data out.zbior1;
set out.zbior;
if health<=2 then health=1;
if health>=3 then health=0;
run;

/* Formatowanie zmiennej celu*/
proc format;
value health_f
1='Dobry'
0='Z³y';
run;

data out.zbior1;
set out.zbior1;
format health health_f.;
run;

proc sort data=out.zbior1;
by health;
run;

proc freq data=out.zbior1;
tables health;
weight dweight;
run;

/* Przekodowanie zmiennych 
Sprawdzenie czêstoœci zmiennych, które pos³u¿¹ do okreœlenia podzia³u na poszczególne kategorie*/
proc freq data=out.zbior1;
tables health gndr domicil cgtsmke dosprt eatveg alcfreq slprl;
by health;
weight dweight;
run;

data out.zbior2;
set out.zbior1;
if domicil <= 2 then domicil = 1;
if domicil = 3 then domicil = 2;
if domicil >= 4 then domicil = 3;

if cgtsmke <=2 then cgtsmke = 1 ;
if cgtsmke in (3:4) then cgtsmke = 2;
if cgtsmke = 5 then cgtsmke = 3;

if dosprt <= 2 then dosprt = 1;
if dosprt in (3:5) then dosprt = 2;
if dosprt >=6 then dosprt = 3;

if eatveg <= 2 then eatveg = 1;
if eatveg = 3 then eatveg = 2;
if eatveg >=4 then eatveg=3;

if alcfreq <= 3 then alcfreq = 1;
if alcfreq in (4:6) then alcfreq = 2;
if alcfreq = 7 then alcfreq = 3;

if slprl = 1 then slprl = 1;
if slprl = 2 then slprl=2;
if slprl >= 3 then slprl=3;
run;


proc format;
value domicil_f
1='Du¿e miasto'
2='Ma³e miasto'
3='Wieœ';
value cgtsmke_f
1 = 'Palacz'
2 = 'By³y palacz'
3 = 'Osoba niepal¹ca';
value dosprt_f
1 = 'Osoba ma³o aktywna'
2 = 'Osoba aktywna'
3 = 'Osoba bardzo aktywna';
value eatveg_f
1 = 'dwa razy dziennie'
2 = 'raz dziennie'
3 = 'mniej ni¿ raz dziennie';
value alcfreq_f
1 = 'Czêsto'
2 = 'Czasami'
3 = 'Nigdy';
value slprl_f
1 = 'Spokojny'
2 = 'Raczej spokojny'
3 = 'Niespokojny';
value gndr_f
1 = 'M'
2 = 'K';
run;
data out.RL_bin;
set out.zbior2;
format domicil domicil_f.;
format cgtsmke cgtsmke_f.;
format dosprt dosprt_f.;
format eatveg eatveg_f.;
format alcfreq alcfreq_f.;
format slprl slprl_f.;
format gndr gndr_f.;
run;


proc freq data=out.rl_bin;
table health;
weight dweight;
title "Rozk³ad zmiennej 'health'";
run;

/* Kod dla wykresów rozk³adu zmiennych objaœniaj¹cych wzglêdem zmiennej 'health' */
	PATTERN1 COLOR=RED;
	PATTERN2 COLOR=GREEN;
Legend1
	FRAME
	POSITION = (BOTTOM CENTER OUTSIDE)
	LABEL=(   "Subiektywny stan zdrowia");
Axis1
	STYLE=1
	WIDTH=1
	MINOR=NONE;
Axis2
	STYLE=1
	WIDTH=1
	LABEL=( FONT='Arial /b'   "Rozk³ad aktywnoœci fizycznej");
TITLE;
TITLE1 "Rozk³ad zmiennej dosprt wzglêdem zmiennej health";
PROC GCHART DATA=out.RL_BIN;
	VBAR dosprt / SUBGROUP=health
	CLIPREF
FRAME	DISCRETE
	TYPE=FREQ
	INSIDE=PCT
	LEGEND=LEGEND1
	COUTLINE=BLACK
	RAXIS=AXIS1
	MAXIS=AXIS2;
RUN; 
QUIT;

/*Procedura PROC LOGISTIC u¿yta do stworzenia modelu regresji logistycznej binarnej dla wszystkich zmiennych*/

PROC LOGISTIC DATA=out.rl_bin
		PLOTS(ONLY)=ODDSRATIO
		PLOTS(ONLY)=ROC;
	CLASS gndr 	(PARAM=REF REF='1') slprl 	(PARAM=REF REF='1') alcfreq 	(PARAM=REF REF='1') cgtsmke 	(PARAM=REF REF='3') dosprt 	(PARAM=REF REF='1') domicil 	(PARAM=ORDINAL);
	WEIGHT dweight;
	MODEL health (Event = '1')=agea gndr slprl alcfreq cgtsmke dosprt domicil /
		SELECTION=NONE
		SLE=0.05
		SLS=0.05
		INCLUDE=0
		CORRB
		COVB
		INFLUENCE
		LACKFIT
		AGGREGATE SCALE=NONE
		RSQUARE
		LINK=LOGIT
		CLPARM=BOTH
		CLODDS=BOTH
		ALPHA=0.05
	;

	OUTPUT OUT=out.rl_bin_pred(LABEL="Statystyki i prognozy regresji logistycznej")
		PREDPROBS=INDIVIDUAL
		RESCHI=reschi_health 
		RESDEV=resdev_health 
		DIFCHISQ=difchisq_health 
		DIFDEV=difdev_health ;
RUN;
QUIT;


/*Procedura PROC LOGISTIC u¿yta do stworzenia modelu regresji logistycznej binarnej z krokowym wyborem zmiennych*/
PROC LOGISTIC DATA=out.rl_bin
		PLOTS(ONLY)=ODDSRATIO
		PLOTS(ONLY)=ROC;
	CLASS gndr 	(PARAM=REF REF='1') slprl 	(PARAM=REF REF='1') alcfreq 	(PARAM=REF REF='1') cgtsmke 	(PARAM=REF REF='3') dosprt 	(PARAM=REF REF='1') domicil 	(PARAM=ORDINAL);
	WEIGHT dweight;
	MODEL health (Event = '1')=agea gndr slprl alcfreq cgtsmke dosprt domicil /
		SELECTION=STEPWISE
		SLE=0.05
		SLS=0.05
		INCLUDE=0
		CORRB
		COVB
		INFLUENCE
		LACKFIT
		AGGREGATE SCALE=NONE
		RSQUARE
		LINK=LOGIT
		CLPARM=BOTH
		CLODDS=BOTH
		ALPHA=0.05
	;

	OUTPUT OUT=out.rl_bin_pred(LABEL="Statystyki i prognozy regresji logistycznej")
		PREDPROBS=INDIVIDUAL
		RESCHI=reschi_health 
		RESDEV=resdev_health 
		DIFCHISQ=difchisq_health 
		DIFDEV=difdev_health ;
RUN;
QUIT;











