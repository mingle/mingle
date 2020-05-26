package net.sf.sahi.client;

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


import junit.framework.TestCase;
import net.sf.sahi.Proxy;
import net.sf.sahi.config.Configuration;

public abstract class SahiTestCase extends TestCase {
	private static final long serialVersionUID = 9094239240720483156L;
	protected Browser browser;
	protected Proxy proxy;
	protected String sahiBasePath = ".";
	protected String userDataDirectory = "./userdata/";
	protected boolean isProxyInSameProcess = false;
	protected String browserName; 	

	
	public abstract void setBrowser();
	
	public void setUp(){
		Configuration.initJava(sahiBasePath, userDataDirectory);
		
		if (isProxyInSameProcess) {
			proxy = new Proxy();
			proxy.start(true);
		}

		setBrowser();
		
		browser = new Browser(browserName);		
		browser.open();
	}
	
	public void tearDown(){
		browser.setSpeed(100);
		browser.close();		
		if (isProxyInSameProcess) {
			proxy.stop();
		}
	}
	
	public void setBrowser(String browserName){
		this.browserName = browserName;
	}
}
