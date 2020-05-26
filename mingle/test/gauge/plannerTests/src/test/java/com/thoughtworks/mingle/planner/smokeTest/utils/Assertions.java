/*
*  Copyright 2020 ThoughtWorks, Inc.
*  
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*  
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*  
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/

package com.thoughtworks.mingle.planner.smokeTest.utils;


import org.junit.Assert;
import org.openqa.selenium.*;
import org.openqa.selenium.interactions.Action;
import org.openqa.selenium.interactions.Actions;
import org.openqa.selenium.support.ui.*;

import java.util.List;
import java.util.concurrent.TimeUnit;
import java.util.function.Function;
import java.util.regex.Pattern;

public class Assertions extends Constants {

    protected WebDriver driver;

    public Assertions() {
        this.driver=DriverFactory.getDriver();
    }

    public void navigateTo(String... paths) {
        String[] idPaths = new String[paths.length];
        for (int i = 0; i < paths.length; i++) {
            idPaths[i] = identifier(paths[i]);
        }
        this.driver.get(pathTo(idPaths));
    }

    public void assertMatch(String regex, String content) {
        String message = "<" + content + "> does not match </" + regex + "/>";
        Assert.assertTrue(message, Pattern.matches(regex, content));
    }

    public void assertTrue(boolean condition){
        String message = "<" + condition + "> does not match >";
        Assert.assertTrue(message,condition);
    }

    public void assertTrue(String message, boolean condition)
    {
        Assert.assertTrue(message,condition);
    }

    public void assertFalse(boolean condition)
    {
        Assert.assertFalse(condition);
    }

    public void assertFalse(String message, boolean condition){
        Assert.assertFalse(message, condition);
    }

    public void assertEquals(String actual, String expected)
    {
        String message = "<" + actual + "> does not match >";
        Assert.assertEquals(message,actual,expected);
    }

    public void assertEquals(String message, String actual, String expected)
    {
        Assert.assertEquals(message,actual,expected);
    }

    public void assertEquals(String message, int actual, int expected){
        Assert.assertEquals(message,actual,expected);
    }

    @com.thoughtworks.gauge.Step("Assert <linkNames> link present")
    public void assertLinkPresent(String linkNames) {
        for (String linkName : linkNames.split(",")) {
            assertTrue(linkName + " is not found on current page! ", findElementsByLinkText("Sign out").size()>0);
        }
    }

    public void assertEquals(String message, boolean expected, boolean actual)
    {
        Assert.assertEquals(message,expected,actual);
    }

    @com.thoughtworks.gauge.Step("Assert current page is <pageURL>")
    public void assertCurrentPageIs(String pageURL) {
        assertEquals(this.getPlannerBaseUrl() + pageURL, this.currentURL());
    }

    public void waitForAjaxCallFinished() {
        excecuteJs("MingleAjaxTracker.allAjaxComplete()");
    }

    public boolean waitForAllAjaxCompleted(){
        return (boolean) ((JavascriptExecutor)driver).executeScript("return MingleAjaxTracker.allAjaxComplete()");
    }

    public void excecuteJs(final String jsCondition) {
        ((JavascriptExecutor)driver).executeScript(jsCondition);
    }

    public boolean executeJsWithBooleanReturn(final String jsCondition){
        return (boolean) ((JavascriptExecutor)driver).executeScript(jsCondition);
    }

    public int excecuteJsWithindexreturn(final String jsCondition) throws InterruptedException {
        Object response = ((JavascriptExecutor)driver).executeScript(jsCondition);
        int i = Integer.parseInt(response+"");
        return i;
    }

    public String excecuteJsWithStringretun(final String jsCondition){
        Object response = ((JavascriptExecutor)driver).executeScript(jsCondition);
        String str=response+"";
        return str;
    }

    public void refreshThePage(){
        excecuteJs("window.location.reload();");
    }

    //Use this method only when element loading time is huge
    public void waitForPageLoad(int miliSecond) throws InterruptedException {
        Thread.sleep(miliSecond);
    }

    public void waitForTimeLineStatusIsReady() {
        excecuteJs("TimelineStatus.instance.isReady()");
    }

    public void waitForElement(By by) throws InterruptedException {
        try {
            WebDriverWait wait = new WebDriverWait(this.driver, 5);
            wait.until(ExpectedConditions.visibilityOfElementLocated(by));
        }catch (org.openqa.selenium.StaleElementReferenceException e){
            WebDriverWait wait = new WebDriverWait(this.driver, 5);
            wait.until(ExpectedConditions.visibilityOfElementLocated(by));
        }
    }

    public  void waitForElementClickable(By by)
    {
        try {
            WebDriverWait wait = new WebDriverWait(this.driver, 5);
            wait.until(ExpectedConditions.elementToBeClickable(by));
        }catch (org.openqa.selenium.StaleElementReferenceException e){
            WebDriverWait wait = new WebDriverWait(this.driver, 5);
            wait.until(ExpectedConditions.elementToBeClickable(by));
        }

    }

    @com.thoughtworks.gauge.Step("Switch to <viewName> view - Assertions")
    public void switchToView(String viewName) throws Exception {
        String link_id = viewName.trim().toLowerCase() + "_selector";
        waitForPageLoad(5000);
        waitForElement(By.id(link_id));
        try {
            excecuteJs("$j('#"+link_id+"').click()");
        }catch (Exception e){
            waitForPageLoad(5000);
            excecuteJs("$j('#"+link_id+"').click()");
        }
        waitForPageLoad(4000);
        assertTrue("Unable to switch to the view", findElementsByXpath("//*[@class=\"selected\" and text()=\""+viewName.trim()+"\"]").size()>0);
        waitForTimeLineStatusIsReady();
    }

    @com.thoughtworks.gauge.Step("Reload the page from server")
    public void reloadThePage(){
        excecuteJs("location.reload(true)");
    }

    public void selectByText(String selectId, String optionText) throws InterruptedException {
            Select dropdown = new Select(findElementById(selectId.trim()));
            dropdown.selectByVisibleText(optionText);
    }

    public void dragAndDrop(WebElement from, WebElement to) throws InterruptedException {
        Actions builder = new Actions(driver);
        Action dragAndDrop = builder.clickAndHold(from)
                .moveToElement(to)
                .release(to)
                .build();
        dragAndDrop.perform();
        Thread.sleep(1000);
    }


    public void scrollToEndOfPage() throws InterruptedException {
        ((JavascriptExecutor)this.driver).executeScript("window.scrollTo(0,document.body.scrollHeight);");
        Thread.sleep(2000);
    }
    public void scrollToTopOfpage() throws InterruptedException {
        ((JavascriptExecutor)this.driver).executeScript("window.scrollTo(document.body.scrollHeight,0);");
        Thread.sleep(2000);
    }
    public void scrollInToText(String text)
    {
        ((JavascriptExecutor)this.driver).executeScript("document.evaluate(\"//a[text()='"+text+"']\", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.scrollIntoView()");
    }

    public void scrollInToViewById(String id) throws InterruptedException {
        ((JavascriptExecutor)this.driver).executeScript("document.getElementById(\""+id+"\").scrollIntoView()");
        Thread.sleep(1000);
    }

    public void scrollBy(int horizontalOffSet, int verticalOffSet) throws InterruptedException {
        excecuteJs("window.scrollBy("+horizontalOffSet+","+verticalOffSet+")");
        Thread.sleep(2000);
    }


    private String identifier(String name) {
        return name;
    }

    public String currentURL() {
        return this.driver.getCurrentUrl();
    }

    //Find element locators

    public WebElement findElementByClass(String className)
    {
        WebElement elementByClass = stubbornWait(this.driver).until(new Function<WebDriver, WebElement>() {
            public WebElement apply(WebDriver driver) {
                return driver.findElement(By.className(className));
            }
        });
        return elementByClass;

    }

    public List<WebElement> findElementsByClass(String className)
    {
        return this.driver.findElements(By.className(className));
    }
    public WebElement findElementById(String id)
    {
        WebElement elementById = stubbornWait(this.driver).until(new Function<WebDriver, WebElement>() {
            public WebElement apply(WebDriver driver) {
                return driver.findElement(By.id(id));
            }
        });
        return elementById;
    }

    public List<WebElement> findElementsById(String id)
    {
        return this.driver.findElements(By.id(id));
    }

    public WebElement findElementByPartialLinkText(String partialText){
        WebElement elementByPartiallinktext = stubbornWait(this.driver).until(new Function<WebDriver, WebElement>() {
            public WebElement apply(WebDriver driver) {
                return driver.findElement(By.partialLinkText(partialText));
            }
        });
        return elementByPartiallinktext;
    }

    public List<WebElement> findElementsByPartialLinkText(String partialText){
        return this.driver.findElements(By.partialLinkText(partialText));
    }

    public WebElement findElementByLinkText(String linkText){
        WebElement elementByLinkText = stubbornWait(this.driver).until(new Function<WebDriver, WebElement>() {
            public WebElement apply(WebDriver driver) {
                return driver.findElement(By.linkText(linkText));
            }
        });
        return elementByLinkText;
    }

    public List<WebElement> findElementsByLinkText(String linkText){
        return this.driver.findElements(By.linkText(linkText));
    }

    public WebElement findElementByCssSelector(String css){
        WebElement elementByCss = stubbornWait(this.driver).until(new Function<WebDriver, WebElement>() {
            public WebElement apply(WebDriver driver) {
                return driver.findElement(By.cssSelector(css));
            }
        });
        return elementByCss;
    }

    public List<WebElement> findElementsByCssSelector(String css){
        return this.driver.findElements(By.cssSelector(css));
    }

    public WebElement findElementByXpath(String xpath)
    {
        WebElement elementByXpath = stubbornWait(this.driver).until(new Function<WebDriver, WebElement>() {
            public WebElement apply(WebDriver driver) {
                return driver.findElement(By.xpath(xpath));
            }
        });
        return elementByXpath;
    }

    public WebElement findElementByName(String name)
    {
        WebElement elementByname = stubbornWait(this.driver).until(new Function<WebDriver, WebElement>() {
            public WebElement apply(WebDriver driver) {
                return driver.findElement(By.name(name));
            }
        });
        return elementByname;
    }

    public Wait<WebDriver> stubbornWait(WebDriver driver)
    {
        Wait<WebDriver> stubbornWait = new FluentWait<WebDriver>(driver)
                .withTimeout(30, TimeUnit.SECONDS)
                .pollingEvery(5, TimeUnit.SECONDS)
                .ignoring(NoSuchElementException.class)
                .ignoring(StaleElementReferenceException.class);
        return stubbornWait;

    }

    public List<WebElement> findElementsByName(String name)
    {
        return this.driver.findElements(By.name(name));
    }

    public List<WebElement> findElementsByXpath(String xpath)
    {
        return this.driver.findElements(By.xpath(xpath));
    }

}
