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

import javax.servlet.ServletContext;
import java.io.File;

/**
 * abstracts public.root and rails.root path resolution
 */
public class RailsPathHelper {
    private ServletContext context;
    private String publicRoot;
    private String railsRoot;

    public RailsPathHelper(ServletContext context) {
        this.context = context;
        this.publicRoot = context.getInitParameter("public.root");
        this.railsRoot = context.getInitParameter("rails.root");
    }

    public String publicRealPath(String path) {
        return context.getRealPath(combine(publicRoot, path).replace(File.separatorChar, '/'));
    }

    public String railsRealPath(String path) {
        return context.getRealPath(combine(railsRoot, path).replace(File.separatorChar, '/'));
    }

    private String combine(String path1, String path2) {
        File file1 = new File(path1);
        return new File(file1, path2).getPath();
    }
}
