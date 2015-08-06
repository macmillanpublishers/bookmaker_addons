<xsl:stylesheet version="1.0" 
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:h="http://www.w3.org/1999/xhtml"
		xmlns="http://www.w3.org/1999/xhtml"
		exclude-result-prefixes="h">

<xsl:output method="xml"
            encoding="UTF-8"/>
<xsl:preserve-space elements="*"/>

<xsl:param name="notice">
        <p class="CopyrightTextsinglespacecrtx">Our eBooks may be purchased in bulk for promotional, educational, or business use. Please contact the Macmillan Corporate and Premium Sales Department at 1-800-221-7945, ext. 5442, or by e-mail at <a href="mailto:MacmillanSpecialMarkets@macmillan.com">MacmillanSpecialMarkets@macmillan.com</a>.</p>    
 </xsl:param>

<xsl:template match="node()|@*" name="identity">
     <xsl:copy>
       <xsl:apply-templates select="node()|@*"/>
     </xsl:copy>
 </xsl:template>

<xsl:template match="h:section[@data-type='copyright-page']/h:p[last()]">
	<xsl:call-template name="identity"/>
  	<xsl:copy-of select="$notice"/>
</xsl:template>

</xsl:stylesheet> 