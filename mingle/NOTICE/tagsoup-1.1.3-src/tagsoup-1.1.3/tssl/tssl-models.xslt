<!-- Generate Java code to be inserted into HTMLModels.java.  -->

<!--
// This file is part of TagSoup.
// 
// This program is free software; you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation; either version 2 of the License, or
// (at your option) any later version.  You may also distribute
// and/or modify it under version 3.0 of the Academic Free License.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  
-->

<xsl:transform xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
	xmlns:tssl="http://www.ccil.org/~cowan/XML/tagsoup/tssl"
	version="1.0">

  <xsl:output method="text"/>

  <xsl:strip-space elements="*"/>

  <!-- The main template.  We are going to generate Java constant
       definitions for the groups in the file.  -->
  <xsl:template match="tssl:schema">
    <xsl:apply-templates select="tssl:group">
      <xsl:sort select="@id"/>
    </xsl:apply-templates>
  </xsl:template>

  <!-- Generate a declaration for a single group.  -->
  <xsl:template match="tssl:group" name="tssl:group">
    <xsl:param name="id" select="@id"/>
    <xsl:param name="number" select="position()"/>
    <xsl:text>&#x9;public static final int </xsl:text>
    <xsl:value-of select="$id"/>
    <xsl:text> = 1 &lt;&lt; </xsl:text>
    <xsl:value-of select="$number"/>
    <xsl:text>;&#xA;</xsl:text>
  </xsl:template>

</xsl:transform>
