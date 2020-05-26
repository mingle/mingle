package net.sf.sahi.issue;

import junit.framework.TestCase;
import net.sf.sahi.report.TestSummary;
import net.sf.sahi.report.ReportUtil;

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
 * User: dlewis
 * Date: Dec 11, 2006
 * Time: 4:39:57 PM
 */
public class IssueFormatterTest extends TestCase {
	private static final long serialVersionUID = -8843504667335098410L;
	private IssueFormatter formatter = new IssueFormatter();

    public void testGetSummaryDataForSuccessSummary()  {
       assertEquals("",formatter.getSummaryData(new TestSummary()));
    }

    public void testGetSummaryDataForFailureSummary()  {
       String expected = "\n\nScript: test\nFailures: 1\nErrors: 0";
       assertEquals(expected,formatter.getSummaryData(ReportUtil.getTestSummary()));
    }
}
