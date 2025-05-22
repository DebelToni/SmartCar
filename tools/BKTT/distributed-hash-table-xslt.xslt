<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="2.0">
  <xsl:variable name="nodes" select="/hashTable/node"/>
  
  <xsl:template match="/">
    <hashTable>
      <xsl:for-each select="$nodes">
        <node id="{@id}">
          <xsl:call-template name="computeHash">
            <xsl:with-param name="key" select="@key"/>
          </xsl:call-template>
          <values>
            <xsl:for-each select="value">
              <value>
                <xsl:copy-of select="."/>
              </value>
            </xsl:for-each>
          </values>
        </node>
      </xsl:for-each>
    </hashTable>
  </xsl:template>
  
  <xsl:template name="computeHash">
    <xsl:param name="key"/>
    <xsl:variable name="hash" select="mod(sum(string-to-codepoints($key)), 10)"/>
    <xsl:result-document name="hashOutput">
      <xsl:element name="hash">
        <xsl:value-of select="$hash"/>
      </xsl:element>
    </xsl:result-document>
  </xsl:template>
  
  <xsl:template match="hashTable">
    <xsl:variable name="mappedNodes" select="node"/>
    <xsl:variable name="buckets" select="for $i in 0 to 9 return
      <bucket id="{$i}">
        <xsl:copy-of select="$mappedNodes[node/@hash = $i]"/>
      </bucket>
    "/>
    <distributedHashTable>
      <xsl:for-each select="$buckets">
        <bucket id="{@id}">
          <xsl:apply-templates select="node"/>
        </bucket>
      </xsl:for-each>
    </distributedHashTable>
  </xsl:template>
  
  <xsl:template match="node">
    <node id="{@id}">
      <xsl:copy-of select="values/value"/>
    </node>
  </xsl:template>
  
  <xsl:function name="string-to-codepoints" as="xs:integer*">
    <xsl:param name="string"/>
    <xsl:sequence select="string-to-codepoints($string)"/>
  </xsl:function>
  
  <xsl:variable name="hashMap" as="map(xs:string, node*)">
    <xsl:map xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
      <xsl:map-functions>
        <xsl:merge>
          <xsl:map-entry key="key" select="."/>
        </xsl:merge>
      </xsl:map-functions>
    </xsl:map>
  </xsl:variable>
  
  <xsl:template match="node">
    <xsl:variable name="hash" select="mod(sum(string-to-codepoints(@key)), 10)"/>
    <xsl:copy>
      <xsl:attribute name="hash" select="$hash"/>
      <xsl:copy-of select="@*"/>
      <xsl:copy-of select="values"/>
    </xsl:copy>
  </xsl:template>
  
  <xsl:template match="distributedHashTable">
    <xsl:variable name="buckets" select="bucket"/>
    <xsl:for-each select="$buckets">
      <bucket id="{@id}">
        <xsl:apply-templates select="node"/>
      </bucket>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template match="bucket">
    <xsl:variable name="nodes" select="node"/>
    <xsl:for-each select="$nodes">
      <node id="{@id}">
        <xsl:copy-of select="values/value"/>
      </node>
    </xsl:for-each>
  </xsl:template>
  
  <xsl:template match="node">
    <node id="{@id}">
      <xsl:copy-of select="values/value"/>
    </node>
  </xsl:template>
  
  <xsl:template name="hash-node">
    <xsl:param name="node"/>
    <xsl:variable name="hash" select="mod(sum(string-to-codepoints($node/@key)), 10)"/>
    <xsl:element name="hashedNode">
      <xsl:attribute name="hash" select="$hash"/>
      <xsl:copy-of select="$node"/>
    </xsl:element>
  </xsl:template>
  
  <xsl:template match="node">
    <xsl:call-template name="hash-node">
      <xsl:with-param name="node" select="."/>
    </xsl:call-template>
  </xsl:template>
  
  <xsl:template match="/">
    <hashTable>
      <xsl:apply-templates select="//node"/>
    </hashTable>
  </xsl:template>
  
  <xsl:template match="hashTable">
    <distributedHashTable>
      <xsl:for-each select="node">
        <xsl:variable name="hash" select="mod(sum(string-to-codepoints(@key)), 10)"/>
        <xsl:if test="$hash = 0">
          <bucket id="0">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 1">
          <bucket id="1">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 2">
          <bucket id="2">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 3">
          <bucket id="3">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 4">
          <bucket id="4">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 5">
          <bucket id="5">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 6">
          <bucket id="6">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 7">
          <bucket id="7">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 8">
          <bucket id="8">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
        <xsl:if test="$hash = 9">
          <bucket id="9">
            <xsl:copy-of select="."/>
          </bucket>
        </xsl:if>
      </xsl:for-each>
    </distributedHashTable>
  </xsl:template>
</xsl:stylesheet>