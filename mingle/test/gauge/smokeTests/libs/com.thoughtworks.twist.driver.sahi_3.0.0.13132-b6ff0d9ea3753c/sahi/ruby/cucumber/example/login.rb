require  'sahi'

def init_browser()
  #Use the correct paths from your system
  userdata_dir = "D:/Dev/sahi/sahi_993/userdata"
  browser_path = "C:\\Program Files\\Mozilla Firefox\\firefox.exe"
  browser_options = "-profile #{userdata_dir}/browser/ff/profiles/sahi0 -no-remote"
  return Sahi::Browser.new(browser_path, browser_options)
end

#open the browser at the start
browser = init_browser()
browser.open

#close the browser on exit
at_exit do
  browser.close
end

Given /^I am not logged in$/ do
  browser.navigate_to("http://sahi.co.in/demo/training/index.htm")
end

When /^I try to login with "([^\"]*)" and "([^\"]*)"$/ do |username, password|
  browser.textbox("user").value = username
  browser.password("password").value = password
  browser.submit("Login").click
end

Then /^I should be logged in$/ do
  if !browser.button("Logout").exists?
    raise "Not logged in"
  end
end

Then /^I should not be logged in$/ do
  if !browser.submit("Login").exists?
    raise "Logged in"
  end
end

Then /^I should be shown error message "([^\"]*)"$/ do |msg|
  value = browser.div("errorMessage").text
  if value != msg
    raise "Incorrect message: #{value}" 
  end
end

