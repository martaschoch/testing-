*****************************
*** SET WORKING DIRECTORY ***
*****************************
// Marta
else if (lower("`c(username)'") == "wb562318") {
	cd "C:/Users/wb562318/OneDrive - WBG/Documents/Global Poverty/missing data/Missing Data"
}

// Daniel
if (lower("`c(username)'") == "wb514665") {
	cd "C:\Users\WB514665\OneDrive - WBG\pip\GitHub\Missing-Data"
}


******************************************************
*** GENERATE DATASET WITH 100 QUANTILES PER SURVEY ***
******************************************************
cap remove "data/cleaned/Quantiles_Raw_2017PPP.dta"
forvalues quantile = 0.005(0.01)0.99501 {
disp in red "`quantile'"
qui pip, country(all) year(all) popsh(`quantile') clear
keep country_code welfare_time welfare_type reporting_level poverty_line headcount
	// Only execute the following from the second quantile queried onwards
	if `quantile' > 0.01 {
	qui tempfile query
	qui save    `query'
	qui cap use "data/cleaned/Quantiles_Raw_2017PPP.dta", clear
	qui append using `query'
	}
qui save    "data/cleaned/Quantiles_Raw_2017PPP.dta", replace
}

// Only keep national surveys
// popsh() doesn't work for IDN/IND/CHN, those will be dealt with separately
keep if reporting_level=="national" | inlist(country_code,"ARG","SUR") |  country_code=="BOL" & welfare_time<=1992 |  country_code=="URY" & welfare_time<2006
drop if inlist(country_code,"CHN","IDN","IND")
drop reporting_level
// Removing some errors in the data
drop if headcount==-1 | headcount==1
drop if poverty_line<=0
duplicates drop
// Removing some strange error with MKD
bysort country_code welfare_time welfare_type poverty_line: gen N=_N
*br if N==2
bysort country_code welfare_time welfare_type poverty_line: drop if _n==2 & N==2
drop N
rename country_code code
rename welfare_time year
save "data/cleaned/Quantiles_Raw_2017PPP.dta", replace

use "data/cleaned/Quantiles_Raw_2017PPP.dta", clear

**********************************************************************
*** GENERATE DATASET WITH 100 QUANTILES PER SURVEY FOR CHN/IDN/IND ***
**********************************************************************
// Needed since popsh() doesn't work for CHN/IDN/IND (it works for urban/rural separately only, not national)

		**************************************
		*** FINDING POVERTY LINES TO QUERY ***
		**************************************
		// Query many poverty lines and then convert the queried poverty rates into quantiles
		// The more poverty lines queried, the more precise results.
		// We start with increments of 2 cents. We will later on linearly interpolate between these queried poverty lines.
		clear
		set obs 1000
		// First query poverty lines at 2 cent intervals
		gen double poverty_line = _n/50
		// From $2 and upwards increase the poverty line by 1%
		replace poverty_line = poverty_line[_n-1]*1.01 if poverty_line>2
		// From $50 and upwards increase the poverty line by 2%
		replace poverty_line = poverty_line[_n-1]*1.02 if poverty_line>50
		// We don't need poverty lines above $100 (99.5th percentile in surveys for those countries is way less than $100
		drop if poverty_line>100
		replace poverty_line = round(poverty_line,0.01)
		// The lines below group poverty lines to query into five. Some experimentation suggests that this goes a bit faster with pip.ado than querying one at a time
		tostring poverty_line, replace force
		gen poverty_line5 = poverty_line + " " + poverty_line[_n+1] + " " + poverty_line[_n+2] + " " + poverty_line[_n+3] + " " + poverty_line[_n+4]
		keep if mod(_n-1,5)==0
		drop poverty_line


		**************************
		*** QUERYING pip ***
		**************************
		preserve
		cap erase "data/cleaned/Surveydata_CHNIDNIND.dta"
		qui levelsof poverty_line5
		foreach lvl in `r(levels)' {
			disp as error "`lvl'"
			qui pip, country(CHN IDN IND) year(all) povline(`lvl') clear
			keep if reporting_level=="national"
			keep country_code welfare_time poverty_line headcount welfare_type
			tempfile querieddata
			save `querieddata'
			cap use "data/cleaned/Surveydata_CHNIDNIND_2017PPP.dta", clear
			cap append using `querieddata'
			save "data/cleaned/Surveydata_CHNIDNIND_2017PPP.dta", replace
		}
		restore
		
		***************************
		*** TURN INTO QUANTILES ***
		***************************
		
		// Create a dataset with the desired quantiles and (at this point) still unknown corresponding poverty lines
		use "data/cleaned/Surveydata_CHNIDNIND_2017PPP.dta", clear
		keep country_code welfare_time welfare_type
		duplicates drop
		expand 100
		bysort country_code welfare_time welfare_type: gen headcount = _n/100-0.005
		gen poverty_line = .
		gen quantile    = 1
		tempfile quantile_CHNIDNIND
		save    `quantile_CHNIDNIND'
		
		// Open the data with the queried poverty rates
		use "data/cleaned/Surveydata_CHNIDNIND_2017PPP.dta", clear
		merge m:1 country_code welfare_time welfare_type headcount using `quantile_CHNIDNIND', nogen
		sort country_code welfare_time welfare_type headcount
		// Interpolate to fill out poverty line at quantiles
		bysort country_code welfare_time welfare_type (headcount): ipolate poverty_line headcount, gen(poverty_line_temp) 
		// Only keep the poverty lines reflecting the desired quantiles.
		keep if quantile==1
		drop poverty_line quantile
		rename poverty_line_temp poverty_line
		rename welfare_time year
		rename country_code code
		save "data/cleaned/Quantiles_CHNIDNIND_2017PPP.dta", replace

*************************************************
*** MERGE WITH QUANTILES FROM OTHER COUNTRIES ***
*************************************************
use "data/cleaned/Quantiles_Raw_2017PPP.dta", replace
append using "data/cleaned/Quantiles_CHNIDNIND_2017PPP.dta"
sort code welfare_type year headcount
save "data/cleaned/Quantiles_2017PPP.dta", replace
