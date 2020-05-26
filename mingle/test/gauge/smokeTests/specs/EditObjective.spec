EditObjective
=============

tags: #11358, timeline_page, plan_projects_page, timeline_page, group_a

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP" with cards - setup
* Create program with objectives "Finance Program" "Billing System" - setup

EditObjective
-------------

Assert objective popup information
* Open plan "Finance Program" in days view
* Open objective "Billing System" popup
* Assert that objective name is on objective popup "Billing System"
* Assert that popup "objective_details_contents" contains text "You must add projects to this plan before you can add work."

Can edit a objective which has no work item.
* Open objective "Billing System" popup
* Edit objective with new name "1234" new start date "10 Jan 2011" new end date "4 Feb 2011"
* Save objective edit
* Assert text present "Feature 1234 was successfully updated."
* Open plan "Finance Program" in days view
* Assert that objective "1234" starts on "10 Jan 2011" and ends on "4 Feb 2011" in days view
* Switch to "weeks" view - Assertions
* Assert that objective "1234" cross weeks that begins from "10 Jan 2011" and week begins from "17 Jan 2011"

Go to plan projects page via objective popup and add projects to plan
* Open objective "1234" popup
* Assert that popup "objective_details_contents" contains text "You must add projects to this plan before you can add work."
* Click "add projects" link
* Associate projects "SAP" with program

Go to objective add work page via objective popup and add work to objective
* Open "Plan" page
* Open objective "1234" popup
* Click "Add work" link
* Add cards with numbers "1,2" from project "SAP"

* Create managed text property "Story Status" in project "SAP" with values "New, Done"

* Navigate to program "Finance Program" projects page
* Open define done status page of project "SAP"
* Map property "Story Status" value "Done" to plan done status

Can edit a objective which has work items.
* Navigate to objective "1234" of plan "Finance Program"
* Edit objective with new name "Billing && System" new start date "10 Jan 2011" new end date "4 Feb 2011"
* Save objective edit
* Assert text present "Feature Billing && System was successfully updated."


___

Teardown of contexts
* Create program with objectives "Finance Program" "Billing System" - teardown
* Create projects "SAP" with cards - teardown
* Login to mingle as "admin" - teardown


