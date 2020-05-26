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
 * User: dlewis
 * Date: Dec 11, 2006
 * Time: 5:47:23 PM
 */
public class JunitReporterTest extends TestCase {
	private static final long serialVersionUID = -2056790640359715868L;

	public void testCreateSuiteLogFolder()  {
        assertEquals(false,new JunitReporter("").createSuiteLogFolder());   
    }
}
