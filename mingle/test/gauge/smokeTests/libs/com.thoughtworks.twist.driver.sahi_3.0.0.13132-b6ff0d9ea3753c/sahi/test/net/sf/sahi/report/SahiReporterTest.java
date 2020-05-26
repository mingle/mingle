package net.sf.sahi.report;

import java.util.ArrayList;

import net.sf.sahi.config.Configuration;
import net.sf.sahi.test.TestLauncher;
import net.sf.sahi.util.Utils;

import org.jmock.Mock;
import org.jmock.MockObjectTestCase;

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
 * Time: 4:50:00 PM
 */
public class SahiReporterTest extends MockObjectTestCase {
	private static final long serialVersionUID = 564123747953708945L;

	static {
		Configuration.init();
	}
	
    private SahiReporter reporter;
    private Mock mockFormatter;

    protected void setUp() throws Exception {
        super.setUp();
        mockFormatter = mock(Formatter.class);
        reporter = new SahiReporter("", (Formatter) mockFormatter.proxy()) {
            public boolean createSuiteLogFolder() {
                return false;
            }
        };
    }

    public void testGenerateSuiteReport() {
        mockFormatter.expects(once()).method("getSuiteLogFileName");
        mockFormatter.expects(once()).method("getFileName").will(returnValue("testFile"));

        mockFormatter.expects(once()).method("getHeader").will(returnValue("data"));
        mockFormatter.expects(once()).method("getSummaryHeader").after("getHeader").will(returnValue("data"));
        mockFormatter.expects(once()).method("getSummaryFooter").after("getSummaryHeader").will(returnValue("data"));
        mockFormatter.expects(once()).method("getFooter").after("getSummaryFooter").will(returnValue("data"));

        reporter.generateSuiteReport(new ArrayList<TestLauncher>());
    }

    public void xtestGenerateTestReport() {
        mockFormatter.expects(once()).method("getFileName").will(returnValue("testFile"));

        mockFormatter.expects(once()).method("getHeader").will(returnValue("data"));
        mockFormatter.expects(once()).method("getSummaryHeader").after("getHeader").will(returnValue("data"));
        mockFormatter.expects(once()).method("getSummaryData").after("getSummaryHeader").will(returnValue("data"));
        mockFormatter.expects(once()).method("getSummaryFooter").after("getSummaryData").will(returnValue("data"));
        mockFormatter.expects(once()).method("getStartScript").after("getSummaryFooter").will(returnValue("data"));
        mockFormatter.expects(once()).method("getResultData").after("getStartScript").will(returnValue("data"));
        mockFormatter.expects(once()).method("getStopScript").after("getResultData").will(returnValue("data"));
        mockFormatter.expects(once()).method("getFooter").after("getStopScript").will(returnValue("data"));

        Report report = new Report("",new ArrayList<SahiReporter>());
        report.setTestSummary(new TestSummary());
        reporter.generateTestReport(report, "");
    }

    public void testGetLogDirForNullLogDir() {
        assertEquals(Configuration.getPlayBackLogsRoot(), reporter.getLogDir());
    }

    public void testGetLogDirForCustomLogDir() {
        reporter.setLogDir("customDir");
        assertEquals("customDir", reporter.getLogDir());
    }

    public void testGetLogDirForNullLogDirWithCreateSuiteFolderSetToTrue() {
        reporter = new SahiReporter("", (Formatter) mockFormatter.proxy()) {
            public boolean createSuiteLogFolder() {
                return true;
            }
        };
        reporter.setSuiteName("junit");
        if(Utils.isWindows())
        	assertTrue(reporter.getLogDir().startsWith(Configuration.getPlayBackLogsRoot() + "\\junit__"));
        else
        	assertTrue(reporter.getLogDir().startsWith(Configuration.getPlayBackLogsRoot() + "/junit__"));

    }
}
