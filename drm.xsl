<xsl:stylesheet version="1.0" 
		xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
		xmlns:h="http://www.w3.org/1999/xhtml"
		xmlns="http://www.w3.org/1999/xhtml"
		exclude-result-prefixes="h">

<xsl:output method="xml"
            encoding="UTF-8"/>
<xsl:preserve-space elements="*"/>

<xsl:param name="drmnotice">
    <section data-type="preface" class="drm">
        <h1 class="Nonprinting">Copyright Notice</h1>
        <p class="CopyrightTextsinglespacecrtx">The author and publisher have provided this e-book to you without Digital Rights Management software (DRM) applied so that you can enjoy reading it on your personal devices. This e-book is for your personal use only. You may not print or post this e-book, or make this e-book publicly available in any way. You may not copy, reproduce or upload this e-book, other than to read it on one of your personal devices.</p>
        <p class="CopyrightTextsinglespacecrtx"><strong>Copyright infringement is against the law. If you believe the copy of this e-book you are reading infringes on the author’s copyright, please notify the publisher at: <a href="http://us.macmillanusa.com/piracy">http://us.macmillanusa.com/piracy</a>.</strong></p>    
    </section>
 </xsl:param>

<xsl:template match="node()|@*" name="identity">
     <xsl:copy>
       <xsl:apply-templates select="node()|@*"/>
     </xsl:copy>
 </xsl:template>

<xsl:template match="h:section[@data-type='titlepage'][last()]">
	<xsl:call-template name="identity"/>
  	<xsl:copy-of select="$drmnotice"/>
</xsl:template>

</xsl:stylesheet> 