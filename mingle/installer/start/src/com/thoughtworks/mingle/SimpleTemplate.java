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

import java.io.File;
import java.io.FileReader;
import java.io.IOException;
import java.util.ArrayList;

public class SimpleTemplate {
    private ArrayList<Assign> assigns;
    private String templatePath;

    private static class Assign {
        private String variable;
        private String value;

        public Assign(String variable, String value) {
            this.variable = variable;
            this.value = value;
        }

        public String sub(String content) {
            String regex = new StringBuilder().append("\\{\\%\\s*").append(variable).append("\\s*\\%\\}").toString();
            return content.replaceAll(regex, value == null ? "" : value);
        }
    }

    public SimpleTemplate(String templatePath) throws IOException {
        this.templatePath = templatePath;
        this.assigns = new ArrayList<Assign>();
    }

    private String readFile(String path) throws IOException {
        File file = new File(path);
        FileReader fileReader = new FileReader(file);
        char[] buffer = new char[(int) file.length()];
        fileReader.read(buffer);
        return new String(buffer);
    }

    public void assign(String variable, String value) {
        this.assigns.add(new Assign(variable, value));
    }

    public String render() throws IOException {
        String content = readFile(templatePath);
        for (Assign assign : assigns) {
            content = assign.sub(content);
        }
        return content;
    }
}

