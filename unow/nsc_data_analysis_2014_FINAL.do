/* 
Author: John Mezzanotte
Project: UNOW 
Date Last Modified: 7-29-14
Purpose: analyze overall enrollment. Are students who were enrolled in a 
		 postsecondary institution as of fall 2013 still enrolled in the spring 
		 of 2014. If they are enrolled are they enrolled in the same 
		 institution? What percentage of time are they enrolled (FT/PT)
source data: Y:\UNow\johns_files\sourcedata\UNOW NSC 7_2014.csv
			 data used to create unow indicator
			 Y:\UNow\johns_files\output\unow_students.dta"
           
*/

clear
set more off

********** Set-up source data paths

global source ///
"Y:\UNOW\johns_files\sourcedata"
global output "Y:\UNOW\johns_files\output"

capture log using "$output\newNSCData72014.smcl", replace

insheet using "$source\UNOW NSC 7_2014.csv"

*******************************************************************************
************************* general data cleaning *******************************
*******************************************************************************

// get rid of trailing '_' in requesterreturn field; create srjcid
gen srjcid = substr(requesterreturnfield, 1, length(requesterreturnfield)-1)

drop requesterreturnfield

destring srjcid, replace

format %11.0g srjcid

order srjcid

// youruniqueidentifier has no data in it
drop youruniqueidentifier

replace enrollmentstatus  = "Full-time" if enrollmentstatus == "F"
replace enrollmentstatus  = "Half-time" if enrollmentstatus == "H"
replace enrollmentstatus  = "Less than half-time" if enrollmentstatus == "L"
replace enrollmentstatus  = "Withdrawn" if enrollmentstatus == "W"
replace enrollmentstatus  = "Leave of absence" if enrollmentstatus == "A"
replace enrollmentstatus  = "Deceased" if enrollmentstatus == "D"

// Create a binned enrollment status 
gen enrollmentstatus_binned = 1 if enrollmentstatus == "Full-time" 
replace enrollmentstatus_binned = 2 if enrollmentstatus == "Half-time" | ///
enrollmentstatus == "Less than half-time" 
replace enrollmentstatus_binned = . if enrollmentstatus == "Withdrawn" | /// 
enrollmentstatus == "Leave of absence"

label define enrl_binned_lab 1 "Full-time" 2 "Part-time" 

label values enrollmentstatus_binned enrl_binned_lab

********************************************************************************								   
********************    Filter out  UNOW students    ***************************
********************    Append to old nsc data       ***************************
********************************************************************************								   

/* Use srjcid_unowstudents_unique.dta, there are 20 unow students in this data
This data contains no duplicates just the unique srjcid*/

merge m:1 srjcid  using "Y:\UNow\johns_files\output\srjcid_unowstudents_unique"

/* now that we have id'd all the unow students we want to drop them. This should
be a dataset of only comparison students */

// We should drop 26 cases
drop if unow_students == "UNOW STUDENT"

//The merge variable should only have values of 1
tab _merge

// drop some variables we don't need anymore 
drop unow_students _merge

* create a public 4/2 year private 4/2 year university indicator
	
sort srjcid 

tostring searchdate, replace
tostring enrollmentbegin, replace
tostring enrollmentend, replace

/* merge in the srjcid id's that identify the students that are enrolled in the 
fall of 2013 only. We are going to drop any students that were not enrolled 
in the fall of 2013*/
merge m:1 srjcid using ///
"Y:\UNow\johns_files\output\srjcid_enrolledstudents_unique"

// should drop 362 cases
/* Not dropping these students allowed me to create the "No" category 
of exhibit 5 in nsc_exhibits_v2_20140808_ch */
//drop if _merge == 1

gen collegetype = . 
foreach college in "ACADEMY OF ART UNIVERSITY" "KAPLAN UNIVERSITY" ///
                   "UNIVERSITY OF PHOENIX" {
	replace collegetype = 1 if publicprivate == "Private" ///
	& collegename == `"`college'"' 
	}
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

save "$output\new_nsc_data_7_2014.dta", replace

// pull in using data and make sure it is sorted on srjcid
use "$output\nsc_WithOldDegreeMajor.dta" , clear

append using "$output\new_nsc_data_7_2014.dta"

// There are no missing values for college type in the new data
gen spring2014_enrl = enrollmentbegin ///
if regexm(enrollmentbegin, "20140[1-4][0-9][0-9]") 

gen spring2014_year =  "2014" ///
if regexm(enrollmentbegin, "20140[1-4][0-9][0-9]") 

gen fall2013_enrl = enrollmentbegin ///
if regexm(enrollmentbegin, "2013[0-9][0-9][0-9][0-9]")

gsort srjcid -spring2014_year collegetype collegename 

// flag dual enrolled in two different college types 
by srjcid : gen spr2014_dual_enrl = 1 if spring2014_enrl != "" & ///
collegetype != collegetype[_n + 1] & spring2014_enrl[_n + 1]!= "" & ///
lastname == lastname[_n+1] 

drop dup 

by srjcid : gen dup = _n 


// two different colleges of the same type 
by srjcid : replace spr2014_dual_enrl = 2 if ///
collegetype == collegetype[_n - 1] & ///
collegename != collegename[_n - 1] & ///
spring2014_enrl != "" & ///
spring2014_enrl[_n - 1] != "" & dual_enrl[_n - 1] == . & dup < 3 


gen newnsc_unique =. 
by srjcid : replace newnsc_unique = 1 if dup == 1 & spr2014_dual_enrl == . & ///
spr2014_dual_enrl[_n+1] == . & spring2014_enrl !=""  | ///
unique == . & spr2014_dual_enrl == 1 | unique == . & spr2014_dual_enrl == 2

// drop all the cases we are don't need 
keep  if unique == 1 & newnsc_unique == . | ///
unique == . & newnsc_unique ==1

sort srjcid unique

gen fall2013_year = "fall" if spring2014_year == ""

label define lab_college_change 1 "Same" 2 "Same Type Diff College" ///
3 "Pub4yr-->Pub2yr" 4 "Pub4yr-->Priv4yr" 5 "Pub4yr-->PrivForProfit" ///
6 "Pub2yr-->Pub4yr" 7 "Pub2yr-->Priv4yr" 8 "Pub2yr-->PrivForProfit" ///
9 "Priv4yr-->Pub4yr" 10 "Priv4yr-->Pub2yr" 11 "Priv4yr-->PrivForProfit" ///
12 "PrivForProfit-->Pub4yr" 13 "PrivForProfit-->Pub2yr" ///
14 "PrivForProfit-->Priv4yr" 15 "PrivFroProfit-->Drop" ///
16 "Pub4yr-->Drop" 17 "Priv4yr-->Drop" 18 "Pub2yr-->Drop"


// Same school fall 2013 - spring 2014 
by srjcid : gen college_change = 1 if ///
collegetype == collegetype[_n + 1] & collegename == collegename[_n + 1] & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Same college type different school from fall 2013 to spring 2014
by srjcid : replace college_change = 2 if ///
collegetype == collegetype[_n + 1] & collegename != collegename[_n + 1] & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 4 year to Public 2 Year -- interesting
by srjcid : replace college_change = 3 if ///
collegetype == 2 & collegetype[_n + 1] == 4 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 4year to private 4 year - nobody is in this category
by srjcid : replace college_change = 4 if ///
collegetype == 2 & collegetype[_n + 1] == 3 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 4 year to Private For Profit - 0 Cases in this category 
by srjcid : replace college_change = 5 if ///
collegetype == 2 & collegetype[_n + 1] == 1 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 2 year to Public 4 year
by srjcid : replace college_change = 6 if ///
collegetype == 4 & collegetype[_n + 1] == 2 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 2 yeaer to Private 4 year 
by srjcid : replace college_change = 7 if ///
collegetype == 4 & collegetype[_n + 1] == 3 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 2 year to Private For Profit
by srjcid : replace college_change = 8 if ///
collegetype == 4 & collegetype[_n + 1] == 1 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private 4 year to Public 4 year - No cases are in this category 
by srjcid : replace college_change = 9 if ///
collegetype == 3 & collegetype[_n + 1] == 2 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private 4 year to Public 2 year - No cases in this category 
by srjcid : replace college_change = 10 if ///
collegetype == 3 & collegetype[_n + 1] == 4 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private 4 year to Private 4 profit - No Cases in this category 
by srjcid : replace college_change = 11 if ///
collegetype == 3 & collegetype[_n + 1] == 1 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private for profit to Public 4 year - No Cases
by srjcid : replace college_change = 12 if ///
collegetype == 1 & collegetype[_n + 1] == 2 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private for profit to Public 2 year
by srjcid : replace college_change = 13 if ///
collegetype == 1 & collegetype[_n + 1] ==  4 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// private for profit to Private 4 year - No cases in this category 
by srjcid : replace college_change = 14 if ///
collegetype == 1  & collegetype[_n + 1] == 3 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Students enrolled in Priv for Profit 2013 then dropped in the spring of 2014
by srjcid : replace college_change = 15 if ///
college_change == . & spring2014_year == "" & fall2013_year == "fall" & ///
collegetype == 1 

// Students enrolled in Public 4 year 2013 then dropped in the spring of 2014
by srjcid : replace college_change = 16 if ///
college_change == . & spring2014_year == "" & fall2013_year == "fall" & ///
collegetype == 2 

// Students enrolled in Private 4 year 2013 then dropped in the spring of 2014
by srjcid : replace college_change = 17 if ///
college_change == . & spring2014_year == "" & fall2013_year == "fall" & ///
collegetype == 3 

// Students enrolled in Public 2 year 2013 then dropped in the spring of 2014
by srjcid : replace college_change = 18 if ///
college_change == . & spring2014_year == "" & fall2013_year == "fall" & ///
collegetype == 4

label values college_change lab_college_change

// fill in blanks 
by srjcid : replace college_change = college_change[_n - 1] if ///
college_change== . & spring2014_year == "2014"

// Enrollment status between years 
// drop enrlstatus_change
// You need this variable to ID the Fall only students 
by srjcid: gen fall_only = _N

// Full-time to Full-time 
by srjcid : gen enrlstatus_change = 1 if ///
enrollmentstatus_binned == 1 & enrollmentstatus_binned[_n + 1] == 1 & ///
collegetype !=. & collegetype[_n +1]  != . 
// Full-time to part-time
by srjcid : replace enrlstatus_change = 2 if ///
enrollmentstatus_binned == 1 & enrollmentstatus_binned[_n + 1] == 2 & ///
collegetype !=. & collegetype[_n + 1] != . 
// Part-time to full-time 
by srjcid : replace enrlstatus_change = 3 if ///
enrollmentstatus_binned == 2 & enrollmentstatus_binned[_n + 1] == 1 & ///
collegetype !=. & collegetype[_n + 1] != . 
// Part-time to part-time
by srjcid : replace enrlstatus_change = 4 if /// 
enrollmentstatus_binned == 2 & enrollmentstatus_binned[_n + 1] == 2 & ///
collegetype !=. & collegetype[_n + 1] !=.
// Full-time to not enrolled Spring 2014
by srjcid : replace enrlstatus_change = 5 if /// 
unique == 1 & fall_only == 1 & collegetype !=. & enrollmentstatus_binned == 1
// Part-time to not enrolled Spring 2014
by srjcid : replace enrlstatus_change = 6 if ///
unique == 1 & fall_only == 1 & collegetype !=. & enrollmentstatus_binned == 2
// Enrolled but enrollmentstatus missing
by srjcid : replace enrlstatus_change = 7 if ///
unique == 1 & fall_only == 1 & collegetype !=. & enrollmentstatus_binned == .
// Not enrolled to enrolled Full Time
by srjcid : replace enrlstatus_change = 8 if /// 
unique == 1 & collegetype == . & collegetype[_n + 1] !=. & ///
srjcid == srjcid[_n + 1] & enrollmentstatus_binned[_n + 1] == 1
// Not enrolled to enrolled Part Time
by srjcid : replace enrlstatus_change = 8 if /// 
unique == 1 & collegetype == . & collegetype[_n + 1] !=. & ///
srjcid == srjcid[_n + 1] & enrollmentstatus_binned[_n + 1] == 2
// Not enrolled to enrolled but missing status record
by srjcid : replace enrlstatus_change = 8 if /// 
unique == 1 & collegetype == . & collegetype[_n + 1] !=. & ///
srjcid == srjcid[_n + 1] & enrollmentstatus_binned[_n + 1] == .

label define lab_enrlstatus_change 1 "FT-FT" 2 "FT-PT" 3 "PT-FT" 4 "PT-PT" ///
5 "FT-NotEnrled" 6 "PT-NotEnrled" 7 "EnrledNoStatus" 8 "NotEnrled-FT" ///
9 "NotEnrled - PT" 10 "NotEnrled-EnrledNoStatus"

label values enrlstatus_change lab_enrlstatus_change


//Create a binned college_change variable
label define lab_college_change_binned 1 "4yr-4yr" 2 "4yr-2yr" 3 "2yr-4yr" ///
4 "2yr-2yr" 5 "4yr-drop" 6 "2yr-drop"


// Private for Profit to Private for Profit should give 1 value
by srjcid : gen college_change_binned = 1 if ///
collegetype == 1 & collegetype[_n + 1] == 1  & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 4yr to Public 4yr
by srjcid : replace college_change_binned = 1 if ///
collegetype == 2 & collegetype[_n + 1]== 2 &  ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private 4yr to Private 4yr
by srjcid : replace college_change_binned = 1 if ///
collegetype == 3 & collegetype[_n + 1]== 3 &  ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private for profit to Public 4 year - No Cases  
by srjcid : replace college_change_binned = 1 if ///
collegetype == 1 & collegetype[_n + 1] == 2 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// private for profit to Private 4 year - No cases in this category 
by srjcid : replace college_change_binned = 1 if ///
collegetype == 1  & collegetype[_n + 1] == 3 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 4 year to Private For Profit - 0 Cases in this category 
by srjcid : replace college_change_binned = 1 if ///
collegetype == 2 & collegetype[_n + 1] == 1 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 4year to private 4 year - nobody is in this category 
by srjcid : replace college_change_binned = 1 if ///
collegetype == 2 & collegetype[_n + 1] == 3 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private 4 year to Private 4 profit - No Cases in this category  
by srjcid : replace college_change_binned = 1 if ///
collegetype == 3 & collegetype[_n + 1] == 1 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private 4 year to Public 4 year - No cases are in this category  
by srjcid : replace college_change_binned = 1 if ///
collegetype == 3 & collegetype[_n + 1] == 2 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private 4 year to Public 2 year - No cases in this category 
by srjcid : replace college_change_binned = 2 if ///
collegetype == 3 & collegetype[_n + 1] == 4 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"


// Public 4 year to Public 2 Year -- interesting
by srjcid : replace college_change_binned = 2 if ///
collegetype == 2 & collegetype[_n + 1] == 4 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Private for profit to Public 2 year
by srjcid : replace college_change_binned = 2 if ///
collegetype == 1 & collegetype[_n + 1] ==  4 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"


// Public 2 year to Public 4 year  
by srjcid : replace college_change_binned = 3 if ///
collegetype == 4 & collegetype[_n + 1] == 2 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 2 year to Private For Profit 
by srjcid : replace college_change_binned = 3 if ///
collegetype == 4 & collegetype[_n + 1] == 1 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 2 yeaer to Private 4 year 
by srjcid : replace college_change_binned = 3 if ///
collegetype == 4 & collegetype[_n + 1] == 3 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"

// Public 2 yeaer to Public 2 year 
by srjcid : replace college_change_binned = 4 if ///
collegetype == 4 & collegetype[_n + 1] == 4 & ///
fall2013_year == "fall" & spring2014_year[_n + 1] == "2014"


// Students enrolled in Priv for Profit 2013 then dropped in the spring of 2014
by srjcid : replace college_change_binned = 5 if ///
college_change_binned == . & spring2014_year == "" & fall2013_year == "fall" & ///
collegetype == 1 


// Students enrolled in Public 4 year 2013 then dropped in the spring of 2014
by srjcid : replace college_change_binned = 5 if ///
college_change_binned == . & spring2014_year == "" & fall2013_year == "fall" & ///
collegetype == 2 

// Students enrolled in Private 4 year 2013 then dropped in the spring of 2014
by srjcid : replace college_change_binned = 5 if ///
college_change_binned == . & spring2014_year == "" & fall2013_year == "fall" & ///
collegetype == 3 

// Students enrolled in Public 2 year 2013 then dropped in the spring of 2014
by srjcid : replace college_change_binned= 6 if ///
college_change_binned == . & spring2014_year == "" & fall2013_year == "fall" & ///
collegetype == 4

// fill in blanks 
by srjcid : replace college_change_binned = college_change_binned[_n - 1] if ///
college_change_binned == . & spring2014_year == "2014"

by srjcid : replace college_change_binned = college_change_binned[_n + 1] if ///
college_change_binned == . & spring2014_year == "2014"

label values college_change_binned lab_college_change_binned



save "$output\new_nsc_data_7_2014.dta", replace
