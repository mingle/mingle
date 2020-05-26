package net.sf.sahi.config;

import java.io.File;

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
public class ConfigurationTest extends TestCase {
	private static final long serialVersionUID = -2118478735809372530L;
	private String basePath;
	private String userDataDirectory;
	
	@Override
	protected void setUp() throws Exception {
		super.setUp();
		basePath = new File(".").getCanonicalPath().replace('\\', '/');
		userDataDirectory = new File(basePath, "userdata/").getCanonicalPath().replace('\\', '/');
	}

	public void testSplit(){
        assertEquals("a", "a\nb\nc".split("\n")[0]);
        assertEquals("b", "a\nb\nc".split("\n")[1]);
        assertEquals("c", "a\nb\nc".split("\n")[2]);
    }

    public void testGetRenderableContentTypes(){
    	assertEquals("a\nb", "a\r\nb".replaceAll("\\\r", ""));
    }

    public void testGetNonBlankLines(){
        assertEquals("a", Configuration.getNonBlankLines(" \r\n a \r\n")[0]);
    }
    public void testInit(){
		Configuration.init(basePath + "", userDataDirectory);
    	assertEquals(userDataDirectory + "/logs/playback", Configuration.getPlayBackLogsRoot().replace('\\', '/'));
    	assertEquals(userDataDirectory + "/certs", Configuration.getCertsPath().replace('\\', '/'));
    	assertEquals(userDataDirectory + "/temp/download", Configuration.tempDownloadDir().replace('\\', '/'));
    	assertEquals("sahi", Configuration.getControllerMode());
    }
    public void testInitJava(){
		Configuration.initJava(basePath + "", userDataDirectory);
    	assertEquals(userDataDirectory + "/logs/playback", Configuration.getPlayBackLogsRoot().replace('\\', '/'));
    	assertEquals(userDataDirectory + "/certs", Configuration.getCertsPath().replace('\\', '/'));
    	assertEquals(userDataDirectory + "/temp/download", Configuration.tempDownloadDir().replace('\\', '/'));
    	assertEquals("java", Configuration.getControllerMode());
    }    
}
