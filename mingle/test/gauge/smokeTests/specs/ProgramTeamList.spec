ProgramTeamList
===============

tags: plan team list, #12038

Setup of contexts
* Create projects "SAP" with cards - setup

ProgramTeamList
---------------


Initially there is no plan, only Mingle admin can create plan so he/she will be the first user of this plan.
* Login as "admin"
* Create program "First Plan" and switch to days view in plan
* Create program "Second Plan" and switch to days view in plan
* Open plan "First Plan" in days view


* Open "Team" tab
* Assert that there are "1" team members for program
* Assert that "admin" is on team members list


User can not see program on the Programs list page before he/she is added into program.
* Login as "bob"
* Navigate to programs list page
* Assert that program is not displayed on programs list "Finance Program"
* Navigate to programs list page
* Assert that program is not displayed on programs list "2nd Plan"
* Open plan "First Plan" via url
* Assert that cannot access the requested resource

Current program team user can add other users into this program team list
* Login as "admin"
* Open plan "First Plan" in days view
* Open "Team" tab
* Open add team members page
* Add user "bob" to program

Program team member can only see program he/she is a member of on the Program lists page.
* Login as "bob"
* Navigate to programs list page
* Assert that program "First Plan" is displayed on programs list
* Assert that program is not displayed on programs list "2nd Plan"

Plan team member cannot create program nor delete plan, only Mingle admin can do.
* Assert that cannot create program
* Open plan "First Plan"
* Open plan settings popup
* Assert that cannot delete program

Plan team member cannot see a new program without a plan, only Mingle admin can do.
* Login as "admin"
* Create new program
* Login as "bob"
* Assert that program is not displayed on programs list "New Program"

Plan team member can create/modify data in Plan;
* Open plan "First Plan" in days view
* Open "Team" tab
* Assert that "admin" is on team members list
* Assert that "bob" is on team members list
* Open "Plan" page
* Create objective "First Feature"
* Assert that objective "First Feature" is present
* Open "Projects" page
* Associate projects "SAP" with program
* Assert links "define a managed text property in this project" present for project "SAP"
* Add card "1" from project "SAP" to plan "First Plan" and assign to objective "First Feature"
* View all work for "First Feature" objective
* Assert that cards "1" of project "SAP" are present in work table

Light users and Existing plan team member cannot be added to plan
* Login as "admin"
* Navigate to users list page
* Change user "longbob" to light user
* Open plan "First Plan" in days view
* Open "Team" tab
* Open add team members page
* Assert that cannot add existing member "bob" to program
* Assert that cannot add light user "longbob" to program



___

Teardown of contexts
* Create projects "SAP" with cards - teardown


