/*
*  Copyright 2020 ThoughtWorks, Inc.
*  
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*  
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*  
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/

package com.thoughtworks.mingle;

import org.junit.Test;

import java.io.BufferedWriter;
import java.io.File;
import java.io.FileWriter;
import java.io.IOException;
import java.util.Date;

import static org.junit.Assert.assertEquals;

public class SimpleTemplateTest {

    public void setup() throws IOException {

    }

    @Test
    public void testWithoutAssignsShouldRenderOriginalContent() throws IOException {
        SimpleTemplate template = createTemplate("say: {% word %}");
        assertEquals("say: {% word %}", template.render());
    }

    @Test
    public void testShouldReplaceAssignsWithValues() throws IOException {
        SimpleTemplate template = createTemplate("say: {% word %}");
        template.assign("word", "hello");
        assertEquals("say: hello", template.render());
    }

    private SimpleTemplate createTemplate(String content) throws IOException {
        File templateFile = createTempFile(Long.toString(new Date().getTime()), content);
        return new SimpleTemplate(templateFile.getAbsolutePath());
    }

    private File createTempFile(String baseName, String content) throws IOException {
        File tempFile = File.createTempFile(baseName, ".jst");
        tempFile.deleteOnExit();
        BufferedWriter out = new BufferedWriter(new FileWriter(tempFile));
        out.write(content);
        out.close();
        return tempFile;
    }

}
