AddWorkPage
===========

tags: plan_projects_page, group_a

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP,Java,Dot Net" with "25" cards - setup
* Create program with objectives "Finance Program" "Payroll System, Billing System" - setup
* Create projects "Ruby" with "28" cards - setup

AddWorkPage
-----------

Message is given when no associated projects
* Navigate to objective "Payroll System" of plan "Finance Program"
* Assert text present "You must add projects to this plan before you can add work."
* Open "Projects" page
* Associate projects "SAP,Java,Dot Net,Ruby" with program

Message and Add work link are present when projects are associated but there exists no work items.
* Navigate to objective "Payroll System" of plan "Finance Program"
* Assert text present "Add work to this feature."
* Assert "Add work" link present

Add selected card to objective by mql filter and normal filter
Filter is cleared when selecting different project
* Open add works page
* Select project "Java"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Select all cards
* Add selected cards to objective
* Assert text present "25 cards added to the feature Payroll System"
* Assert that cards "Java_1,Java_2,Java_20,Java_25" are disabled
* Select project "Dot Net"

Message is given when filter does not match any cards
* Navigate to plan "Finance Program" objective "Payroll System" assign work page
* Select project "SAP"
* Set filter number "0" with property "Type" operator "is not" and value "Card" on add work page
* Assert text present "There are no cards found for given filter"

Able to use multiple filters
* Create managed text property "Story Status" in project "SAP" with values "New, Fixed, Tested"
* Create managed text property "Type of test" in project "SAP" with values "Automated, Manual, None"
* Set "Story Status" in card number "1" of project "SAP" to "Fixed"
* Set "Story Status" in card number "2" of project "SAP" to "Tested"
* Set "Type of test" in card number "2" of project "SAP" to "Automated"
* Set "Type of test" in card number "3" of project "SAP" to "Automated"

* Select project "SAP"
* Set filter number "0" with property "Type" operator "is" and value "Card" on add work page
* Add another filter
* Set filter number "1" with property "Story Status" operator "is not" and value "(not set)" on add work page
* Assert that cards "SAP_1, SAP_2" are present
* Add another filter
* Set filter number "2" with property "Type of test" operator "is" and value "Automated" on add work page
* Assert that cards "SAP_2" are present
* Remove "Story Status" filter
* Select cards "SAP_3, SAP_2"
* Add selected cards to objective
* Assert that cards "SAP_3, SAP_2" are present
* Assert that cards "SAP_3, SAP_2" are disabled

un-selected card won't be added to objective
* Remove "Type of test" filter
* Select all cards
* Deselect cards "SAP_24,SAP_25"
* Add selected cards to objective
* Assert text present "21 cards added to the feature Payroll System"
* Assert that the cards "SAP_25, SAP_24" are enabled

select none will deselect all cards on current page
* Select all cards
* Clear cards selection
* Assert cards "SAP_25,SAP_24" are not selected

Assert card results when clicking next page
User stays on current page after cards have been added
* Select project "Ruby"
* Assert that pagination exists
* Click next link to open next page
* Assert that the text present in page navigator is "Add Work"
* Assert that cards "Ruby_1, Ruby_2,Ruby_3" are present
* Select cards "Ruby_1, Ruby_2,Ruby_3"
* Add selected cards to objective
* Assert that cards "Ruby_1, Ruby_2,Ruby_3" are disabled


___

Teardown of contexts
* Create projects "Ruby" with "28" cards - teardown
* Create program with objectives "Finance Program" "Payroll System, Billing System" - teardown
* Create projects "SAP,Java,Dot Net" with "25" cards - teardown
* Login to mingle as "admin" - teardown


