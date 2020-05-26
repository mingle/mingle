PlanSettings
============

tags: plan_settings_page, group_a

Setup of contexts
* Login to mingle as "admin" - setup
* Create program with objectives "Finance Program" "Payroll System" - setup
* Create program with objectives "Money" "Billing System" - setup
* FakeNow "2011" "02" "20" - setup

PlanSettings
------------

* Create new program
* The rounded default plan start date and and end dates are "17 Jan 2011" "22 Jan 2012"


* Open plan "Finance Program" via url
* Open plan settings popup
* Click cancel link
* Assert granularity "months" highlighted



___

Teardown of contexts
* FakeNow "2011" "02" "20" - teardown
* Create program with objectives "Money" "Billing System" - teardown
* Create program with objectives "Finance Program" "Payroll System" - teardown
* Login to mingle as "admin" - teardown


