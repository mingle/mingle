package net.sf.sahi.report;

import junit.framework.TestCase;
import net.sf.sahi.config.Configuration;
import net.sf.sahi.util.Utils;

/**
 * Sahi - Web Automation and Test Tool
 * 
 * Copyright  2006  V Narayan Raman
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
/**
 * @author dlewis
 */
public class HtmlFormatterTest extends TestCase {
	private static final long serialVersionUID = 17080619161553882L;

	static {
		Configuration.init();
	}
	
    private HtmlFormatter formatter = null;

    private String expectedSummaryForEmptyList = new StringBuffer(
            "<tr class=\"SUCCESS\"><td>test</td><td>0</td>").append(
            "<td>0</td><td>0</td><td>100%</td><td>0</td></tr>").toString();

    private String expectedSummaryForAllTypes = new StringBuffer("<tr class=\"FAILURE\"><td>test</td><td>3</td>").append(
            "<td>1</td><td>0</td><td>66%</td><td>0</td></tr>").toString();

    protected void setUp() throws Exception {
        super.setUp();
        formatter = new HtmlFormatter();
    }

    protected void tearDown() throws Exception {
        super.tearDown();
    }

    public void testGetFileName() {
        assertEquals("test.htm", formatter.getFileName("test"));
    }

    public void xtestGetStringResultForSuccessResult() {
        String expected = "<div class=\"SUCCESS\"><a class=\"SUCCESS\">_assertNotNull(_textarea(\"t2\"));</a></div>";
        assertEquals(expected, formatter.getStringResult(ReportUtil
                .getSuccessResult()));
    }

    public void xtestGetStringResultForFailureResult() {
        String expected = "<div class=\"FAILURE\"><a class=\"FAILURE\">_call(testAccessors()); Assertion Failed.</a></div>";
        assertEquals(expected, formatter.getStringResult(ReportUtil
                .getFailureResultWithoutDebugInfo()));
    }

    public void xtestGetStringResultForInfoResult() {
        String expected = "<div class=\"INFO\"><a class=\"INFO\" href=\"/_s_/dyn/Log_highlight?href=blah\">_click(_link(\"Form Test\"));</a></div>";
        assertEquals(expected, formatter.getStringResult(ReportUtil
                .getInfoResult()));
    }

    public void testGetResultDataForEmptyList() {
        assertEquals("", formatter.getResultData(null));
    }

    public void testGetResultDataForListWithAllTypesOfResults() {
        String expected = new StringBuffer(formatter.getStringResult(ReportUtil
                .getInfoResult())).append("\n").append(
                formatter.getStringResult(ReportUtil.getSuccessResult()))
                .append("\n").append(
                formatter.getStringResult(ReportUtil.getFailureResultWithoutDebugInfo()))
                .append("\n").toString();

        assertEquals(expected, formatter.getResultData(ReportUtil
                .getListResult()));
    }

    public void testGetHeader() {
        String expected = new StringBuffer("<head><meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\" />\n<style>\n").append(
                new String(Utils.readFileAsString(Configuration
                        .getPlaybackLogCSSFileName(true)))).append(
                new String(Utils.readFileAsString(Configuration
                        .getConsolidatedLogCSSFileName(true)))).append(
                "</style></head>\n").toString();
        assertEquals(expected, formatter.getHeader());
    }

    public void testGetSummaryHeader() {
        String expected = "<table class='summary'><tr><td>Test</td><td>Total Steps</td><td>Failures</td><td>Errors</td><td>Success Rate</td><td>Time Taken (ms)</td></tr>";
        assertEquals(expected, formatter.getSummaryHeader());
    }

    public void testGetSummaryFooter() {
        String expected = "</table>";
        assertEquals(expected, formatter.getSummaryFooter());
    }

    public void testGetSummaryDataForEmptyList() {
        TestSummary summary = new TestSummary();
        summary.setScriptName("test");
        assertEquals(expectedSummaryForEmptyList, formatter
                .getSummaryData(summary));
    }

    public void testGetSummaryDataForAllTypesWithoutLink() {
        assertEquals(expectedSummaryForAllTypes, formatter
                .getSummaryData(ReportUtil.getTestSummary()));
    }

    public void testGetSummaryDataForAllTypesWithLink() {
        String expected = expectedSummaryForAllTypes.replaceFirst("test", "<a class=\"SCRIPT\" href=\"test.htm\">test</a>");
        TestSummary summary =  ReportUtil.getTestSummary();
        summary.setLogFileName("test");
        summary.setAddLink(true);
        assertEquals(expected, formatter
                .getSummaryData(summary));
    }
    
    public void testNewLinesConvertedToBRTag() {
    	String expected = "Difference in array length:<br/>Expected Length<br/>Another line<br/>abc"; 
        TestResult result = new TestResult("Difference in array length:\nExpected Length\nAnother line", ResultType.INFO, "abc", "abc");
		String stringResult = formatter.getStringResult(result);
		assertTrue(stringResult.contains(expected));
    }
}
