<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
  <xsl:output method="xml" indent="yes"/>

  <xsl:variable name="meta-registry">
    <entry name="Person">
      <field name="name" type="string"/>
      <field name="age" type="integer"/>
      <field name="address" type="Address"/>
    </entry>
    <entry name="Address">
      <field name="street" type="string"/>
      <field name="city" type="string"/>
      <field name="zip" type="string"/>
    </entry>
    <entry name="Department">
      <field name="deptName" type="string"/>
      <field name="manager" type="Person"/>
      <field name="employees" type="Person" multiple="true"/>
    </entry>
  </xsl:variable>

  <xsl:function name="meta:get-entry" as="element()">
    <xsl:param name="name" as="xs:string"/>
    <xsl:for-each select="$meta-registry/entry[@name=$name]">
      <xsl:if test="."">
        <xsl:copy/>
      </xsl:if>
    </xsl:for-each>
  </xsl:function>

  <xsl:template match="/">
    <xsl:apply-templates select="root"/>
  </xsl:template>

  <xsl:template match="root">
    <xsl:variable name="type" select="@type"/>
    <xsl:variable name="meta" select="meta:get-entry($type)"/>
    <xsl:variable name="data" select="."/>
    <xsl:call-template name="generate-element">
      <xsl:with-param name="meta" select="$meta"/>
      <xsl:with-param name="data" select="$data"/>
      <xsl:with-param name="name" select="$type"/>
    </xsl:call-template>
  </xsl:template>

  <xsl:template name="generate-element">
    <xsl:param name="meta"/>
    <xsl:param name="data"/>
    <xsl:param name="name"/>
    <xsl:element name="{$name}">
      <xsl:for-each select="$meta/field">
        <xsl:variable name="fieldName" select="@name"/>
        <xsl:variable name="fieldType" select="@type"/>
        <xsl:variable name="multiple" select="@multiple"/>
        <xsl:choose>
          <xsl:when test="$multiple='true'">
            <xsl:for-each select="$data/*[local-name()=$fieldName]/*">
              <xsl:call-template name="generate-field">
                <xsl:with-param name="fieldMeta" select="$meta/field[@name=$fieldName]"/>
                <xsl:with-param name="fieldData" select="."/>
                <xsl:with-param name="fieldName" select="$fieldName"/>
              </xsl:call-template>
            </xsl:for-each>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="generate-field">
              <xsl:with-param name="fieldMeta" select="$meta/field[@name=$fieldName]"/>
              <xsl:with-param name="fieldData" select="$data/*[local-name()=$fieldName]"/>
              <xsl:with-param name="fieldName" select="$fieldName"/>
            </xsl:call-template>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:for-each>
    </xsl:element>
  </xsl:template>

  <xsl:template name="generate-field">
    <xsl:param name="fieldMeta"/>
    <xsl:param name="fieldData"/>
    <xsl:param name="fieldName"/>
    <xsl:choose>
      <xsl:when test="$fieldMeta/@type='string' or $fieldMeta/@type='integer'">
        <xsl:element name="{$fieldName}">
          <xsl:if test="$fieldData">
            <xsl:value-of select="$fieldData"/>
          </xsl:if>
        </xsl:element>
      </xsl:when>
      <xsl:when test="$fieldMeta/@type">
        <xsl:variable name="type" select="$fieldMeta/@type"/>
        <xsl:choose>
          <xsl:when test="$type='Address'">
            <xsl:call-template name="generate-element">
              <xsl:with-param name="meta" select="meta:get-entry('Address')"/>
              <xsl:with-param name="data" select="$fieldData"/>
              <xsl:with-param name="name" select="Address"/>
            </xsl:call-template>
          </xsl:when>
          <xsl:otherwise>
            <xsl:element name="{$fieldName}">
              <xsl:if test="$fieldData">
                <xsl:value-of select="$fieldData"/>
              </xsl:if>
            </xsl:element>
          </xsl:otherwise>
        </xsl:choose>
      </xsl:when>
      <xsl:otherwise>
        <xsl:element name="{$fieldName}">
          <xsl:if test="$fieldData">
            <xsl:value-of select="$fieldData"/>
          </xsl:if>
        </xsl:element>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <xsl:template match="*">
    <xsl:call-template name="generate-element">
      <xsl:with-param name="meta" select="meta:get-entry(name())"/>
      <xsl:with-param name="data" select="."/>
      <xsl:with-param name="name" select="name()"/>
    </xsl:call-template>
  </xsl:template>
</xsl:stylesheet>