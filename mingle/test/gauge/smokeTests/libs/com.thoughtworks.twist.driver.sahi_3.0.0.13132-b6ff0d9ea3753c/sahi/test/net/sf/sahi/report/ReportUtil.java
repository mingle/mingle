package net.sf.sahi.report;

import java.util.ArrayList;
import java.util.List;

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
public class ReportUtil {
	public static List<TestResult> getListResult() {
		List<TestResult> listResult = new ArrayList<TestResult>();
		listResult.add(getInfoResult());
		listResult.add(getSuccessResult());
		listResult.add(getFailureResultWithoutDebugInfo());
		return listResult;
	}

	public static TestResult getSuccessResult() {
		return new TestResult("_assertNotNull(_textarea(\"t2\"));",
				ResultType.SUCCESS, null, null);
	}

	public static TestResult getFailureResultWithoutDebugInfo() {
		return new TestResult("_call(testAccessors());",
				ResultType.FAILURE, "", "Assertion Failed.");
	}

	public static TestResult getFailureResultWithDebugInfo() {
		return new TestResult(
				"_call(testAccessors());",
				ResultType.FAILURE, null, "Assertion Failed. Expected:[2] Actual:[1]");
	}

	public static TestResult getInfoResult() {
		return new TestResult("_click(_link(\"Form Test\"));", ResultType.INFO,
				"blah", null);
	}

	public static TestSummary getTestSummary() {
		TestSummary summary = new TestSummary();
		summary.setScriptName("test");
		summary.setFailures(1);
		summary.setErrors(0);
		summary.setSteps(3);
        summary.setFail(true);
        return summary;
	}

}
