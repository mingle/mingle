ChangeLicenseDoesNotCleanLicenseCache
=====================================

tags: bug, licensing and access, cache, #11383, group_a

Setup of contexts
* Enable real license decryption - setup
* Login to mingle as "admin" - setup
* Create projects "SAP, Java" with cards - setup

ChangeLicenseDoesNotCleanLicenseCache
-------------------------------------

Bug #11383 (Keep getting 403 after switch license from 'planner not supported' to 'planner supported').

* Register license of the type "Valid Mingle license without Planner access"
* Register license of the type "Valid Mingle license with Planner access"
* Create program "Finance Program" with plan from "1 Jan 2010" to "10 Feb 2010" and switch to days view
* Open plan "Finance Program" in days view
* Create objective "Payroll System" starts on "6 Jan 2010" and ends on "4 Feb 2010" in days view
* Navigate to program "Finance Program" projects page
* Associate projects "Java, SAP" with program
* Register license of the type "Valid Mingle license without Planner access"
* Assert that cannot see programs tab
* Navigate to programs list page
* Assert that cannot access the requested resource


___

Teardown of contexts
* Create projects "SAP, Java" with cards - teardown
* Login to mingle as "admin" - teardown
* Enable real license decryption - teardown

