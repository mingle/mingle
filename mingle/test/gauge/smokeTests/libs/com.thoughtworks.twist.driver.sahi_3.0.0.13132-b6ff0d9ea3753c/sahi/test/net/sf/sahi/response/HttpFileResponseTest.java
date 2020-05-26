package net.sf.sahi.response;

import junit.framework.TestCase;

import java.util.Date;
import java.util.GregorianCalendar;
import java.util.Properties;
import java.util.TimeZone;

import net.sf.sahi.util.Utils;

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
 * User: nraman Date: May 15, 2005 Time: 10:14:34 PM
 */
public class HttpFileResponseTest extends TestCase {
	private static final long serialVersionUID = -4093505712461135994L;

	public void testSubstitute() {
        Properties props = new Properties();
        props.setProperty("isRecording", "true");
        props.setProperty("isPlaying", "false");
        props.setProperty("sessionId", "sahi_1281210");
        String template = " var isRecording=$isRecording;\n var isPlaying=$isPlaying;\n setCookie('$sessionId')";
        assertEquals(
                " var isRecording=true;\n var isPlaying=false;\n setCookie('sahi_1281210')",
                Utils.substitute(template, props));
    }

    public void testSubstituteWorksWhenTheReplacedTextHasDollarInIt() {
        Properties props = new Properties();
        props.setProperty("sessionId", "$sahi_1281210");
        String template = "setCookie('$sessionId')";
        assertEquals(
                "setCookie('$sahi_1281210')",
                Utils.substitute(template, props));
    }

    public void testFormatForExpiresHeader() {
        Date date = new GregorianCalendar(2001, 4, 5).getTime();

        assertEquals("Sat, 05 May 2001 12:00:00 " + getTimeZone(date), HttpFileResponse.formatForExpiresHeader(date));
    }

    private String getTimeZone(Date date) {
        return TimeZone.getDefault().getDisplayName(TimeZone.getDefault().inDaylightTime(date), TimeZone.SHORT);
    }
}
