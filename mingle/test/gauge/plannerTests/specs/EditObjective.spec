EditObjective
=============
tags: objectives

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP" with cards - setup

EditObjective
-------------

Assert objective popup information
* Create program "Finance Program" with plan from "1 Jan 2010" to "10 Feb 2010" and switch to days view
* Create objective "Billing System" on "Finance Program" starts on "2010-01-01" and ends on "2010-01-02" in days view
* Open plan "Finance Program" in days view
* Open objective "Billing System" popup
* Assert that objective name is on objective popup "Billing System"
* Assert that popup "objective_details_contents" contains text "You must add projects to this plan before you can add work."

Can edit a objective which has no work item.
* Open objective "Billing System" popup
* Edit objective with new name "1234" new start date "03 Jan 2010" new end date "04 Jan 2010"
* Save objective edit
* Assert text present "Feature 1234 was successfully updated."
* Open plan "Finance Program" in days view
* Assert that objective "Objective 1234" starts on "3 Jan 2010" and ends on "4 Jan 2010" in days view
* Switch to "weeks" view - Assertions
* Assert that objective "Objective 1234" cross weeks that begins from "28 Dec 2009" and week begins from "4 Jan 2010"

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
* Create projects "SAP" with cards - teardown
* Login to mingle as "admin" - teardown


