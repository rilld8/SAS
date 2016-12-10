libname essout 'C:\Users\rilld8\Documents\My SAS Files\9.4\RL';
libname out 'C:\Users\rilld8\Documents\My SAS Files\9.4\RL';

/*Wczytanie zbioru danych dla Niemczech */
data Essout.DE_Ess;
set Out.Ess7e02_0_f1(keep= idno --region dweight) ;
where cntry='DE';
run;

/* Stworzenie interesuj�cego nas zbioru danych z uwzgl�dnieniem zmiennych obja�niaj�cych */
data Out.zbior;
set essout.de_ess
(keep=health gndr agea domicil cgtsmke dosprt eatveg alcfreq slprl dweight);
where (health in (1:5)); /* Wyb�r obserwacji dla kt�rych nie brakuje zmiennej celu - health */
run;

/* Cz�sto�ci dla zmiennej celu, 
pomagaj� okre�li� podzia� zbioru.
Otrzymujemy informacje, �e 62% respondent�w odpowiedzia�o, 
�e ich stan zdrowia jest dobry lub bardzo dobry */
proc freq data=out.zbior;
tables health;
weight dweight;
run;

/* Przekodowanie zmiennej health na binarn�,
 interesuj�ce nas zdarzenie to pozytywna ocena stanu zdrowia - 1 */
data out.zbior1;
set out.zbior;
if health<=2 then health=1;
if health>=3 then health=0;
run;

/* Formatowanie zmiennej celu*/
proc format;
value health_f
1='Dobry'
0='Z�y';
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
Sprawdzenie cz�sto�ci zmiennych, kt�re pos�u�� do okre�lenia podzia�u na poszczeg�lne kategorie*/
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
1='Du�e miasto'
2='Ma�e miasto'
3='Wie�';
value cgtsmke_f
1 = 'Palacz'
2 = 'By�y palacz'
3 = 'Osoba niepal�ca';
value dosprt_f
1 = 'Osoba ma�o aktywna'
2 = 'Osoba aktywna'
3 = 'Osoba bardzo aktywna';
value eatveg_f
1 = 'dwa razy dziennie'
2 = 'raz dziennie'
3 = 'mniej ni� raz dziennie';
value alcfreq_f
1 = 'Cz�sto'
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














proc format;
value domicil_f
1='Du�e miasto'
2='Ma�e miasto'
3='Wie�';
value tvpol_f
1 = 'Mniej niz 0,5h'
2 = 'Wiecej niz 0,5h';
value polintr_f
1 = 'Bardzo zainteresowany'
2 = 'Zainteresowany'
3 = 'Nie zainteresowany';
value ipfrule_f
1 = 'Wa�ne'
2 = 'Ma�o wa�ne'
3 = 'Niewa�ne';
value impfree_f
1 = 'Wa�ne'
2 = 'Troch� wa�ne'
3 = 'Niewa�ne';
value impsafe_f
1 = 'Wa�ne'
2 = 'Ma�o wa�ne';
value ipadvnt_f  
1 = 'Wa�ne'
2 = 'Niewa�ne';
value gndr_f
1 = 'M'
2 = 'K';
run;

data out.zbior2;
set out.zbior2;
format domicil domicil_f.;
format tvpol tvpol_f.;
format polintr polintr_f.;
format ipfrule ipfrule_f.;
format impfree impfree_f.;
format impsafe impsafe_f.;
format impadvnt impadvnt_f.;
format gndr gndr_f.;
run;

