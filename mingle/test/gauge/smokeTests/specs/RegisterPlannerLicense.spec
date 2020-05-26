RegisterPlannerLicense
======================

tags: Plan, #11161, licensing and access

Setup of contexts
* Enable real license decryption - setup
* Login to mingle as "admin" - setup

RegisterPlannerLicense
----------------------

Story #11161 (Be able to turn on/off planner based on license)
Story #11274 Update the license page to include product edition

* Register license of the type "Valid Mingle license without Planner access"
* Assert that product is "Mingle"
* Assert that program tab is invisible

* Register license of the type "Valid Mingle license with Planner access"
* Assert that product is "Mingle Plus"
* Assert that program tab is visible

* Register license of the type "Expired license with Planner access"
* Assert that product is "Mingle Plus"
* Assert that program tab is invisible



___

Teardown of contexts
* Login to mingle as "admin" - teardown
* Enable real license decryption - teardown

