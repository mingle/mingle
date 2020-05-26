<!-- Generate complaints if the schema is invalid in some way.  -->

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

  <!-- Generates a report if an element does not belong to at least
       one of the groups that its parent element contains.  -->
  <xsl:template match="tssl:element/tssl:element">
    <xsl:if test="not(tssl:memberOfAny) and not(tssl:memberOf/@group = ../tssl:contains/@group)">
      <xsl:value-of select="@name"/>
      <xsl:text> is not in the content model of </xsl:text>
      <xsl:value-of select="../@name"/>
      <xsl:text>&#xA;</xsl:text>
    </xsl:if>
    <xsl:apply-templates/>
  </xsl:template>



</xsl:transform>
