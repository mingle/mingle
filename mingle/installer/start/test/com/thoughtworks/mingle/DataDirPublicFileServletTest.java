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

import javax.servlet.ServletOutputStream;
import javax.servlet.WriteListener;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.io.IOException;

import static junit.framework.Assert.assertFalse;
import static junit.framework.Assert.assertTrue;
import static org.mockito.Mockito.*;

public class DataDirPublicFileServletTest {

    @Test
    public void isDataDirPublicFileRequest() {
        assertTrue("should match", DataDirPublicFileServlet.isDataDirPublicFileRequest("/project/icon/123"));
        assertTrue("should match", DataDirPublicFileServlet.isDataDirPublicFileRequest("/user/icon/123"));
        assertTrue("should match", DataDirPublicFileServlet.isDataDirPublicFileRequest("/attachments/3f172cf77f7d3d860209a3d3cb07fac0/33/Screen.png"));
        assertTrue("should match", DataDirPublicFileServlet.isDataDirPublicFileRequest("/attachments_3/3f172cf77f7d3d860209a3d3cb07fac0/33/Screen.png"));

        assertFalse("should not match", DataDirPublicFileServlet.isDataDirPublicFileRequest("/projects/project"));
        assertFalse("should not match", DataDirPublicFileServlet.isDataDirPublicFileRequest("users/project"));
    }

    @Test
    public void willAddContentDispositionForDownload() throws Exception {
        DataDirPublicFileServlet servlet = new DataDirPublicFileServlet();
        File publicDir = new File("test/data");
        servlet.setPublicDir(publicDir);

        HttpServletRequest request;
        HttpServletResponse response;

        request = mockRequest("sample_attachment.txt", "download=yes");
        response = mockResponse();
        servlet.serveResource(request, response);

        verify(response).setHeader("Content-Disposition", "attachment; filename=\"sample_attachment.txt\"");

        request = mockRequest("sample_attachment.txt");
        response = mockResponse();
        servlet.serveResource(request, response);

        verify(response, never()).setHeader("Content-Disposition", "attachment; filename=\"sample_attachment.txt\"");
    }

    @Test
    public void willOnlyServeFilesInDataDir() throws Exception {
        DataDirPublicFileServlet servlet = new DataDirPublicFileServlet();
        File publicDir = new File("test/data");
        servlet.setPublicDir(publicDir);

        HttpServletRequest request;
        HttpServletResponse response;

        request = mockRequest("sample_attachment.txt");
        response = mockResponse();
        servlet.serveResource(request, response);

        verify(response).getOutputStream();
        verify(response, never()).setStatus(404);

        String fileOutsidePublicDir = "../../config/environment.rb";
        assertTrue(new File(publicDir, fileOutsidePublicDir).exists());

        request = mockRequest(fileOutsidePublicDir);
        response = mockResponse();
        servlet.serveResource(request, response);
        verify(response, never()).getOutputStream();
        verify(response).setStatus(404);

        request = mockRequest("icons");
        response = mockResponse();
        // directory should not be served
        servlet.serveResource(request, response);
        verify(response, never()).getOutputStream();
        verify(response).setStatus(404);
    }

    private HttpServletRequest mockRequest(String path) throws IOException {
        return mockRequest(path, "");
    }

    private HttpServletRequest mockRequest(String path, String query) throws IOException {
        HttpServletRequest request = mock(HttpServletRequest.class);
        stub(request.getRequestURI()).toReturn(path);
        stub(request.getContextPath()).toReturn("/");
        stub(request.getQueryString()).toReturn(query);

        return request;
    }

    private HttpServletResponse mockResponse() throws IOException {
        HttpServletResponse response = mock(HttpServletResponse.class);
        when(response.getOutputStream()).thenReturn(new ServletOutputStream() {
            public boolean isReady() {
                return true;
            }

            public void setWriteListener(WriteListener writeListener) {

            }

            public void write(int i) throws IOException {
            }
        });

        return response;
    }
}
