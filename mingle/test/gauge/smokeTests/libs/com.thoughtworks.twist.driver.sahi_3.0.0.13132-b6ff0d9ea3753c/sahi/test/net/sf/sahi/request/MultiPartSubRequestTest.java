package net.sf.sahi.request;

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
 * User: nraman
 * Date: May 18, 2005
 * Time: 8:42:08 PM
 */
public class MultiPartSubRequestTest extends TestCase {
	private static final long serialVersionUID = 3538233569242971732L;

	public void testParse() {
        String s = "form-data; name=\"f1\"; filename=\"test.txt\"";
        MultiPartSubRequest multiPartSubRequest = new MultiPartSubRequest();
        multiPartSubRequest.setNameAndFileName(s);
        assertEquals("f1", multiPartSubRequest.name());
        assertEquals("test.txt", multiPartSubRequest.fileName());

    }

    public void testGetValue(){
        assertEquals("f1", MultiPartSubRequest.getValue("name=\"f1\""));
        assertEquals("test.txt", MultiPartSubRequest.getValue("filename=\"test.txt\""));
    }


}
