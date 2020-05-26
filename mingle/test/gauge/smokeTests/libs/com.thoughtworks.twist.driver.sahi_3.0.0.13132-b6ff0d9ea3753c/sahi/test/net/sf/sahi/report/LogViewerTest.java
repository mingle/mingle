package net.sf.sahi.report;

import junit.framework.TestCase;
import net.sf.sahi.config.Configuration;
import net.sf.sahi.util.Utils;

import java.io.File;
import java.io.IOException;

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
 * Date: Dec 8, 2006
 * Time: 5:02:01 PM
 */
public class LogViewerTest extends TestCase {
	private static final long serialVersionUID = 6044194475810086560L;

	static {
		Configuration.init();
	}
	
    private File dir = new File(Configuration.getPlayBackLogsRoot() + System.getProperty("file.separator") + "junit");


    protected void setUp() throws Exception {
        super.setUp();
        Utils.deleteDir(dir);
        dir.mkdirs();
    }

    public void testGetLogsList() throws IOException, InterruptedException {
        new File(dir, "log3.htm").createNewFile();
        new File(dir, "log2.htm").createNewFile();
        new File(dir, "dummy.txt").createNewFile();
        Thread.sleep(100);
        File subDir = new File(dir, "subDir");
        subDir.mkdirs();
        new File(subDir, "blah.htm").createNewFile();

        String expected1 = "<a href='/_s_/dyn/Log_viewLogs/subDir/index.htm'>subDir</a><br>";
        String expected2 = "<a href='/_s_/dyn/Log_viewLogs/log2.htm'>log2.htm</a><br>";
        String expected3 = "<a href='/_s_/dyn/Log_viewLogs/log3.htm'>log3.htm</a><br>";
        String actual = LogViewer.getLogsList(dir.getAbsolutePath());
        assertTrue(actual.indexOf(expected1)!=1);
        assertTrue(actual.indexOf(expected2)!=1);
        assertTrue(actual.indexOf(expected3)!=1);
    }

    public void testHighlightLine() {
        assertEquals("<span>1</span> <a name='selected'><b>one</b></a>\n<span>2</span> two\n<span>3</span> three\n<span>4</span> four\n", LogViewer.highlightLine("one\ntwo\nthree\r\nfour", 1));
        assertEquals("<span>1</span> one\n<span>2</span> <a name='selected'><b>two</b></a>\n<span>3</span> three\n<span>4</span> four\n", LogViewer.highlightLine("one\ntwo\nthree\nfour", 2));
        assertEquals("<span>1</span> one\n<span>2</span> two\n<span>3</span> three\n<span>4</span> <a name='selected'><b>four</b></a>\n", LogViewer.highlightLine("one\ntwo\nthree\nfour", 4));
        assertEquals("<span>1</span> one\n<span>2</span> two\n<span>3</span> three\n<span>4</span> four\n", LogViewer.highlightLine("one\ntwo\nthree\nfour", -1));
        assertEquals("<span>1</span> one\n<span>2</span> two\n<span>3</span> three\n<span>4</span> four\n", LogViewer.highlightLine("one\ntwo\nthree\nfour", 0));
    }

    public void testHighlight() {
        String data = "test";
        assertEquals("<html><head><meta http-equiv=\"content-type\" content=\"text/html; charset=UTF-8\" /></head><body><style>b{background:brown;color:white;}\nspan{background:lightgrey;}</style><pre><span>1</span> test\n</pre></body></html>", LogViewer.highlight(data, -1));
    }
}
