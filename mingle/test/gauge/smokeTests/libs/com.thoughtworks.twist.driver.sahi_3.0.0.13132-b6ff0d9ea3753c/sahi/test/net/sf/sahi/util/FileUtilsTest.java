package net.sf.sahi.util;

import junit.framework.TestCase;

import java.io.IOException;
import java.io.File;
import java.io.FileOutputStream;

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

public class FileUtilsTest extends TestCase {
	private static final long serialVersionUID = 4433222425549723764L;
	String src = "../temp/copysrc/";
    String dest = "../temp/copydest/";
    String file1 = "a.txt";
    String file2 = "nested/b.txt";
    public String content = "Some text";


    protected void setUp() throws Exception {
        new File(src).mkdirs();
        new File(src+"nested").mkdirs();

        new File(src+file1).createNewFile();
        new File(src+file2).createNewFile();

        File srcFile = new File(src + file1);
        srcFile.createNewFile();

        FileOutputStream out = new FileOutputStream(srcFile);
        out.write(content.getBytes());
        out.close();
    }

    public void testCopyDir() throws IOException, InterruptedException {
        FileUtils.copyDir(src, dest);
        assertTrue(new File(dest + file1).exists());
        assertTrue(new File(dest + file2).exists());

    }


    public void testCopyFile() throws IOException {
        String destFile = dest + file1;
        FileUtils.copyFile(src+file1, destFile);
        assertTrue(new File(destFile).exists());
        assertEquals(content, new String(Utils.readFileAsString(destFile)));
    }


    protected void tearDown() throws Exception {
        new File(src+file1).delete();
        new File(src+file2).delete();
        new File(dest+file1).delete();
        new File(dest+file2).delete();

        new File(src+"/nested").delete();
        new File(src).delete();
        new File(dest+"/nested").delete();
        new File(dest).delete();
    }

    public void testCleanFileName() throws IOException {
        assertEquals("abcdefghijk", FileUtils.cleanFileName("a\\b/c:d*e?f\"g<h>i|jk"));
        String fileName = null;
        assertNull(FileUtils.cleanFileName(fileName));
    }

}
