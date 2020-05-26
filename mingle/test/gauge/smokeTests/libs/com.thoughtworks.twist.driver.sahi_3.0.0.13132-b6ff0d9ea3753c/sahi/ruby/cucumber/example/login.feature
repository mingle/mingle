Feature: Login
  In order to access the system
  As a user
  I want to be able to login
  
  Scenario: Login with valid credentials
    Given I am not logged in
    When I try to login with "test" and "secret"
    Then I should be logged in
    
  Scenario: Login with invalid credentials
    Given I am not logged in
    When I try to login with "test" and "wrongpassword"
    Then I should not be logged in
    And I should be shown error message "Invalid username or password"
    