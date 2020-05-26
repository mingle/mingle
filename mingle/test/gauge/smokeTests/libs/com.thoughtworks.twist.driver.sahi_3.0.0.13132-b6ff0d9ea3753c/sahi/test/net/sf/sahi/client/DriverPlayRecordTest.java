package net.sf.sahi.client;

import junit.framework.TestCase;
import net.sf.sahi.Proxy;
import net.sf.sahi.config.Configuration;

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
public class DriverPlayRecordTest extends TestCase {
	private static final long serialVersionUID = -5086443670358903534L;
	private Browser browser;
	private Proxy proxy;
	String basePath = ".";
	private String userDataDirectory = "./userdata/";

	public void setUp(){
		System.setProperty("sahi.mode.dev", "true");
		Configuration.initJava(basePath, userDataDirectory);
		proxy = new Proxy();
		proxy.start(true);

		try {
			Runtime.getRuntime().exec(new String[]{basePath + "\\tools\\toggle_IE_proxy.exe", "enable"});
			Thread.sleep(1000);
		} catch (Exception e) {
			e.printStackTrace();
		}
		
		browser = new Browser("ie");
		browser.open();
	}
	
	public void testRecorder() throws ExecutionException{
		System.out.println("--- startRecording");
		browser.startRecording(); // check that controller window is opened, and navigateTo is added.
		int i=0;
		while (i++<30){
			String[] steps = browser.getRecordedSteps();
			for (int j = 0; j < steps.length; j++) {
				if (!"".equals(steps[j])) 
					System.out.println("Record: " + steps[j]);
			}
			browser.waitFor(1000);
		}
		System.out.println("--- stopRecording");
		browser.stopRecording();
		browser.waitFor(1000); // check that controller window is closed.

		
		// Perform a few actions, the way Twist performs initial steps and halts for recording
		browser.navigateTo("http://sahi.co.in/demo/index.htm");
		assertTrue(browser.link("Link Test").exists());
		assertFalse(browser.link("Link Test 1111").exists());
		browser.link("Link Test").click();
		browser.link("Back").click();
		
		// Start recording
		System.out.println("--- startRecording");
		browser.startRecording(); // check that controller window is opened.
		
		// Simple loop to wait for 30 seconds while looking for recorded steps.
		// You can click and perform other actions on the browser during these 30 seconds.
		// The actions performed will be recorded and in this case, printed on the console
		// You can press ALT-DblClick or CTRL-ALT-DblClick  on the browser 
		// to bring up the Controller for assertions.
		// Make sure to come back to your index page so that further steps can be performed.
		i=0;
		while (i++<40){
			String[] steps = browser.getRecordedSteps();
			for (int j = 0; j < steps.length; j++) {
				if (!"".equals(steps[j])) 
					System.out.println("Record: " + steps[j]);
			}
			browser.waitFor(1000);
		}
		
		// Stop recording 
		System.out.println("--- stopRecording");
		browser.stopRecording();
		browser.waitFor(1000); // check that controller window is closed.
		// Continue with further steps like Twist does.
		browser.link("Form Test").click();
		browser.waitFor(2000); // check that controller window is not re-opened.
		browser.link("Back").click();
	}
	
	public void tearDown(){
		browser.close();		
		proxy.stop();
		try {
			Runtime.getRuntime().exec(new String[]{basePath + "\\tools\\toggle_IE_proxy.exe", "disable"});
			Thread.sleep(1000);
		} catch (Exception e) {
			e.printStackTrace();
		}
	}
}
