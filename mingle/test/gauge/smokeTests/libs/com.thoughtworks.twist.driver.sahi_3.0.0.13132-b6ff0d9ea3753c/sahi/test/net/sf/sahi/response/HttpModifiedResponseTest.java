package net.sf.sahi.response;

import java.util.Iterator;
import java.util.List;

import net.sf.sahi.config.Configuration;
import net.sf.sahi.stream.filter.StreamFilter;
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

public class HttpModifiedResponseTest extends TestCase {
	private static final long serialVersionUID = -3402971698869800021L;

	static{
		Configuration.init();
	}
	
    public void testCharsetReturnsCharsetInMetaTag(){
    	String s = "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" /><meta http-equiv=\"zxz\"/></head>";
    	SimpleHttpResponse simpleHttpResponse = new SimpleHttpResponse(s);
    	simpleHttpResponse.removeHeader("Content-Type");
    	assertEquals(null, simpleHttpResponse.contentTypeHeader());
		HttpModifiedResponse resp = new HttpModifiedResponse(simpleHttpResponse, false, "htm");
    	assertEquals("utf-8", resp.charset());
    }

    public void testCharsetReturnsCharsetInHeader(){
    	String s = "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=xx\" /><meta http-equiv=\"zxz\"/></head>";
    	SimpleHttpResponse simpleHttpResponse = new SimpleHttpResponse(s);
    	simpleHttpResponse.removeHeader("Content-Type");
    	simpleHttpResponse.addHeader("Content-Type", "text/html; charset=utf-8");
    	assertEquals("text/html; charset=utf-8", simpleHttpResponse.contentTypeHeader());
		HttpModifiedResponse resp = new HttpModifiedResponse(simpleHttpResponse, false, "htm");
    	assertEquals("utf-8", resp.charset());
    }

    public void testCharsetReturnsISO88591IfNoCharset(){
    	String s = "<html><head><meta http-equiv=\"zxz\"/></head>";
    	SimpleHttpResponse simpleHttpResponse = new SimpleHttpResponse(s);
    	simpleHttpResponse.removeHeader("Content-Type");
    	assertEquals(null, simpleHttpResponse.contentTypeHeader());
		HttpModifiedResponse resp = new HttpModifiedResponse(simpleHttpResponse, false, "htm");
    	assertEquals("iso-8859-1", resp.charset());
    }

    public void testCharsetReturnsISO88591IfBadCharset(){
    	String s = "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=xx\" /><meta http-equiv=\"zxz\"/></head>";
    	SimpleHttpResponse simpleHttpResponse = new SimpleHttpResponse(s);
    	simpleHttpResponse.removeHeader("Content-Type");
    	assertEquals(null, simpleHttpResponse.contentTypeHeader());
		HttpModifiedResponse resp = new HttpModifiedResponse(simpleHttpResponse, false, "htm");
    	assertEquals("iso-8859-1", resp.charset());
    }

    public void testCharsetReturnsCharsetWithSemiColonInHeader(){
    	String s = "<html><head><meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8;\" /><meta http-equiv=\"zxz\"/></head>";
    	SimpleHttpResponse simpleHttpResponse = new SimpleHttpResponse(s);
    	simpleHttpResponse.removeHeader("Content-Type");
    	assertEquals(null, simpleHttpResponse.contentTypeHeader());
		HttpModifiedResponse resp = new HttpModifiedResponse(simpleHttpResponse, false, "htm");
    	assertEquals("utf-8", resp.charset());
    }
    
    public void testNoCacheHeaderIsNotAddedToJavascriptResponses(){
    	// Javascript cache headers significantly slow down responses.
    	// Check http://sourceforge.net response times with and without NoCacheFilter on js.
    	String s = "var x = 10;\nvar y = x + 11;";
    	SimpleHttpResponse simpleHttpResponse = new SimpleHttpResponse(s);
    	simpleHttpResponse.removeHeader("Cache-Control");
    	assertEquals(null, simpleHttpResponse.headers().getHeader("Cache-Control"));
		HttpModifiedResponse resp = new HttpModifiedResponse(simpleHttpResponse, false, "js");
		List<StreamFilter> filters = resp.getFilters();
		for (Iterator<StreamFilter> iterator = filters.iterator(); iterator.hasNext();) {
			StreamFilter streamFilter = iterator.next();
			if (streamFilter instanceof NoCacheFilter) {
				fail("Should not have added NoCacheFilter");
			}
		}		
    }    
    
    public void testNoCacheHeaderIsAddedToHTMLResponses(){
    	String s = "<html><head></head></html>";
    	SimpleHttpResponse simpleHttpResponse = new SimpleHttpResponse(s);
		HttpModifiedResponse resp = new HttpModifiedResponse(simpleHttpResponse, false, "htm");
		List<StreamFilter> filters = resp.getFilters();
		for (Iterator<StreamFilter> iterator = filters.iterator(); iterator.hasNext();) {
			StreamFilter streamFilter = iterator.next();
			if (streamFilter instanceof NoCacheFilter) {
				return;
			}
		}
		fail("Should have added NoCacheFilter");
    } 
}
