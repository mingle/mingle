package net.sf.sahi.report;

import junit.framework.TestCase;

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
public class JUnitFormatterTest extends TestCase {
	private static final long serialVersionUID = 1842921551229934964L;
	
	private JUnitFormatter formatter = null;

	protected void setUp() throws Exception {
		super.setUp();
		formatter = new JUnitFormatter();
	}

	protected void tearDown() throws Exception {
		super.tearDown();
	}

	public void testGetFileName() {
		assertEquals("TEST-test.xml", formatter.getFileName("test"));
	}

	public void testGetFooter() {
		String expected = "</testcase></testsuite>";
		assertEquals(expected, formatter.getFooter());
	}

	public void testGetHeader() {
		String expected = "<?xml version=\"1.0\" encoding=\"UTF-8\" ?>";
		assertEquals(expected, formatter.getHeader());
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

	public void testGetSummaryDataForEmptyList() {
		String expected = "\n<testsuite errors=\"0\" failures=\"0\" name=\"null.test\" tests=\"1\" time=\"0.0\">\n<testcase classname=\"null.test\" name=\"test\" time=\"0.0\">";
		TestSummary summary = new TestSummary();
		summary.setScriptName("test");
		assertEquals(expected, formatter.getSummaryData(summary));
	}

	public void testGetSummaryDataForAllTypes() {
		String expected = "\n<testsuite errors=\"0\" failures=\"1\" name=\"null.test\" tests=\"1\" time=\"0.0\">\n<testcase classname=\"null.test\" name=\"test\" time=\"0.0\">";
		assertEquals(expected, formatter.getSummaryData(ReportUtil
				.getTestSummary()));
	}

	public void testGetStringResultForSuccessResult() {
		String expected = "";
		assertEquals(expected, formatter.getStringResult(ReportUtil
				.getSuccessResult()));
	}

	public void testGetStringResultForFailureResultWithoutDebugInfo() {
		String expected = "\n<failure message=\"Assertion Failed\"><![CDATA[Assertion Failed.]]></failure>\n";
		assertEquals(expected, formatter.getStringResult(ReportUtil
				.getFailureResultWithoutDebugInfo()));
	}
	
	public void testGetStringResultForFailureResultWithDebugInfo() {
		String expected = "\n<failure message=\"Assertion Failed\"><![CDATA[Assertion Failed. Expected:[2] Actual:[1]]]></failure>\n";
		assertEquals(expected, formatter.getStringResult(ReportUtil
				.getFailureResultWithDebugInfo()));
	}
}
