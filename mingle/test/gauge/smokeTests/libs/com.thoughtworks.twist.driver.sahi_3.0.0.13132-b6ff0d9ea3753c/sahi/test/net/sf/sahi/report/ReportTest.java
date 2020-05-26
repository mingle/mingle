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
/**
 * @author dlewis
 * 
 */
public class ReportTest extends TestCase {
	private static final long serialVersionUID = -2966355524465595469L;
	
	private Report report = null;

	protected void setUp() throws Exception {
		super.setUp();
		report = new Report("test", new HtmlReporter(null));
	}

	protected void tearDown() throws Exception {
		super.tearDown();
	}

	public void testAddResult() {
		report.addResult("a", "success", "", null);
		assertEquals(1, report.getListResult().size());
	}

	/*
	 * public void xtestGenerateReportForDefaultLogDir() throws
	 * FileNotFoundException { report.addResult(ReportUtil.getListResult());
	 * report.generateReport(); assertNotNull(new
	 * FileReader(Configuration.appendLogsRoot(report
	 * .getFormatter().getFileName(Utils.createLogFileName("test"))))); }
	 * 
	 * public void xtestGenerateReportForCustomLogDir() throws
	 * FileNotFoundException { report.addResult(ReportUtil.getListResult());
	 * report.generateReport(); assertNotNull(new
	 * FileReader(Configuration.appendLogsRoot(report
	 * .getFormatter().getFileName(Utils.createLogFileName("test"))))); }
	 */

	public void testSummarizeResultsForEmptyList() {
		TestSummary summary = report.summarizeResults("");
		assertEquals(0, summary.getSteps());
	}

	public void testSummarizeResultsForAllTypes() {
		report.addResult(ReportUtil.getListResult());
		TestSummary summary = report.summarizeResults("");
		assertEquals(3, summary.getSteps());
		assertEquals(1, summary.getFailures());
		assertEquals(0, summary.getErrors());
		assertEquals("test", summary.getScriptName());
	}

	
}
