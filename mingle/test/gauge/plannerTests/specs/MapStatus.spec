MapStatus
=========

tags: add_remove_work

Setup of contexts
* Login to mingle as "admin" - setup
* Create projects "SAP, Java,DotNet" with cards - setup
* Create program with objectives "Finance Program" "Payroll System, Billing System" - setup
* Create projects "Ruby" with "1" cards - setup

MapStatus
---------

Story #11259 (Allow different projects to have different "status" properties and map them to planner "status")
Story #11698 (Show progress information on objective page)

Show relevent done status when project has no mananged text property for mapping
* Navigate to program "Finance Program" projects page
* Associate projects "Java, Ruby" with program
* Assert links "Java, define a managed text property in this project" present for project "Java"

Creating properties in projects
* Create any text property "Release" in project "Java"
* Create managed number property "Iteration" in project "Java" with values "1, 2, 3"
* Create managed text property "No value property" in project "Java" with values ""
* Create managed text property "Status" in project "Java" with values "Open, Closed"
* Create managed text property "Story Status" in project "SAP" with values "New, Done"
* Create hidden managed text property "Hidden Property" in project "DotNet" with values "Hidden,Hidden2"
* Create card type "storie's" in project "Java"
* Create managed text property "no type property" with values "a , b, c" in project "Java" without card type

Show relevent done status message when projects have mananged text properties for mapping
* Navigate to program "Finance Program" projects page
* Associate projects "SAP, DotNet" with program
* Assert links "define done status" present for project "Java"
* Assert links "define done status" present for project "SAP"
* Assert links "define done status" present for project "DotNet"

Should be able to map manange text properties from project to plan but cannot map non-mananged text property
* Open define done status page of project "Java"
* Assert that cannot see property "Release" in mapping dropdown list
* Assert that cannot see property "Iteration" in mapping dropdown list
* Select property "No value property" and assert values "No Values Defined" in mapping dropdown list
* Assert save button disabled with message "The card type tracked by this definition is: \"storie\\'s\", ,\"Card\","
* Select property "no type property" and assert values "a,b,c" in mapping dropdown list
* Assert save button disabled with message "No card types are associated with the selected property."
* Select property "Status" and assert values "Open, Closed" in mapping dropdown list
* Map property "Status" value "Closed" to plan done status
* Navigate to program "Finance Program" projects page
* Open define done status page of project "SAP"
* Map property "Story Status" value "Done" to plan done status

Can map hidden property (bug #11512)
* Navigate to program "Finance Program" projects page
* Open define done status page of project "DotNet"
* Map property "Hidden Property" value "Hidden" to plan done status


Show relevent done status when project have properties mapped already.
* Open "Projects" page
* Assert links "Status >= Closed" present for project "Java"
* Assert links "Story Status >= Done" present for project "SAP"
* Assert links "Hidden Property >= Hidden" present for project "DotNet"


Objective summary and objective progress should reflect the cards update in project
* Add card "1" from project "SAP" to plan "Finance Program" and assign to objective "Payroll System"
* Add cards with numbers "1" from project "Java"
* Add cards with numbers "1" from project "Ruby"
* Open "Plan" page
* Open objective "Payroll System" popup
* Assert that objective popup shows "Java" project has "0" completed work items out of "1" total
* Assert that objective popup shows "Ruby" project has "0" completed work items out of "1" total
* Assert that objective popup shows "SAP" project has "0" completed work items out of "1" total
* Set "Story Status" in card number "1" of project "SAP" to "Done"
* Set "Status" in card number "1" of project "Java" to "Closed"
* Open objective "Payroll System" popup
* Assert that objective popup shows "Java" project has "1" completed work items out of "1" total
* Assert that objective popup shows "Ruby" project has "0" completed work items out of "1" total
* Assert that objective popup shows "SAP" project has "1" completed work items out of "1" total
* Set "Story Status" in card number "1" of project "SAP" to "New"
* Open objective "Payroll System" popup
* Assert that objective popup shows "Java" project has "1" completed work items out of "1" total
* Assert that objective popup shows "Ruby" project has "0" completed work items out of "1" total
* Assert that objective popup shows "SAP" project has "0" completed work items out of "1" total

Check the status column on plan work page
* View all work for "Payroll System" objective
* Assert that the status column for cards "Java_1" is "Done"
* Assert that the status column for cards "Ruby_1" is "\"Done\" status not defined for project"
* Assert that the status column for cards "SAP_1" is "Not done"


___

Teardown of contexts
* Create projects "Ruby" with "1" cards - teardown
* Create program with objectives "Finance Program" "Payroll System, Billing System" - teardown
* Create projects "SAP, Java,DotNet" with cards - teardown
* Login to mingle as "admin" - teardown


