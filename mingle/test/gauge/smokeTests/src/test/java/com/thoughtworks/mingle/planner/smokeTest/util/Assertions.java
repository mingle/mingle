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

package com.thoughtworks.mingle.planner.smokeTest.util;

import static junit.framework.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import java.util.regex.Pattern;

import net.sf.sahi.client.Browser;
import net.sf.sahi.client.BrowserCondition;
import net.sf.sahi.client.ElementStub;
import net.sf.sahi.client.ExecutionException;

public class Assertions extends Constants {
    protected Browser browser;

    public Assertions(Browser browser) {
        this.browser = browser;
    }

    public void waitFor(final String jsCondition) {
        browser.waitFor(new BrowserCondition(browser) {
            public boolean test() throws ExecutionException {
                return Boolean.parseBoolean(browser.fetch(jsCondition));
            }
        }, 10000);
    }

    public void waitForAjaxCallFinished() {
        waitFor("MingleAjaxTracker.allAjaxComplete()");
    }

    public void waitForLightboxShowup() {
        waitFor("$('lightbox').visible()");
    }

    // our element fade in time is 0.5 sec,
    // this wait should sync with our code
    public void waitForElementFadeIn() {
        try {
            Thread.sleep(500);
        } catch (InterruptedException e) {
        }
    }

    @com.thoughtworks.gauge.Step("Assert current page is <pageURL>")
	public void assertCurrentPageIs(String pageURL) {
        assertEquals(this.getPlannerBaseUrl() + pageURL, this.currentURL());
    }

    public void assertCurrentURLIs(String ExpectedURL) {
        assertEquals(this.getPlannerBaseUrl() + ExpectedURL, this.currentURL());
    }

    public void assertMatch(String regex, String content) {
        String message = "<" + content + "> does not match </" + regex + "/>";
        assertTrue(message, Pattern.matches(regex, content));
    }

    public void assertNotMatch(String regex, String content) {
        String message = "Expected  <" + content + "> not matches </" + regex + "/>";
        assertFalse(message, Pattern.matches(regex, content));
    }

    public void assertInclude(String content, String included) {
        assertMatch(".*" + Pattern.quote(included) + ".*", content);
    }

    public void assertNotInclude(String content, String included) {
        assertNotMatch(".*" + Pattern.quote(included) + ".*", content);
    }

    public String bodyText() {
        return browser.accessor("window.document.body").getText();
    }

    @com.thoughtworks.gauge.Step("Assert text present <message>")
	public void assertTextPresent(String message) {
        assertInclude(bodyText(), message);
    }

    public void assertTextPresentIn(String text, ElementStub element) {
        String content = element.getText();
        assertInclude(content, text);

    }

    @com.thoughtworks.gauge.Step("Assert <linkNames> link present")
	public void assertLinkPresent(String linkNames) {

        for (String linkName : linkNames.split(",")) {
            assertTrue(linkName + " is not found on current page! ", browser.link(linkName).isVisible());

        }

    }

    public void assertLinkNotPresent(String linkName) {
        assertFalse(linkName + " is found on current page! ", browser.link(linkName).isVisible());
    }

    public void assertElementNotPresent(String elementId) throws Exception {
        assertFalse("Element with ID " + elementId + " is still visible", browser.byId(elementId).isVisible());
    }

    public void navigateTo(String... paths) {
        String[] idPaths = new String[paths.length];
        for (int i = 0; i < paths.length; i++) {
            idPaths[i] = identifier(paths[i]);
        }
        this.browser.navigateTo(pathTo(idPaths));
    }

    private String identifier(String name) {
        return name;
    }

    public String currentURL() {
        return browser.fetch("window.location.href");
    }

    public void assertRowInTableHasText(Integer rowNumber, String tableId, String... texts) throws Exception {
        for (String text : texts) {
            ElementStub table = browser.table(tableId);
            assertTrue("Expected <" + text + "> presents, but got " + table.getText(), browser.row(rowNumber).in(table).getText().contains(text));
        }
    }

    /**
     * Retrieve the text only (no HTML) of the Nth element matched by the provided css locator
     * 
     * @param locator
     * @param index
     *            0-based
     * @return Text with no html
     */
    public String getTextWithCssLocator(String locator, int index) {
        return browser.fetch(String.format("$$('%s')[%d].innerHTML.strip().stripTags()", locator, index));
    }

    @com.thoughtworks.gauge.Step("Assert that product is <productType>")
	public void assertThatProductIs(String productType) throws Exception {
        assertTrue(browser.listItem("Product:" + productType).isVisible());

    }

    @com.thoughtworks.gauge.Step("Switch to <viewName> view - Assertions")
	public void switchToView(String viewName) throws Exception {
        String link_id = viewName.trim().toLowerCase() + "_selector";
        browser.link(link_id).click();
        waitForTimeLineStatusIsReady();
    }

    public void waitForTimeLineStatusIsReady() {
        waitFor("TimelineStatus.instance.isReady()");
    }
}
