AutoSync
========

tags: group_a

Setup of contexts
* Enable messaging - setup
* Login to mingle as "admin" - setup
* Create projects "SAP, Java" with cards - setup
* Create program with objectives "Finance Program" "Payroll System, Billing System" - setup
* Associate projects "SAP,Java" with program "Finance Program" - setup

AutoSync
--------



* Create managed text property "Status" in project "SAP" with values "Open, In Progress, QA Complete"
* Bulk update "Status" of cards number "SAP_2" of project "SAP" from "(not set)" to "Open"
* Bulk update "Status" of cards number "SAP_1" of project "SAP" from "(not set)" to "In Progress"

Add work to objective from two projects without auto sync
* Open plan "Finance Program" in days view
* Click on addWork in the objective "Payroll System"
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Select project "SAP"
* Select cards "SAP_1"
* Add selected cards to objective

Add work to objective with autosync and verify changes in Add work page after autosync

* Add another filter
* Set filter number "1" with property "Status" operator "is" and value "Open" on add work page
* Enable auto sync
* Cancel autoSync
* Enable auto sync
* Assert that popup "autosync_confirmation_content" contains text "1 card currently matches your filter."
* ContinueAutoSync
* Assert add work page is in autosync mode matching "1" card
* Open plan "Finance Program" in days view
* Assert spinner on "Payroll System" objective
* Run auto sync for project "SAP"
* Wait for auto sync spinner in "Payroll System" to dissappear
* Assert spinner is not present on "Payroll System" objective


* Open card number "2" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"

View Work Added by Auto Sync
Verify card that matches auto sync filter is added to objective
Also verify card which does not match auto sync filter is removed from objective
* Bulk update "Status" of cards number "SAP_3" of project "SAP" from "(not set)" to "Open"

* Run auto sync for project "SAP"

* Open plan "Finance Program" in days view
* Click on viewWork in the objective "Payroll System"
* Assert that cards "SAP_2,SAP_3" are present in view work table
* Assert that cards "1" of project "SAP" not present in work table
* Assert text present "(auto sync on)"
* Assert that cards "SAP_2,SAP3" are disabled on view work table


Invalid Filters Message When card properties are modified.And user has to reset auto sync filter
* Update card property "Status" as "Status New" in project "SAP"

* Open plan "Finance Program" in days view
* Click on addWork in the objective "Payroll System"
* Select project "SAP"
* Assert text present "Property Status does not exist"
* Disable auto sync
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Assert that cards "SAP_2,SAP_3" are disabled
* Add another filter
* Set filter number "1" with property "Status New" operator "is" and value "In Progress" on add work page
* Enable auto sync
* ContinueAutoSync
* Run auto sync for project "SAP"


* Open card number "1" from project "SAP"
* Assert that on card that card belongs to objective "Payroll System" of plan "Finance Program"


___

Teardown of contexts
* Associate projects "SAP,Java" with program "Finance Program" - teardown
* Create program with objectives "Finance Program" "Payroll System, Billing System" - teardown
* Create projects "SAP, Java" with cards - teardown
* Login to mingle as "admin" - teardown
* Enable messaging - teardown


