<?xml version="1.0"?>
<!-- SQLite output. C.SUDRE (cyril.sudre@edf.fr) -->

<!DOCTYPE stylesheet [
<!ENTITY newline "<![CDATA[&#xa;]]>">
<!ENTITY tab "<![CDATA[&#9;]]>">
]>

<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
	<xsl:output method="text"/>

	<!--
    Add extra triggers to enforce integrity
    See http://justatheory.com/computers/databases/sqlite/
    -->
    <xsl:param name="ENFORCE_INTEGRITY_CONSTRAINTS" select="1"/>
    
    <!-- root -->
	<xsl:template match="/sql">
		<xsl:text>BEGIN TRANSACTION;&newline;&newline;</xsl:text>

		<!-- tables -->
		<xsl:apply-templates select="table"/>
		
		<!-- Add integrity triggers -->
        <xsl:if test="$ENFORCE_INTEGRITY_CONSTRAINTS = 1">
            <xsl:apply-templates select="//relation" mode="integrity-triggers"/>
        </xsl:if>

		<xsl:text>COMMIT TRANSACTION;</xsl:text>
	</xsl:template>

	<!-- tables -->
	<xsl:template match="table">
		<!-- Comments above table sql statement -->
		<xsl:apply-templates select="comment"/>

		<!-- open table sql statement -->
		<xsl:text>CREATE TABLE </xsl:text>
		<xsl:value-of select="@name"/>
		<xsl:text> (&newline;</xsl:text>
		
		<!-- Number of field(s) for primary key -->
		<xsl:variable name="nb_pkey_fields" select="count(key[@type = 'PRIMARY'])"/>
		
		<xsl:choose>
			<!-- Primary key is composed of a unique field for this table. In this case, key constraint is column-based -->
			<xsl:when test="$nb_pkey_fields = 1">
				<xsl:apply-templates select="row">
					<!-- Apply template with "pkey_name" param to treat PRIMARY KEY specific -->
					<xsl:with-param name="pkey_name" select="key[@type = 'PRIMARY']/part"/>
				</xsl:apply-templates>
			</xsl:when>

			<!-- Composite key (or no primary key at all!?). In this case, key constraint is table-based -->
			<xsl:otherwise>
				<xsl:apply-templates select="row"/>
			</xsl:otherwise>
		</xsl:choose>

		<!-- Apply templates for table-constraints : PRIMARY KEY, UNIQUE, FOREIGN -->
		<!-- TODO : CHECK -->
		<xsl:apply-templates select="key" mode="table-constraint"/>

		<!-- Add foreign keys constraint as sqlite support this... -->
		<xsl:apply-templates select="row/relation" mode="table-constraint"/>

		<!-- close table sql statement -->
		<xsl:text>&newline;);&newline;&newline;</xsl:text>

		<!-- indexes on this table -->
		<xsl:apply-templates select="key" mode="table-index"/>

	</xsl:template>


	<!-- Match <row> -->
	<xsl:template match="row">

		<!-- Is there a composite key or not? If one field for primary key, it's in pkey param -->
		<xsl:param name="pkey_name" select="''"/>

		<!-- pretty print of create statement... -->
		<xsl:text>&tab;</xsl:text>

		<!-- field name -->
		<xsl:value-of select="@name"/>
		<xsl:text> </xsl:text>

		<!-- field type -->
		<xsl:value-of select="datatype"/>

		<xsl:choose>
			<!-- If only one key, make it primary key on column constraint -->
			<xsl:when test="@name = $pkey_name">
				<xsl:text> PRIMARY KEY</xsl:text>

				<!-- AUTOINCREMENT for this key? See http://www.sqlite.org/lang_createtable.html-->
				<xsl:if test="datatype = 'INTEGER' and @autoincrement = 1">
					<xsl:text> AUTOINCREMENT</xsl:text>
				</xsl:if>
			</xsl:when>

			<!-- PRIMARY KEY do not need this constraints (implicit) -->
			<xsl:otherwise>
				<!-- NOT NULL constraint -->
				<xsl:if test="@null = 0">
					<xsl:text> NOT NULL</xsl:text>
				</xsl:if>

				<!-- DEFAULT constraint -->
				<xsl:if test="default">
					<xsl:text> DEFAULT </xsl:text>
					<xsl:value-of select="default"/>
				</xsl:if>
			</xsl:otherwise>
		</xsl:choose>

		<!-- Continue declare? -->
		<xsl:if test="not (position()=last())">
			<xsl:text>,&newline;</xsl:text>
		</xsl:if>
	</xsl:template>


	<!-- Treat key constraints on table basis -->
	<!-- PRIMARY KEY, UNIQUE, CHECK , FOREIGN -->
	<!-- + foreign key clause -->
	<!-- http://www.sqlite.org/lang_createtable.html -->
	<xsl:template match="key" mode="table-constraint">
		<xsl:if test="(@type = 'PRIMARY' and count(part) &gt; 1) or @type = 'UNIQUE'">

			<!-- pretty print -->
			<xsl:text>,&newline;</xsl:text>			

			<xsl:choose>
				<xsl:when test="@type = 'PRIMARY'">&tab;PRIMARY KEY(</xsl:when>
				<xsl:when test="@type = 'UNIQUE'">&tab;UNIQUE(</xsl:when>
			</xsl:choose>
			<xsl:for-each select="part">
				<xsl:value-of select="."/>

				<!-- Last <part> node? -->
				<xsl:if test="not (position() = last())">
					<xsl:text>,</xsl:text>
				</xsl:if>
			</xsl:for-each>
			<xsl:text>)</xsl:text>
		</xsl:if>
	</xsl:template>

	<!-- Table indexes -->
	<xsl:template match="key" mode="table-index">
		<xsl:if test="@type = 'INDEX'">
			<!-- index MUST have a name -->
			<xsl:if test="@name != ''">
				<xsl:text>CREATE INDEX </xsl:text>
				<xsl:value-of select="@name"/>
				<xsl:text> ON </xsl:text>
				<xsl:value-of select="../@name"/>
				<!-- to get table name : key node is child of table node -->
				<xsl:text>(</xsl:text>

				<xsl:for-each select="part">
					<xsl:value-of select="."/>
					<xsl:if test="not (position() = last())">
						<xsl:text>,</xsl:text>
					</xsl:if>
				</xsl:for-each>
				<xsl:text>);&newline;&newline;</xsl:text>
			</xsl:if>
		</xsl:if>
	</xsl:template>

	<!-- foreign keys relations as constraint on table -->
	<!-- http://www.sqlite.org/lang_createtable.html -->
	<xsl:template match="relation" mode="table-constraint">
		<!-- pretty print -->
		<xsl:text>,&newline;</xsl:text>			

		<xsl:text>&tab;CONSTRAINT </xsl:text>
		<xsl:value-of select="../@name"/>	<!-- row name -->
		<xsl:text> FOREIGN KEY(</xsl:text>
		<xsl:value-of select="../@name"/>
		<xsl:text>) REFERENCES </xsl:text>
		<xsl:value-of select="@table"/>
		<xsl:text>(</xsl:text>
		<xsl:value-of select="@row"/>
		<xsl:text>)</xsl:text>
	</xsl:template>
    
    <xsl:template match="relation" mode="integrity-triggers">
        <!-- trigger BEFORE INSERT -->
		<xsl:call-template name="trigger_insert_update">
            <xsl:with-param name="null_accepted" select="../@null"/>
			<xsl:with-param name="trigger_type" select="'INSERT'"/>
			<xsl:with-param name="modified_table" select="../../@name"/>
            <xsl:with-param name="referenced_table" select="@table"/>
            <xsl:with-param name="fk" select="../@name"/>
            <xsl:with-param name="k" select="@row"/>
        </xsl:call-template>
		
		<!-- trigger BEFORE UPDATE -->
		<xsl:call-template name="trigger_insert_update">
			<xsl:with-param name="null_accepted" select="../@null"/>
			<xsl:with-param name="trigger_type" select="'UPDATE'"/>
            <xsl:with-param name="modified_table" select="../../@name"/>
            <xsl:with-param name="referenced_table" select="@table"/>
            <xsl:with-param name="fk" select="../@name"/>
            <xsl:with-param name="k" select="@row"/>
        </xsl:call-template>
		
		<!-- trigger BEFORE DELETE -->
		<xsl:call-template name="trigger_delete">
            <xsl:with-param name="delete_table" select="../../@name"/>
			<xsl:with-param name="delete_cascade" select="0"/>
            <xsl:with-param name="referenced_table" select="@table"/>
            <xsl:with-param name="fk" select="../@name"/>
            <xsl:with-param name="k" select="@row"/>
        </xsl:call-template>
     </xsl:template>
    

	<!-- Display comments above table create statement -->
	<xsl:template match="comment">
		<xsl:text>/*&newline;</xsl:text>
		<xsl:value-of select="."/>
		<xsl:text>&newline;</xsl:text>
		<xsl:text>*/&newline;</xsl:text>
	</xsl:template>
	
	
	<!-- Add TRIGGER to enforce integrity on INSERT /UPDATE -->
	<xsl:template name="trigger_insert_update">
		<!-- The table we want to insert/update into -->
        <xsl:param name="modified_table"/>
		
		<!-- INSERT or UPDATE trigger? -->
        <xsl:param name="trigger_type"/>
		
        <!-- The table referenced by foreign key -->
        <xsl:param name="referenced_table"/>
        
        <!-- foreign key name for table we are inserting in -->
		<xsl:param name="fk"/>
        
		<!-- primary key name for referenced table -->
        <xsl:param name="k"/>
        
        <!-- Is NULL permitted with foreign key? -->
        <xsl:param name="null_accepted"/>
	
		<!-- fki_ or fku_ prefix for trigger name -->
		<xsl:text>CREATE TRIGGER fk</xsl:text>
		<xsl:choose>
			<xsl:when test="$trigger_type = 'INSERT'"><xsl:text>i</xsl:text></xsl:when>
			<xsl:when test="$trigger_type = 'UPDATE'"><xsl:text>u</xsl:text></xsl:when>
		</xsl:choose>
		<xsl:text>_</xsl:text>
		
		<xsl:value-of select="$modified_table"/>
        <xsl:text>_</xsl:text>
        <xsl:value-of select="$fk"/>

		<xsl:text> BEFORE </xsl:text>
		<xsl:value-of select="$trigger_type"/>	<!-- before INSERT or UPDATE? -->
		<xsl:text> ON </xsl:text>

        <xsl:value-of select="$modified_table"/>
		<xsl:text>&newline;FOR EACH ROW BEGIN&newline;&tab;SELECT CASE&newline;&tab;&tab;</xsl:text>
     	<xsl:text>WHEN ((</xsl:text>
        
        <!-- Extra test if NULL values accepted for foreign key -->
        <xsl:if test="$null_accepted = 1">
            <xsl:text>new.</xsl:text>
            <xsl:value-of select="$fk"/>
            <xsl:text> IS NOT NULL) AND (</xsl:text>
        </xsl:if>
        
		<xsl:text>SELECT </xsl:text>
        <xsl:value-of select="$k"/>
        <xsl:text> FROM </xsl:text>
        <xsl:value-of select="$referenced_table"/>
        <xsl:text> WHERE </xsl:text>
        <xsl:value-of select="$k"/>
        <xsl:text> = NEW.</xsl:text>
        <xsl:value-of select="$fk"/>        
        <xsl:text>) IS NULL)</xsl:text>
        <xsl:text>&newline;&tab;&tab;THEN RAISE(ABORT, '</xsl:text>
		<xsl:value-of select="$trigger_type"/>
		<xsl:text> on table </xsl:text>
        <xsl:value-of select="$modified_table"/>
        <xsl:text> violates foreign key constraint')</xsl:text>
        <xsl:text>&newline;&tab;END;&newline;END;&newline;&newline;</xsl:text>
	</xsl:template>
	
	
	<!-- Add TRIGGER to enforce integrity on DELETE -->
	<xsl:template name="trigger_delete">
		<!-- The table we want to delete from -->
        <xsl:param name="delete_table"/>
		
		<!-- Cascade DELETE? (0/1)-->
        <xsl:param name="delete_cascade"/>
		
        <!-- The table referenced by foreign key -->
        <xsl:param name="referenced_table"/>
        
        <!-- foreign key name for table we are inserting in -->
		<xsl:param name="fk"/>
        
		<!-- primary key name for referenced table -->
        <xsl:param name="k"/>
        
		<!-- fki_ or fku_ prefix for trigger name -->
		<xsl:text>CREATE TRIGGER fkd_</xsl:text>

		<xsl:value-of select="$delete_table"/>
        <xsl:text>_</xsl:text>
        <xsl:value-of select="$fk"/>

		<xsl:text> BEFORE DELETE ON </xsl:text>
        <xsl:value-of select="$referenced_table"/>
		<xsl:text>&newline;FOR EACH ROW BEGIN&newline;&tab;</xsl:text>
		
		<xsl:choose>
			<xsl:when test="$delete_cascade = 1">
				<xsl:text>DELETE from </xsl:text><xsl:value-of select="$delete_table"/>
				<xsl:text> WHERE </xsl:text>
				<xsl:value-of select="$fk"/><xsl:text> = OLD.</xsl:text><xsl:value-of select="$k"/>
				<xsl:text>;</xsl:text>
			</xsl:when>
			
			<xsl:otherwise>
				<xsl:text>SELECT CASE&newline;&tab;&tab;</xsl:text>
				<xsl:text>WHEN ((</xsl:text>
			
				<xsl:text>SELECT </xsl:text>
				<xsl:value-of select="$fk"/>
				<xsl:text> FROM </xsl:text>
				<xsl:value-of select="$delete_table"/>
				<xsl:text> WHERE </xsl:text>
				<xsl:value-of select="$fk"/>
				<xsl:text> = OLD.</xsl:text>
				<xsl:value-of select="$k"/>        
				<xsl:text>) IS NOT NULL)</xsl:text>
				<xsl:text>&newline;&tab;&tab;THEN RAISE(ABORT, 'DELETE on table </xsl:text>
				<xsl:value-of select="$referenced_table"/>
				<xsl:text> violates foreign key constraint')</xsl:text>
			
				<!-- END SELECT CASE -->
				<xsl:text>&newline;&tab;END;</xsl:text>
			</xsl:otherwise>
		</xsl:choose>
		
		<!-- END FOR EACH -->
		<xsl:text>&newline;END;&newline;&newline;</xsl:text>
	</xsl:template>
	
</xsl:stylesheet>
