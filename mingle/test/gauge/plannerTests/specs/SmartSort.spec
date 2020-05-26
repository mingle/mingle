SmartSort
=========

tags: program_page

Setup of contexts
* Create program with objectives "plan 123" "Foo" - setup
* Create program with objectives "plan 9cod" "Payroll System" - setup
* Create program with objectives "plan Base" "Billing System" - setup
* Create program with objectives "plan bass" "halibut" - setup
* Create projects "Proj 123, java, DotNet, SAP" with cards - setup
* Login to mingle as "admin" - setup

SmartSort
---------

This scenario tests the smart sorting for Planner. It adopts similar smart sorting from Mingle. The expected order of sorting special character, number and alphabetical order.

Smart sorting of plan names on plan list page.
* Navigate to programs list page
* Open plan "plan 123" in days view
* Open "Projects" page
* Assert that the order of projects in dropdown on program projects page is "DotNet, java, Proj 123, SAP"

Smart sorting on plan projects page.
* Associate projects "DotNet, java, Proj 123, SAP" with program "plan 123"
* Assert that the order of program projects is "DotNet, java, Proj 123, SAP"

Smart sorting on projects dropdown on objective detail page.
* Navigate to plan "plan 123" objective "Foo" assign work page
* Select project "SAP"
* Assert that the order of projects in dropdown on objective detail page is "DotNet, java, Proj 123, SAP"



___

Teardown of contexts
* Login to mingle as "admin" - teardown
* Create projects "Proj 123, java, DotNet, SAP" with cards - teardown
* Create program with objectives "plan bass" "halibut" - teardown
* Create program with objectives "plan Base" "Billing System" - teardown
* Create program with objectives "plan 9cod" "Payroll System" - teardown
* Create program with objectives "plan 123" "Foo" - teardown


