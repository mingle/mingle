#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

require "itext-2.1.7.jar"
require "tagsoup-1.1.3.jar"
require "java"

module PdfGenerator
  java_import 'org.xhtmlrenderer.pdf.ITextRenderer'
  java_import 'org.ccil.cowan.tagsoup.CommandLine'

  def create_pdf(html, output)
    html_file = RailsTmpDir::PdfExport.file.pathname
    xhtml_file = html_file.gsub(/\.html$/, '.xhtml')
    FileUtils.mkdir_p(File.dirname(html_file))
    File.open(html_file, 'w') do |f|
      f.puts html
    end

    begin
      # redirect stdout to xhtml file
      java.lang.System.setOut(java.io.PrintStream.new(xhtml_file))

      # convert to xhtml using tagsoup
      # encoding the output format as US-ASCII seems odd but forces all characters > 127 to be output as HTML entities
      # this solves the issue where HTML entities were getting converted to the actual byte values
      CommandLine.main(["--encoding=utf-8", "--output-encoding=us-ascii", "file:///" + html_file].to_java(:string))

      result = xhtml_to_pdf(xhtml_file, output)
    ensure
      FileUtils.rm_rf([html_file, xhtml_file]) rescue nil
    end
    result
  end


  def xhtml_to_pdf(path, io)
    url = java.io.File.new(path).toURI().toURL().toString()
    stream = org.jruby.util.IOOutputStream.new(io)
    renderer = ITextRenderer.new

    renderer.setDocument(url)
    renderer.layout
    renderer.createPDF(stream)
  end

  module_function :create_pdf, :xhtml_to_pdf
end
