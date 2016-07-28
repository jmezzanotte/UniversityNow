/* 
Author: John Mezzanotte
Project: UNOW 
Date Last Modified: 8-8-14
Purpose: analyze overall enrollment (Y/N, FT/PT), institution info 
	     (name, public/private, 2yr/4yr, CA/other state) and create initial 
		 tables.
source data: <data path>

Note on dual enrolled students: 
Dual enrolled students are handled as follows 
	- enrolled in 4yr & 2yr : keep 4yr 
	- enrolled in 2yr & 2yr : Keep either one, unless the school is SRJC, in 
	                          this case we will keep SRJC
	- enrolled in 4yr & 4yr : Keep if college type if is for profit
							  else, keep if college type is public 4 year
							  else, keep if college type is private 4 year							  
*/

clear 
set more off

global source "<DATA SOURCE PATH>"

capture log using "$output\ncsdata.smcl", replace

/* 
the only difference between the original UNOW_NSC_20131115searchdate.csv
file and the _clean version is that the original file
(UNOW_NSC_20131115searchdate.csv, featured a trailing "_" in the student id. 
In the clean version I striped the trailing "_" from the id then imported 
that file into Stata. 
*/

insheet using "$source\UNOW_NSC_20131115searchdate_clean.csv"

*******************************************************************************
************************* general data cleaning *******************************
*******************************************************************************

// requesterreturnfield is the srjcid
rename requesterreturnfield srjcid

* youruniqueidentifier has no data; drop it
drop youruniqueidentifier namesuffix

/* The only reason I re-coded these was so I would not have to keep looking 
back at the codebook to see actual values of the variables */
replace enrollmentstatus = "Full-time" if enrollmentstatus == "F"
replace enrollmentstatus = "Half-time" if enrollmentstatus == "H"
replace enrollmentstatus = "Less than half-time" if enrollmentstatus == "L"
replace enrollmentstatus = "Withdrawn" if enrollmentstatus == "W"
replace enrollmentstatus = "Leave of absense" if enrollmentstatus == "A"
replace enrollmentstatus = "Deceased" if enrollmentstatus == "D"

/* Convert values in enrollment variables into valid dates (searchdate, 
enrollmentbegin, enrollmentend */
foreach var in enrollmentend enrollmentbegin searchdate {
	tostring `var', replace
	gen `var'_clean = date(`var', "YMD")
	format `var'_clean %td
	}

/* Identify those students who have a enrollment begining "and" end month of 08 
or 09 we would like to be able to control these cases when we analyze
enrollment */

/* this will extract the month out of the date for enrollmentbegin and 
enrollmentend. This code will also concatenate both results into one string.
the values of 0808 and 0809 are those we are interested in. These values 
represent a begining month of 08 and and end month of 08, for example. */
gen enrol_beg_end = "b" + substr(enrollmentbegin, 5,2) + "e" + ///
substr(enrollmentend, 5, 2)

* missing values were given a value of "be", change them back to missing
replace enrol_beg_end = "" if enrol_beg_end == "be"

label variable enrol_beg_end "enrol begin month followed by enrol end month"

gen enrollmentstatus_binned = 1 if enrollmentstatus == "Full-time" 
replace enrollmentstatus_binned = 2 if enrollmentstatus == "Half-time" | ///
enrollmentstatus == "Less than half-time" 
replace enrollmentstatus_binned = . if enrollmentstatus == "Withdrawn"

label define enrl_binned_lab 1 "Full-time" 2 "Part-time"

label values enrollmentstatus_binned enrl_binned_lab

/*
commented out on 8/13/14 -- we don't need this variable 
* Create a dichotomous enrollmentstatus variable (fulltime or not)

gen enrollmentstatus_dich = . 
replace enrollmentstatus_dich = 1 if enrollmentstatus == "Full-time" | ///
                                     enrollmentstatus == "Half-time" | ///
								     enrollmentstatus == "Less than half-time" 
replace enrollmentstatus_dic = 0  if enrollmentstatus == "Withdrawn"

sort srjcid
*/								  								   
************************** Drop UNOW students **********************************
								  
/* Use <FILE PATH DELETED>, there are 20 
unow students */

/* Think of this as ascreener. I am trying to see if there are any unow students 
in the NSC data. by merging our list of srjcid's associated with known unow 
students into the nsc we can see if the nsc data contains any unow students. 
unow students will be matches. Any students who are not matched are unow students 
that were not in the nsc data and should be dropped from the new data aswell. 
20 students will be merged in but only 10 are unique. so the n will 
become 1004. If you look at the merge variable you can see that 10 unow 
students were matched*/
merge m:1 srjcid using "$output\srjcid_unowstudents_unique.dta"

/* should drop <DATA DELTED> cases. We are dropping the <DATA DELETED> unow students. Remember, 
there were 10 that were matched to the original data, meaning there were 
some Unow students hiding in our original data, and then <DATA DELETED> that were new. 
so when drop the <DATA DELETED> we should have an n of <DATA DELTED>. That is, we will drop 
the 10 unow students that didn't exist in the file and then the 10 that 
were in the original file.  */
drop if unow_students == "UNOW STUDENT" 

drop unow_students _merge

save "$output\nsc_data_no_unow.dta", replace

********************************************************************************								   
*****************              ANALYSIS                 ************************
********************************************************************************								   

/* There is a lot of variation in the beginning and ending enrollment dates. 
You should bin these, so they are easier to work with.
10/24/14 - note, we really didn't do anything with this variable, it was 
created when I was exploring the data */
gen semester = ""
replace semester = "Fall" if enrol_beg_end == "b08e08" | ///
enrol_beg_end == "b08e09" | enrol_beg_end == "b08e10" | ///
enrol_beg_end == "b09e09" | enrol_beg_end == "b06e11" | ///
enrol_beg_end == "b08e11" | enrol_beg_end == "b09e10" | ///
enrol_beg_end== "b09e11" | enrol_beg_end == "b07e12" | ///
enrol_beg_end == "b08e12" | enrol_beg_end == "b08e01" | ///
enrol_beg_end == "b09e12"

replace semester = "Spring" if enrol_beg_end == "b11e02" | ///
enrol_beg_end == "b11e12"

/* create a drop/complete indicator. 
10/24/14 - we ended up only using this variable to id non-traditional schools 
that were in the data. We used enrollment dates as well as school names 
to id these schools. 
*/

gen status = ""
replace status = "Drop" if enrol_beg_end == "b08e08" | ///
enrol_beg_end == "b08e09" | enrol_beg_end == "b08e10" | ///
enrol_beg_end == "b09e09" | ///
enrol_beg_end == "b08e11" | enrol_beg_end == "b09e10" | ///
enrol_beg_end == "b09e11" | enrol_beg_end == "b11e02" 

replace status = "Enrolled" if ///
enrol_beg_end == "b08e12" | enrol_beg_end == "b09e12"

replace status = "Non-Traditional" if ///
enrol_beg_end == "b06e11" | enrol_beg_end == "b07e12" ///
| enrol_beg_end == "b08e01" | enrol_beg_end == "b11e12" ///
| enrol_beg_end == "b11e02" | collegename == "ACADEMY OF ART UNIVERSITY" 

* create a public 4/2 year private 4/2 year university indicator
gen  collegetype = 1 if status == "Non-Traditional" /// 
& collegename != "CONCORDIA UNIVERSITY - IRVINE"
replace collegetype = 2  if publicprivate == "Public" & ///
year4year == 4
replace collegetype = 3 if publicprivate == "Private" ///
& year4year == 4 & collegetype == . 
/*you have to add the condition of collegetype == . or else we will overwrite 
the collegetype values of 1*/
replace collegetype = 4 if publicprivate == "Public" & ///
year4year == 2

label define lab_collegetype 1 "PrivForProfit" 2 "Pub4yr" 3 "Priv4yr" ///
4 "Pub2yr"

label values collegetype lab_collegetype

/* the values of collegetype reflect the order of importance for dual 
enrollment selection */

tostring degreetitle degreemajor1, replace

*************************************************************************

sort srjcid collegetype collegename 

// any value of 2 or more represents a duplicate
by srjcid : gen dup = _N

// flag dual enrolled in two different college types 
by srjcid : gen dual_enrl = 1 if collegetype != collegetype[_n + 1] & ///
lastname == lastname[_n+1] & dup > 1

/* flag dual enrolled in same college type. Only for those with two cases. 
This code relies on Santa Rosa Junior College or Sonoma State being sorted
on the buttom of each unique srjcid block. Test to make sure that these schools
are always on the bottom. There are two schools that could be sorted 
below SRJC and there are 15 schools that could be sorted below sonoma state
check to make sure none of these schools are sorted below srjc or sonoma state*/ 

local schools "WEST HILLS COMMUNITY COLLEGE" "SHASTA COLLEGE" ///
"UNIVERSITY OF CALIFORNIA - BERKELEY" "UNIVERSITY OF CALIFORNIA - RIVERSIDE" ///
"UNIVERSITY OF CALIFORNIA-DAVIS" "UNIVERSITY OF CALIFORNIA-LOS ANGELES" ///
"UNIVERSITY OF CALIFORNIA-SAN DIEGO" "UNIVERSITY OF CALIFORNIA-SANTA BARBARA" ///
"UNIVERSITY OF CALIFORNIA-SANTA CRUZ" "UNIVERSITY OF MAINE, FT KENT" ///
"UNIVERSITY OF MICHIGAN" "UNIVERSITY OF MONTANA" "UNIVERSITY OF NEVADA-RENO" ///
"UNIVERSITY OF NORTH CAROLINA-CHAPEL HILL" "UNIVERSITY OF OREGON" ///
"UNIVERSITY OF PITTSBURGH" "UNIVERSITY OF UTAH"

// This shoule return "no observations"
foreach school in `schools' {
	by srjcid: tab collegename if collegetype == collegetype[_n -1] & ///
	dup > 1 & collegename == `"`school'"'
	}

by srjcid : replace dual_enrl = 2 if collegetype == collegetype[_n - 1] & ///
collegetype != .   & dup == 2 


// create a unique flag
gen unique = . 
by srjcid : replace unique = 1 if dup == 1 | dup == 2 & dual_enrl == 1 | ///
dup == 2 & dual_enrl == 2 | dup == 3 & dual_enrl == 1 | dup == 3 & ///
collegename == collegename[_n+2] 

/* since we are only counting dual enrolled students one time and we now
have collegetype as a numeric variable we do not need to replace 
any values. This should save you a lot of headaches. Sorting is important here.
Because collegetype is numeric if we sort by srjcid then college type all the 
private For profits will float to the top followed by the public 4 years. 
In the cases where a student is enrolled in 2 schools a 2 yr and 4yr the 
correct  year will automatically be selected. The people who are dual enrolled 
in the same college type is a little more tricky. In these cases we also 
sort by collegename. In this specific data all the cases where a student 
is dual enrolled in the same college type Santa Rosa Junior College or 
Sonoma State floats to the buttom of the stack. If we assign values from 
the bottom of the data to the top [_n -1] the correct school will always 
be selected. THIS IS ONLY VALID FOR THIS PARTICULAR DATA!*/


// 8/8/14 This is correct now

save "$output\nsc_data_no_unow.dta", replace

********************************************************************************
************** merge in degree major from an earlier NSC datapull **************
********************************************************************************

************************ Pull in data and clean it *****************************

insheet using "$source\UNOW_NSC_20120801searchdate.csv", clear

drop if graduated == "N" /*should drop 3181 and keep 1363. */

quietly describe 

* check to make sure we got the right number of drops
if r(N) == 1363 { 
	di as green "We are good to go!"
}
else {
	di as red "observations are not what we expected"
}

* use string functions to remove trailing "_" from requesterreturnfield (srjcid)
gen srjcid = substr(requesterreturnfield, 1, length(requesterreturnfield)-1)

destring srjcid, replace

format %15.0g srjcid 

keep  srjcid firstname middleinitial lastname graduated degreetitle ///
degreemajor1 graduationdate

/* you will need to drop out any students that are not part listed in our 
original nsc data. Do this by merging in a list of the unique srjcids found 
in that file. The file below lists only unique srjcids that appear in the 
original data set. 

*/

merge m:1 srjcid using "$output\srjcid_nsc_unique.dta"

// Now we want to drop any student who were not matched; drop merge values of 1

// should have 19 drops 
drop if _merge == 1 & original == "" 

drop original _merge

// dup should equal 949 if you filter by dup ==1 

bysort srjcid : gen dup = _n
tab dup if dup == 1

drop dup

sort srjcid

// will be used to check total observation number later
quietly desc
global degree_pull_N = r(N) 

// Now we have data with only the students that were in the 2013 nsc data 

gen degree2012 = 1 

save "$output\nsc_pullWithDegreeMajor.dta", replace

****************** append this data to our original nsc data *******************

use "$output\nsc_data_no_unow.dta", clear

quietly describe 

local nsc_N = r(N)

* check to make sure we got the right number of drops

append using "$output\nsc_pullWithDegreeMajor.dta"

quietly describe 

if `nsc_N' + $degree_pull_N == r(N){ 
	di as green "We are good to go! Obs are as expected"
}
else {
	di as red "observations are not what we expected"
}

// resort the data
sort srjcid collegetype collegename

// some people were missing information here this code fills that in. 
by srjcid : replace firstname = firstname[_n + 1] if firstname == "" 
by srjcid : replace firstname = firstname[_n - 1] if firstname == ""

by srjcid : replace lastname = lastname[_n + 1] if lastname == "" 
by srjcid : replace lastname = lastname[_n - 1] if lastname == ""

// should return no observations
foreach var in firstname lastname { 
	tab `var' if `var' == ""
	}
	
//browse firstname lastname srjcid collegetype collegename degreemajor1 ///
//degreetitle unique

************************ Create Degrees Held Variables *************************

// run a regular expression to create a certificate and transfer indicator

// Where 0 references the regular expression match
gen cert = regexs(0) if  regexm(degreetitle, "CERTIFICATE")
gen trans = regexs(0) if regexm(degreetitle, "TRANSFER")
gen aa = regexs(0) if regexm(degreetitle, "ASSOCIATE IN ARTS")
gen aSci = regexs(0) if regexm(degreetitle, "ASSOCIATE IN SCIENCE")

// some fixes
replace aa = "" if trans == "TRANSFER"
replace aSci = "" if trans == "TRANSFER"

// create one var to hold all of these indicators 
gen degreeCategory = "" 
replace degreeCategory = "cert" if cert == "CERTIFICATE"
replace degreeCategory = "aa/as" if aa == "ASSOCIATE IN ARTS" | ///
aSci == "ASSOCIATE IN SCIENCE"
replace degreeCategory = "trans" if trans == "TRANSFER"

drop cert trans aa aSci

/* this code is getting close to what Clarisse wants. It just misses the people
 who got the same degree twice You also have the students who do not have any 
 duplicate records who were also skipped. there are also the cases where 
 people have 3 different degrees. It catches this but it does not place it 
 in the same value
 
 The line has to make sure the degree categories are different, also, it 
 needs to check and make sure degreecategoy doesn't have a blank value. 
 */
 
 // you have to sort by srjcid then degree category for this to work
sort srjcid degreeCategory 
by srjcid  : gen degreesHeld = degreeCategory + "_" + degreeCategory[_n+1] ///
if lastname == lastname[_n+1] & degreeCategory != degreeCategory[_n+1] & ///
degreeCategory != "" 


/* We have situations where a person has 3 different degrees. This is not 
handled by the code above. Write code to place the third degree into the value. 
first find all cases where this occurs  */

/* this is a two step process; first generate counts. They will all be 1 since
all the values will be unique within an individual. You will have to add all 
the values from drgHeldCheck in a second step to see if a person has more than 
one value */

bysort srjcid degreesHeld : gen dgrHeldCheck = _n if degreesHeld != ""
egen dgrHeldCount = count(dgrHeldCheck) , by(srjcid)  

/* 11 values of 2 returned showing we have more than two degrees for some people. 
Those people are Daniel Anderson and Susana Fuentes */ 

// replace these cases with a value of aa/as_cert_trans

// should see 4 changes; this clears out what they already had 
replace degreesHeld = ""  if dgrHeldCount == 2 & degreesHeld == "aa/as_cert" & ///
srjcid == 878357521 | dgrHeldCount == 2 & degreesHeld == "cert_trans" & ///
srjcid == 878357521 | dgrHeldCount == 2 & degreesHeld == "aa/as_cert" & ///
srjcid == 880501202 | dgrHeldCount == 2 & degreesHeld == "cert_trans" & ///
srjcid == 880501202 

// should have two changes 
replace degreesHeld = "aa/as_cert_trans" if srjcid == 878357521 & ///
collegetype == 2 | srjcid == 880501202 & collegetype == 2

drop dgrHeldCount
drop dgrHeldCheck

bysort srjcid degreesHeld : gen dgrHeldCheck = _n if degreesHeld != ""
egen dgrHeldCount = count(dgrHeldCheck), by(srjcid)
 
tab dgrHeldCount

// get rid of the variables used for checking
drop dgrHeldCount
drop dgrHeldCheck

/* Fill in missing values. This way you can use the origin_date_flag to filter
for the people in the original dataset */ 

// 7 time
local index = 0 
while `index' <= 7 {
	by srjcid: replace degreesHeld = degreesHeld[_n+1] if degreesHeld == "" 
	local index = `index' + 1
	}


// last step is to create the degreesHeld value for those with a single degree

sort srjcid degreeCategory 
by srjcid  : replace degreesHeld = degreeCategory  ///
if degreeCategory != "" & degreesHeld == "" 

// Fill in missing values 
local index = 0 
while `index' <= 6 {
	by srjcid : replace degreesHeld = degreesHeld[_n+1] if degreesHeld == ""
	local index = `index' + 1
	}


// If everything is correct this should return "no observations"
tab srjcid  if degreesHeld == "" & degreeCategory != ""


**************** Create a variable that has a multi degree aggregation *********

gen degreesHeldAgg = ""


replace degreesHeldAgg = "aa or as & cert" if degreesHeld == "aa/as_cert" | ///
degreesHeld == "cert"
replace degreesHeldAgg = "aa or as" if degreesHeld == "aa/as"
replace degreesHeldAgg = "trans" if degreesHeld == "aa/as_cert_trans" | ///
degreesHeld == "aa/as_trans" | degreesHeld == "cert_trans" | ///
degreesHeld == "trans"

/* drop the students with missing degree information (drops 63, 51 of which fit
our conditions (unow !=1 & origin_data_flag == 1)*/

drop if degreesHeld == ""


save "$output\nsc_WithOldDegreeMajor.dta", replace

