----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET NOCOUNT ON;
----------------------------------------------------------------------------------------------------------------------------------------
--------------------------------------------Configure Search Here-----------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
DECLARE @search_string NVARCHAR(MAX) = ''; -- This is the text you are searching for.
DECLARE @search_SSRS BIT = 0; -- Do you want to search MSDB for SQL Server Reporting Services objects?
DECLARE @search_SSIS_MSDB BIT = 0; -- Do you want to search unencrypted SSIS packages defined in MSDB?
DECLARE @search_SSIS_disk BIT = 0; -- Do you want to search SSIS packages that are located on disk?
DECLARE @pkg_directory NVARCHAR(MAX) = '\\hreport\e$\SSIS'; -- If searching SSIS packages on disk, specify the target folder here.
DECLARE @only_process_this_database NVARCHAR(MAX) = NULL; -- If you'd like this proc to ONLY search a single database, enter it here.  Otherwise, leave it NULL
DECLARE @database_name_like NVARCHAR(MAX) = NULL; -- Apply a LIKE condition to database names to search.  Can be combined with a NOT LIKE condition.
DECLARE @database_name_not_like NVARCHAR(MAX) = NULL; -- Apply a NOT LIKE condition to database names to search.  Can be combined with a LIKE condition.
----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------------------------------
SET @search_string = '%' + @search_string + '%';
DECLARE @sql_command NVARCHAR(MAX);
DECLARE @database_name NVARCHAR(MAX);
DECLARE @database TABLE
	(database_name NVARCHAR(MAX), is_online BIT);

IF OBJECT_ID('#object_data') IS NOT NULL
BEGIN
	DROP TABLE #object_data;
END

CREATE TABLE #object_data
(	server_name NVARCHAR(MAX) NULL,
	database_name NVARCHAR(MAX) NULL,
	schema_name NVARCHAR(MAX) NULL,
	table_name NVARCHAR(MAX) NULL,
	column_name NVARCHAR(MAX) NULL,
	objectname NVARCHAR(MAX) NULL,
	step_name NVARCHAR(MAX) NULL,
	object_description NVARCHAR(MAX) NULL,
	object_definition NVARCHAR(MAX) NULL,
	key_column_list NVARCHAR(MAX) NULL,
	include_column_list NVARCHAR(MAX) NULL,
	xml_content XML NULL,
	text_content NVARCHAR(MAX) NULL,
	enabled BIT NULL,
	status NVARCHAR(MAX) NULL,
	object_type NVARCHAR(50) NULL);

IF @only_process_this_database IS NOT NULL
BEGIN
	IF EXISTS (SELECT * FROM sys.databases WHERE databases.name = @only_process_this_database AND databases.state = 0)
	BEGIN
		INSERT INTO @database
			(database_name, is_online)
		SELECT
			@only_process_this_database,
			1;
	END
	ELSE
	BEGIN
		DROP TABLE #object_data;
		RAISERROR('Invalid database name supplied for @only_process_this_database parameter.  Please try again or use NULL instead.', 16, 1);
		RETURN;
	END
END
ELSE
IF @database_name_like IS NOT NULL AND @database_name_not_like IS NOT NULL
BEGIN
	INSERT INTO @database
		(database_name, is_online)
	SELECT
		databases.name,
		CASE WHEN databases.state = 0 THEN 1 ELSE 0 END AS is_online
	FROM sys.databases
	WHERE databases.name LIKE '%' + @database_name_like + '%'
	AND databases.name NOT LIKE '%' + @database_name_not_like + '%';
END
ELSE
IF @database_name_like IS NOT NULL AND @database_name_not_like IS NULL
BEGIN
	INSERT INTO @database
		(database_name, is_online)
	SELECT
		databases.name,
		CASE WHEN databases.state = 0 THEN 1 ELSE 0 END AS is_online
	FROM sys.databases
	WHERE databases.name LIKE '%' + @database_name_like + '%';
END
ELSE
IF @database_name_like IS NULL AND @database_name_not_like IS NOT NULL
BEGIN
	INSERT INTO @database
		(database_name, is_online)
	SELECT
		databases.name,
		CASE WHEN databases.state = 0 THEN 1 ELSE 0 END AS is_online
	FROM sys.databases
	WHERE databases.name NOT LIKE '%' + @database_name_not_like + '%';
END
ELSE
BEGIN
	INSERT INTO @database
		(database_name, is_online)
	SELECT
		databases.name,
		CASE WHEN databases.state = 0 THEN 1 ELSE 0 END AS is_online
	FROM sys.databases;
END

-- Jobs
INSERT INTO #object_data
	(server_name, objectname, object_description, enabled, object_type)
SELECT
	sysservers.srvname AS server_name,
	sysjobs.name AS objectname,
	sysjobs.description AS object_description,
	sysjobs.enabled,
	'SQL Agent Job' AS object_type
FROM msdb.dbo.sysjobs
INNER JOIN master.dbo.sysservers
ON srvid = originating_server_id
WHERE sysjobs.name LIKE @search_string
OR sysjobs.description LIKE @search_string;

-- Job Steps
INSERT INTO #object_data
	(server_name, objectname, step_name, object_description, object_definition, enabled, object_type)
SELECT
	s.srvname AS server_name,
	sysjobs.name AS objectname,
	sysjobsteps.step_name,
	sysjobs.description AS object_description,
	sysjobsteps.command AS object_definition,
	sysjobs.enabled,
	'SQL Agent Job Step'
FROM msdb.dbo.sysjobs
INNER JOIN msdb.dbo.sysjobsteps
ON sysjobsteps.job_id = sysjobs.job_id
INNER JOIN master.dbo.sysservers s
ON s.srvid = sysjobs.originating_server_id
WHERE sysjobsteps.command LIKE @search_string
OR sysjobsteps.step_name LIKE @search_string;

-- SQL Server Agent Alerts
INSERT INTO #object_data
	(database_name, objectname, step_name, object_description, object_definition, enabled, object_type)
SELECT
	sysalerts.database_name AS database_name,
	sysalerts.name AS objectname,
	'SQL Server Agent Job: ' + sysjobs.name AS step_name,
	sysalerts.notification_message AS object_description,
	sysalerts.performance_condition AS object_definition,
	sysalerts.enabled,
	'SQL Agent Alert' AS object_type
FROM msdb.dbo.sysalerts
LEFT JOIN msdb.dbo.sysjobs
ON sysjobs.job_id = sysalerts.job_id
WHERE sysalerts.name LIKE @search_string
OR ISNULL(sysjobs.name, '') LIKE @search_string
OR ISNULL(sysalerts.database_name, '') LIKE @search_string
OR ISNULL(sysalerts.performance_condition, '') LIKE @search_string
OR ISNULL(sysalerts.notification_message, '') LIKE @search_string;

-- SQL Server Agent Operators
INSERT INTO #object_data
	(objectname, object_definition, enabled, object_type)
SELECT
	sysoperators.name AS objectname,
	sysoperators.email_address AS object_definition,
	sysoperators.enabled,
	'SQL Agent Operator' AS object_type
FROM msdb.dbo.sysoperators
WHERE sysoperators.email_address LIKE @search_string
OR sysoperators.name LIKE @search_string;

-- Databases
INSERT INTO #object_data
	( objectname, object_type)
SELECT
	databases.name AS objectname,
	'Database' AS object_type
FROM sys.databases
WHERE databases.name LIKE @search_string;

-- Logins
INSERT INTO #object_data
	(objectname, object_type)
SELECT
	syslogins.name AS objectname,
	'Server Login' AS object_type
FROM sys.syslogins
WHERE syslogins.name LIKE @search_string;

-- Linked Servers
INSERT INTO #object_data
	(objectname, object_definition, object_type)
SELECT
	servers.name AS objectname,
	servers.data_source AS object_definition,
	'Linked Server' AS object_type
FROM sys.servers
WHERE servers.name LIKE @search_string
OR servers.data_source LIKE @search_string;

-- Server Triggers
INSERT INTO #object_data
	(objectname, object_description, object_definition, object_type)
SELECT
	server_triggers.name AS objectname,
	parent_class_desc AS object_description,
	server_sql_modules.definition AS object_definition,
	'Server Trigger' AS object_type
FROM sys.server_triggers
INNER JOIN sys.server_sql_modules
ON server_triggers.object_id = server_sql_modules.object_id
WHERE server_triggers.name LIKE @search_string
OR server_sql_modules.definition LIKE @search_string;

-- Central Management Server Groups
INSERT INTO #object_data
	(objectname, object_description, object_type)
SELECT      
      sysmanagement_shared_server_groups_internal.name AS objectname,
	  sysmanagement_shared_server_groups_internal.Description AS object_description,
	  'Central Management Server (Group)' AS object_type
FROM msdb.dbo.sysmanagement_shared_server_groups_internal
WHERE sysmanagement_shared_server_groups_internal.server_type = 0 -- Only Database Engine Server Group
AND (sysmanagement_shared_server_groups_internal.name LIKE @search_string OR sysmanagement_shared_server_groups_internal.Description LIKE @search_string);

-- Central Management Server Servers
INSERT INTO #object_data
	(server_name, objectname, object_description, object_definition, object_type)
SELECT
	  sysmanagement_shared_registered_servers_internal.server_name AS server_name,
	  sysmanagement_shared_registered_servers_internal.name AS objectname, 
	  sysmanagement_shared_registered_servers_internal.Description AS object_description,
	  'CMS Group: ' + ISNULL(sysmanagement_shared_server_groups_internal.name, '') AS object_definition,
	  'Central Management Server (Server Listing)' AS object_type 
FROM msdb.dbo.sysmanagement_shared_server_groups_internal
LEFT JOIN msdb.dbo.sysmanagement_shared_registered_servers_internal
ON sysmanagement_shared_server_groups_internal.server_group_id = sysmanagement_shared_registered_servers_internal.server_group_id
WHERE sysmanagement_shared_server_groups_internal.server_type = 0 -- Only Database Engine Server Group
AND (sysmanagement_shared_registered_servers_internal.name LIKE @search_string OR sysmanagement_shared_registered_servers_internal.server_name LIKE @search_string OR sysmanagement_shared_registered_servers_internal.Description LIKE @search_string)
AND sysmanagement_shared_registered_servers_internal.server_name IS NOT NULL

-- Reporting Services
IF EXISTS (SELECT * FROM sys.databases WHERE databases.name = 'ReportServer')
AND @search_SSRS = 1
BEGIN
	INSERT INTO #object_data
		(objectname, object_definition, xml_content, text_content, object_type)
	SELECT
		Catalog.Name AS objectname,
		Catalog.Path AS object_definition,
		CONVERT(XML, CONVERT(VARBINARY(MAX), Catalog.content)) AS xml_content,
		CONVERT(NVARCHAR(MAX), CONVERT(XML, CONVERT(VARBINARY(MAX), Catalog.content))) AS text_content,
		CASE Catalog.Type
			WHEN 1 THEN 'SSRS Folder'
			WHEN 2 THEN 'SSRS Report'
			WHEN 3 THEN 'SSRS Resource'
			WHEN 4 THEN 'SSRS Linked Report'
			WHEN 5 THEN 'SSRS Data Source'
			WHEN 6 THEN 'SSRS Report Model'
			WHEN 7 THEN 'SSRS Report Part'
			WHEN 8 THEN 'SSRS Shared Dataset'
			ELSE 'SSRS Unknown'
		END AS object_type
	FROM reportserver.dbo.Catalog
	LEFT JOIN ReportServer.dbo.Subscriptions
	ON Subscriptions.Report_OID = Catalog.ItemID
	WHERE Catalog.Path LIKE @search_string
	OR Catalog.Name LIKE @search_string
	OR CONVERT(NVARCHAR(MAX), CONVERT(XML, CONVERT(VARBINARY(MAX), Catalog.content))) LIKE @search_string
	OR Subscriptions.DataSettings LIKE @search_string
	OR Subscriptions.ExtensionSettings LIKE @search_string
	OR Subscriptions.Description LIKE @search_string;
	
	INSERT INTO #object_data
		(object_description, object_definition, text_content, status, object_type)
	SELECT
		Subscriptions.Description AS object_description,
		Subscriptions.ExtensionSettings AS object_definition,
		Subscriptions.DeliveryExtension AS text_content,
		Subscriptions.LastStatus AS status,
		'SSRS Subscription' AS object_type
	FROM ReportServer.dbo.Subscriptions
	WHERE Subscriptions.ExtensionSettings LIKE @search_string
	OR Subscriptions.Description LIKE @search_string
	OR Subscriptions.DataSettings LIKE @search_string;
END

IF @search_SSIS_MSDB = 1
BEGIN
	WITH CTE_SSIS AS (
	SELECT
		pf.foldername + '\'+ p.name AS full_path,
		CONVERT(XML,CONVERT(VARBINARY(MAX),packagedata)) AS package_details_XML,
		CONVERT(NVARCHAR(max), CONVERT(XML,CONVERT(VARBINARY(MAX),packagedata))) AS package_details_text,
		'SSIS Package (MSDB)' AS object_type
	FROM msdb.dbo.sysssispackages p
	INNER JOIN msdb.dbo.sysssispackagefolders pf
	ON p.folderid = pf.folderid)
	INSERT INTO #object_data
		(object_description, xml_content, text_content, object_type)
	SELECT
		full_path AS object_description,
		package_details_XML AS xml_content,
		package_details_text AS text_content,
		object_type
	FROM CTE_SSIS
	WHERE CTE_SSIS.package_details_text LIKE @search_string
	OR CTE_SSIS.full_path LIKE @search_string;
END

IF @search_SSIS_disk = 1
BEGIN
	DECLARE @xp_cmdshell_command VARCHAR(4000);

	CREATE TABLE #SSIS_data
	  (  full_path	          NVARCHAR(MAX),
		 package_details_XML  XML,
		 package_details_text NVARCHAR(MAX) );

	DECLARE @ssis_package_name NVARCHAR(MAX);

	SELECT @xp_cmdshell_command = 'dir "' + @pkg_directory + '" /A-D /B /S ';

	INSERT INTO #SSIS_data
		(full_path)
	EXEC Xp_cmdshell @xp_cmdshell_command;

	DELETE FROM #SSIS_data
	WHERE full_path not like '%.dts%'

	DECLARE SSIS_CURSOR CURSOR FOR
	SELECT full_path FROM #SSIS_data;

	OPEN SSIS_CURSOR;

	FETCH NEXT FROM SSIS_CURSOR INTO @ssis_package_name;

	WHILE @@FETCH_STATUS = 0
	  BEGIN

		  SELECT @sql_command = 'WITH CTE_SSIS_PACKAGES AS (
							SELECT
								''' + @ssis_package_name + ''' AS full_path,
								CONVERT(XML, SSIS_PACKAGE.bulkcolumn) AS package_details_XML
							FROM OPENROWSET(BULK ''' + @ssis_package_name + ''', single_blob) AS SSIS_PACKAGE)
						  UPDATE SSIS_DATA 
								SET package_details_XML = CTE_SSIS_PACKAGES.package_details_XML
						  FROM CTE_SSIS_PACKAGES
						  INNER JOIN #SSIS_data SSIS_DATA
						  ON CTE_SSIS_PACKAGES.full_path = SSIS_DATA.full_path;'
		  FROM #SSIS_data;

		  EXEC sp_executesql @sql_command;
		  FETCH NEXT FROM SSIS_CURSOR INTO @ssis_package_name;
	  END

	CLOSE SSIS_CURSOR;
	DEALLOCATE SSIS_CURSOR;


	UPDATE SSIS_DATA
	SET    package_details_text = CONVERT(NVARCHAR(MAX), SSIS_DATA.package_details_XML)
	FROM   #SSIS_data SSIS_DATA;

	INSERT INTO #object_data
		(object_description, xml_content, text_content, object_type)
	SELECT
		full_path AS object_description,
		package_details_XML AS xml_content,
		package_details_text AS text_content,
		'SSIS Package (File System)' AS object_type
	FROM #SSIS_data SSIS_DATA
	WHERE SSIS_DATA.package_details_text LIKE @search_string
	OR SSIS_DATA.full_path LIKE @search_string;

	DROP TABLE #SSIS_data;
END

-- Iterate through databases to retrieve database object metadata
DECLARE DBCURSOR CURSOR FOR
SELECT database_name FROM @database WHERE is_online = 1;
OPEN DBCURSOR;
FETCH NEXT FROM DBCURSOR INTO @database_name;

WHILE @@FETCH_STATUS = 0
BEGIN
	SELECT @sql_command = '
	USE [' + @database_name + '];
	-- Tables
	INSERT INTO #object_data
		(database_name, schema_name, table_name, object_type)
	SELECT
		db_name() AS database_name,
		schemas.name AS schema_name,
		tables.name AS table_name,
		''Table'' AS object_type
	FROM sys.tables
	INNER JOIN sys.schemas
	ON schemas.schema_id = tables.schema_id
	WHERE tables.name LIKE ''' + @search_string + ''';
	-- Columns
	INSERT INTO #object_data
		(database_name, schema_name, table_name, column_name, object_type)
	SELECT
		db_name() AS database_name,
		schemas.name AS schema_name,
		tables.name AS table_name,
		columns.name AS column_name,
		''Column'' AS object_type
	FROM sys.tables
	INNER JOIN sys.columns
	ON tables.object_id = columns.object_id
	INNER JOIN sys.schemas
	ON schemas.schema_id = tables.schema_id
	WHERE columns.name LIKE ''' + @search_string + ''';
	-- Schemas
	INSERT INTO #object_data
		(database_name, schema_name, object_type)
	SELECT
		db_name() AS database_name,
		schemas.name AS schema_name,
		''Schema'' AS object_type
	FROM sys.schemas
	WHERE schemas.name LIKE ''' + @search_string + ''';
	-- Synonyms
	INSERT INTO #object_data
		(database_name, objectname, object_definition, object_type)
	SELECT
		db_name() AS database_name,
		synonyms.name AS objectname,
		synonyms.base_object_name AS object_definition,
		''Synonym'' AS object_type
	FROM sys.synonyms
	WHERE synonyms.name LIKE ''' + @search_string + '''
	OR synonyms.base_object_name LIKE ''' + @search_string + ''';
	-- Indexes and Index Column References
	WITH CTE_INDEX_COLUMNS AS (
		SELECT
			db_name() AS database_name,
			schemas.name AS schema_name,
			TABLE_DATA.name AS table_name,
			INDEX_DATA.name AS index_name,
			STUFF(( SELECT '', '' + columns.name
					FROM sys.tables
					INNER JOIN sys.indexes
					ON tables.object_id = indexes.object_id
					INNER JOIN sys.index_columns
					ON indexes.object_id = index_columns.object_id
					AND indexes.index_id = index_columns.index_id
					INNER JOIN sys.columns
					ON tables.object_id = columns.object_id
					AND index_columns.column_id = columns.column_id
					WHERE INDEX_DATA.object_id = indexes.object_id
					AND INDEX_DATA.index_id = indexes.index_id
					AND index_columns.is_included_column = 0
					ORDER BY index_columns.key_ordinal
				FOR XML PATH('''')), 1, 2, '''') AS key_column_list,
				STUFF(( SELECT '', '' + columns.name
					FROM sys.tables
					INNER JOIN sys.indexes
					ON tables.object_id = indexes.object_id
					INNER JOIN sys.index_columns
					ON indexes.object_id = index_columns.object_id
					AND indexes.index_id = index_columns.index_id
					INNER JOIN sys.columns
					ON tables.object_id = columns.object_id
					AND index_columns.column_id = columns.column_id
					WHERE INDEX_DATA.object_id = indexes.object_id
					AND INDEX_DATA.index_id = indexes.index_id
					AND index_columns.is_included_column = 1
					ORDER BY index_columns.key_ordinal
				FOR XML PATH('''')), 1, 2, '''') AS include_column_list
		FROM sys.indexes INDEX_DATA
		INNER JOIN sys.tables TABLE_DATA
		ON TABLE_DATA.object_id = INDEX_DATA.object_id
		INNER JOIN sys.schemas
		ON TABLE_DATA.schema_id = schemas.schema_id		)
	INSERT INTO #object_data
		(database_name, schema_name, table_name, objectname, key_column_list, include_column_list, object_type)
	SELECT
		CTE_INDEX_COLUMNS.database_name,
		CTE_INDEX_COLUMNS.schema_name,
		CTE_INDEX_COLUMNS.table_name,
		CTE_INDEX_COLUMNS.index_name AS objectname,
		CTE_INDEX_COLUMNS.key_column_list,
		ISNULL(CTE_INDEX_COLUMNS.include_column_list, '''') AS include_column_list,
		CASE WHEN CTE_INDEX_COLUMNS.index_name LIKE ''' + @search_string + ''' AND (CTE_INDEX_COLUMNS.key_column_list NOT LIKE ''' + @search_string + ''' AND ISNULL(CTE_INDEX_COLUMNS.include_column_list, '''') NOT LIKE ''' + @search_string + ''')
				THEN ''Index''
			 ELSE ''Index Column''
		END AS object_type
	FROM CTE_INDEX_COLUMNS
	WHERE CTE_INDEX_COLUMNS.key_column_list LIKE ''' + @search_string + '''
	OR ISNULL(CTE_INDEX_COLUMNS.include_column_list, '''') LIKE ''' + @search_string + '''
	OR CTE_INDEX_COLUMNS.index_name LIKE ''' + @search_string + ''';
	-- Service Broker Queues
	INSERT INTO #object_data
		(database_name, objectname, object_type)
	SELECT
		db_name() AS database_name,
		name AS objectname,
		''Queue'' AS object_type
	FROM sys.service_queues
	WHERE service_queues.name LIKE ''' + @search_string + ''';
	-- Replication Articles
	INSERT INTO #object_data
		(database_name, schema_name, table_name, objectname, status, object_type)
	SELECT
		DB_NAME() AS database_name,
		schemas.name AS schema_name,
		CASE WHEN objects.type_desc = ''USER_TABLE'' THEN objects.name ELSE NULL END AS table_name,
		dm_repl_articles.wszArtdesttable AS objectname,
		CASE dm_repl_articles.artstatus WHEN 1 THEN ''Active'' WHEN 8 THEN ''Include column name in INSERT statements'' WHEN 16 THEN ''Use parameterized statements'' WHEN 24 THEN ''Include column name in INSERT statements and use parameterized statements''
			WHEN 9 THEN ''Active and Include column name in INSERT statements'' WHEN 17 THEN ''Active and Use parameterized statements'' WHEN 25 THEN ''Active, include column name in INSERT statements, and use parameterized statements'' ELSE NULL END AS status,
		''Replication Article'' AS object_type
	FROM sys.dm_repl_articles
	INNER JOIN sys.objects
	ON dm_repl_articles.artobjid = objects.object_id
	INNER JOIN sys.schemas
	ON objects.schema_id = schemas.schema_id
	WHERE dm_repl_articles.wszArtdesttable LIKE ''' + @search_string + ''';
	-- Partition Schemes
	INSERT INTO #object_data
		(database_name, schema_name, table_name, objectname, object_type)
	SELECT DISTINCT
		DB_NAME() AS database_name,
		schemas.name AS schema_name,
		tables.name AS table_name,
		partition_schemes.name AS objectname,
		''Partition Scheme'' AS object_type
	FROM sys.partition_schemes
	INNER JOIN sys.indexes
	ON indexes.data_space_id = partition_schemes.data_space_id
	INNER JOIN sys.tables
	ON indexes.object_id = tables.object_id
	INNER JOIN sys.schemas
	ON tables.schema_id = schemas.schema_id
	WHERE partition_schemes.name LIKE ''' + @search_string + ''';
	-- Partition Functions
	INSERT INTO #object_data
		(database_name, objectname, object_type)
	SELECT
		DB_NAME() AS database_name,
		partition_functions.name AS objectname,
		''Partition Function'' AS object_type
	FROM sys.partition_functions
	WHERE partition_functions.name LIKE ''' + @search_string + ''';
	-- Database principals (users, roles, etc...)
	INSERT INTO #object_data
		(database_name, schema_name, objectname, object_description, object_type)
	SELECT
		db_name() AS database_name,
		database_principals.default_schema_name AS schema_name,
		database_principals.name AS objectname,
		database_principals.type_desc AS object_description,
		''Database Principal'' AS object_type
	FROM sys.database_principals
	WHERE database_principals.name LIKE ''' + @search_string + ''';
	-- Foreign Keys
	INSERT INTO #object_data
		(database_name, schema_name, table_name, objectname, object_type)
	SELECT
		db_name() AS database_name,
		schemas.name AS schema_name,
		objects.name AS table_name,
		foreign_keys.name AS objectname,
		''Foreign Key'' AS object_type
	FROM sys.foreign_keys
	INNER JOIN sys.schemas
	ON foreign_keys.schema_id = schemas.schema_id
	INNER JOIN sys.objects
	ON objects.object_id = foreign_keys.parent_object_id
	WHERE foreign_keys.name LIKE ''' + @search_string + ''';
	-- Foreign Key Columns
	WITH CTE_FOREIGN_KEY_COLUMNS AS (
		SELECT
			parent_schema.name AS parent_schema,
			parent_table.name AS parent_table,
			referenced_schema.name AS referenced_schema,
			referenced_table.name AS referenced_table,
			foreign_keys.name AS foreign_key_name,
			STUFF(( SELECT '', '' + referencing_column.name
					FROM sys.foreign_key_columns
					INNER JOIN sys.objects
					ON objects.object_id = foreign_key_columns.constraint_object_id
					INNER JOIN sys.tables parent_table
					ON foreign_key_columns.parent_object_id = parent_table.object_id
					INNER JOIN sys.schemas parent_schema
					ON parent_schema.schema_id = parent_table.schema_id
					INNER JOIN sys.columns referencing_column
					ON foreign_key_columns.parent_object_id = referencing_column.object_id 
					AND foreign_key_columns.parent_column_id = referencing_column.column_id
					INNER JOIN sys.columns referenced_column
					ON foreign_key_columns.referenced_object_id = referenced_column.object_id
					AND foreign_key_columns.referenced_column_id = referenced_column.column_id
					INNER JOIN sys.tables referenced_table
					ON referenced_table.object_id = foreign_key_columns.referenced_object_id
					INNER JOIN sys.schemas referenced_schema
					ON referenced_schema.schema_id = referenced_table.schema_id
					WHERE objects.object_id = foreign_keys.object_id
					ORDER BY foreign_key_columns.constraint_column_id ASC
				FOR XML PATH('''')), 1, 2, '''') AS foreign_key_column_list,
			STUFF(( SELECT '', '' + referenced_column.name
					FROM sys.foreign_key_columns
					INNER JOIN sys.objects
					ON objects.object_id = foreign_key_columns.constraint_object_id
					INNER JOIN sys.tables parent_table
					ON foreign_key_columns.parent_object_id = parent_table.object_id
					INNER JOIN sys.schemas parent_schema
					ON parent_schema.schema_id = parent_table.schema_id
					INNER JOIN sys.columns referencing_column
					ON foreign_key_columns.parent_object_id = referencing_column.object_id 
					AND foreign_key_columns.parent_column_id = referencing_column.column_id
					INNER JOIN sys.columns referenced_column
					ON foreign_key_columns.referenced_object_id = referenced_column.object_id
					AND foreign_key_columns.referenced_column_id = referenced_column.column_id
					INNER JOIN sys.tables referenced_table
					ON referenced_table.object_id = foreign_key_columns.referenced_object_id
					INNER JOIN sys.schemas referenced_schema
					ON referenced_schema.schema_id = referenced_table.schema_id
					WHERE objects.object_id = foreign_keys.object_id
					ORDER BY foreign_key_columns.constraint_column_id ASC
				FOR XML PATH('''')), 1, 2, '''') AS referenced_column_list,
				''Foreign Key Column'' AS object_type
		FROM sys.foreign_keys
		INNER JOIN sys.tables parent_table
		ON foreign_keys.parent_object_id = parent_table.object_id
		INNER JOIN sys.schemas parent_schema
		ON parent_schema.schema_id = parent_table.schema_id
		INNER JOIN sys.tables referenced_table
		ON referenced_table.object_id = foreign_keys.referenced_object_id
		INNER JOIN sys.schemas referenced_schema
		ON referenced_schema.schema_id = referenced_table.schema_id)
	INSERT INTO #object_data
		(database_name, schema_name, table_name, objectname, key_column_list, object_type)
	SELECT
		db_name() AS database_name,
		parent_schema + '' --> '' + referenced_schema,
		parent_table + '' --> '' + referenced_table,
		foreign_key_name AS objectname,
		foreign_key_column_list + '' --> '' + referenced_column_list AS key_column_list,
		object_type
	FROM CTE_FOREIGN_KEY_COLUMNS
	WHERE CTE_FOREIGN_KEY_COLUMNS.foreign_key_column_list LIKE ''' + @search_string + '''
	OR CTE_FOREIGN_KEY_COLUMNS.referenced_column_list LIKE ''' + @search_string + ''';
	-- Default Constraints
	INSERT INTO #object_data
		(database_name, schema_name, table_name, column_name, objectname, object_definition, object_type)
	SELECT
		db_name() AS database_name,
		schemas.name AS schema_name,
		objects.name AS table_name,
		columns.name AS column_name,
		default_constraints.name AS objectname,
		default_constraints.definition AS object_definition,
		''Default Constraint'' AS object_type
	FROM sys.default_constraints
	INNER JOIN sys.objects
	ON objects.object_id = default_constraints.parent_object_id
	INNER JOIN sys.schemas
	ON objects.schema_id = schemas.schema_id
	INNER JOIN sys.columns
	ON columns.object_id = objects.object_id
	AND columns.column_id = default_constraints.parent_column_id
	WHERE default_constraints.name LIKE ''' + @search_string + '''
	OR default_constraints.definition LIKE ''' + @search_string + ''';
	-- Computed Column Definitions
	INSERT INTO #object_data
		(database_name, schema_name, table_name, column_name, objectname, object_definition, object_type)
	SELECT
		db_name() AS database_name,
		schemas.name AS schema_name,
		tables.name AS table_name,
		columns.name AS Column_Name,
		computed_columns.name AS objectname,
		computed_columns.definition AS object_definition,
		''Computed Column'' AS object_type
	FROM sys.schemas
	INNER JOIN sys.tables
	ON schemas.schema_id = tables.schema_id
	INNER JOIN sys.columns
	ON tables.object_id = columns.object_id
	INNER JOIN sys.computed_columns
	ON columns.object_id = computed_columns.object_id
	AND columns.column_id = computed_columns.column_id
	WHERE computed_columns.name LIKE ''' + @search_string + '''
	OR computed_columns.definition LIKE ''' + @search_string + ''';
	-- Check Constraints
	INSERT INTO #object_data
		(database_name, schema_name, table_name, objectname, object_definition, object_type)
	SELECT
		db_name() AS database_name,
		schemas.name AS schema_name,
		objects.name AS table_name,
		check_constraints.name AS objectname,
		check_constraints.definition AS object_definition,
		''Check Constraint'' AS object_type
	FROM sys.check_constraints
	INNER JOIN sys.objects
	ON objects.object_id = check_constraints.parent_object_id
	INNER JOIN sys.schemas
	ON objects.schema_id = schemas.schema_id
	WHERE check_constraints.name LIKE ''' + @search_string + '''
	OR check_constraints.definition LIKE ''' + @search_string + ''';
	-- Database DDL Triggers
	INSERT INTO #object_data
		(database_name, objectname, object_description, object_definition, object_type)
	SELECT
		db_name() AS database_name,
		triggers.name AS objectname,
		triggers.parent_class_desc AS object_description,
		sql_modules.definition AS object_definition,
		''Database DDL Trigger'' AS object_type
	FROM sys.triggers
	INNER JOIN sys.sql_modules
	ON triggers.object_id = sys.sql_modules.object_id
	WHERE parent_class_desc = ''DATABASE''
	AND (triggers.name LIKE ''' + @search_string + ''' OR sql_modules.definition LIKE ''' + @search_string + ''');
	-- P (stored proc), RF (replication-filter-procedure), V (view), TR (DML trigger), FN (scalar function), IF (inline table-valued function), TF (SQL table-valued function), and R (rule)
	INSERT INTO #object_data
		(database_name, schema_name, table_name, objectname, object_definition, object_type)
	SELECT
		db_name() AS database_name,
		parent_schema.name AS schema_name,
		parent_object.name AS table_name,
		child_object.name AS objectname,
		sql_modules.definition AS object_definition,
		CASE child_object.type 
			WHEN ''P'' THEN ''Stored Procedure''
			WHEN ''RF'' THEN ''Replication Filter Procedure''
			WHEN ''V'' THEN ''View''
			WHEN ''TR'' THEN ''DML Trigger''
			WHEN ''FN'' THEN ''Scalar Function''
			WHEN ''IF'' THEN ''Inline Table Valued Function''
			WHEN ''TF'' THEN ''SQL Table Valued Function''
			WHEN ''R'' THEN ''Rule''
		END	AS object_type
	FROM sys.sql_modules
	INNER JOIN sys.objects child_object
	ON sql_modules.object_id = child_object.object_id
	LEFT JOIN sys.objects parent_object
	ON parent_object.object_id = child_object.parent_object_id
	LEFT JOIN sys.schemas parent_schema
	ON child_object.schema_id = parent_schema.schema_id
	WHERE child_object.name LIKE ''' + @search_string + '''
	OR sql_modules.definition LIKE ''' + @search_string + '''';

	BEGIN TRY
		EXEC sp_executesql @sql_command;
	END TRY
	BEGIN CATCH
		DECLARE @Error_Message NVARCHAR(MAX);
		DECLARE @Error_Details NVARCHAR(MAX);
		SELECT
			@Error_Details = '
			Error Details: Error Number: ' + ISNULL(CAST(ERROR_NUMBER() AS VARCHAR(MAX)), '') + ', ' + 'Error Severity: ' + ISNULL(CAST(ERROR_SEVERITY() AS VARCHAR(MAX)), '') + ', ' +
				'Error State: ' + ISNULL(CAST(ERROR_STATE() AS VARCHAR(MAX)), '') + ', ' + 'Error Procedure: ' + ISNULL(CAST(ERROR_PROCEDURE() AS VARCHAR(MAX)), '') + ', ' +
				'Error Line: ' + ISNULL(CAST(ERROR_LINE() AS VARCHAR(MAX)), '') + ', ' + '
			Error Message: ' + ISNULL(CAST(ERROR_MESSAGE() AS VARCHAR(MAX)), '');

		SELECT @Error_Message = 'FIND Proc Error: Unable to access database ' + @database_name + '.  It has been skipped and results returned normally, excluding this metadata.' + @Error_Details;

		RAISERROR (@Error_Message, 16, 1);
	END CATCH

	FETCH NEXT FROM DBCURSOR INTO @database_name;
END

CLOSE DBCURSOR;
DEALLOCATE DBCURSOR;

SELECT
	object_type,
	server_name,
	database_name,
	schema_name,
	table_name,
	column_name,
	objectname,
	step_name,
	object_description,
	object_definition,
	key_column_list,
	include_column_list,
	xml_content,
	text_content,
	enabled,
	status
FROM #object_data
ORDER BY database_name, schema_name, table_name, object_type;

DROP TABLE #object_data;
GO