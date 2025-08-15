-- =================================================================
-- Oracle Exadata to Azure Database@Azure Assessment Script
-- =================================================================
-- Purpose: Comprehensive assessment for migration planning
-- Owner: KYNDRYL
-- Usage: Run as SYSDBA user with access to DBA views
-- Output: CSV and formatted reports for migration analysis
-- =================================================================

SET PAGESIZE 0
SET LINESIZE 4000
SET FEEDBACK OFF
SET VERIFY OFF
SET HEADING OFF
SET TERM OFF
SET TRIMSPOOL ON

-- Create output directory (modify path as needed)
DEFINE output_dir = '/tmp/exadata_assessment'

-- Set output file
SPOOL &output_dir/exadata_assessment_report.txt

PROMPT =================================================================
PROMPT ORACLE EXADATA TO AZURE DATABASE@AZURE ASSESSMENT REPORT
PROMPT Generated: 
SELECT 'Assessment Date: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =================================================================

PROMPT
PROMPT [1] DATABASE INSTANCE INFORMATION
PROMPT =================================================================
SELECT 
    'DATABASE_INFO,' ||
    d.name || ',' ||
    d.db_unique_name || ',' ||
    d.database_role || ',' ||
    i.instance_name || ',' ||
    i.version || ',' ||
    i.status || ',' ||
    TO_CHAR(i.startup_time, 'YYYY-MM-DD HH24:MI:SS') || ',' ||
    d.platform_name || ',' ||
    d.log_mode || ',' ||
    CASE WHEN d.force_logging = 'YES' THEN 'ENABLED' ELSE 'DISABLED' END || ',' ||
    d.open_mode
FROM v$database d, v$instance i;

PROMPT
PROMPT [2] DATABASE SIZE AND STORAGE
PROMPT =================================================================
SELECT 
    'DATABASE_SIZE,' ||
    ROUND(SUM(bytes)/1024/1024/1024,2) || ',' ||
    ROUND(SUM(maxbytes)/1024/1024/1024,2) || ',' ||
    COUNT(*) || ',' ||
    'TOTAL_SIZE_GB,MAX_SIZE_GB,DATAFILE_COUNT'
FROM dba_data_files;

SELECT 
    'TABLESPACE_INFO,' ||
    tablespace_name || ',' ||
    ROUND(SUM(bytes)/1024/1024/1024,2) || ',' ||
    ROUND(SUM(maxbytes)/1024/1024/1024,2) || ',' ||
    COUNT(*) || ',' ||
    status
FROM dba_data_files 
GROUP BY tablespace_name, status
ORDER BY SUM(bytes) DESC;

PROMPT
PROMPT [3] MEMORY CONFIGURATION
PROMPT =================================================================
SELECT 
    'MEMORY_CONFIG,' ||
    name || ',' ||
    value || ',' ||
    'BYTES'
FROM v$parameter 
WHERE name IN ('sga_max_size', 'pga_aggregate_target', 'memory_target', 'memory_max_target')
AND value IS NOT NULL;

SELECT 
    'SGA_COMPONENTS,' ||
    name || ',' ||
    ROUND(bytes/1024/1024,2) || ',' ||
    'MB'
FROM v$sgainfo 
WHERE bytes > 0;

PROMPT
PROMPT [4] CPU AND SYSTEM RESOURCES
PROMPT =================================================================
SELECT 
    'SYSTEM_STATS,' ||
    stat_name || ',' ||
    value
FROM v$osstat 
WHERE stat_name IN ('NUM_CPUS', 'NUM_CPU_CORES', 'NUM_CPU_SOCKETS', 'PHYSICAL_MEMORY_BYTES', 'LOAD');

PROMPT
PROMPT [5] DATABASE FEATURE USAGE
PROMPT =================================================================
SELECT 
    'FEATURE_USAGE,' ||
    name || ',' ||
    detected_usages || ',' ||
    TO_CHAR(last_usage_date, 'YYYY-MM-DD') || ',' ||
    currently_used || ',' ||
    version
FROM dba_feature_usage_statistics 
WHERE detected_usages > 0
ORDER BY detected_usages DESC;

PROMPT
PROMPT [6] TOP SEGMENTS BY SIZE
PROMPT =================================================================
SELECT * FROM (
    SELECT 
        'SEGMENT_SIZE,' ||
        owner || ',' ||
        segment_name || ',' ||
        segment_type || ',' ||
        ROUND(bytes/1024/1024/1024,2) || ',' ||
        tablespace_name
    FROM dba_segments 
    WHERE owner NOT IN ('SYS', 'SYSTEM', 'SYSAUX', 'SYSMAN', 'DBSNMP')
    ORDER BY bytes DESC
) WHERE ROWNUM <= 50;

PROMPT
PROMPT [7] ORACLE RAC CONFIGURATION
PROMPT =================================================================
SELECT 
    'RAC_INFO,' ||
    instance_number || ',' ||
    instance_name || ',' ||
    host_name || ',' ||
    status || ',' ||
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS')
FROM gv$instance
ORDER BY instance_number;

PROMPT
PROMPT [8] PLUGGABLE DATABASES (if applicable)
PROMPT =================================================================
SELECT 
    'PDB_INFO,' ||
    con_id || ',' ||
    name || ',' ||
    open_mode || ',' ||
    restricted || ',' ||
    TO_CHAR(open_time, 'YYYY-MM-DD HH24:MI:SS')
FROM v$pdbs
WHERE name != 'PDB$SEED';

PROMPT
PROMPT [9] DATABASE LINKS
PROMPT =================================================================
SELECT 
    'DB_LINKS,' ||
    owner || ',' ||
    db_link || ',' ||
    host || ',' ||
    username || ',' ||
    TO_CHAR(created, 'YYYY-MM-DD')
FROM dba_db_links;

PROMPT
PROMPT [10] SCHEDULER JOBS
PROMPT =================================================================
SELECT * FROM (
    SELECT 
        'SCHEDULER_JOBS,' ||
        owner || ',' ||
        job_name || ',' ||
        job_type || ',' ||
        enabled || ',' ||
        state || ',' ||
        TO_CHAR(last_start_date, 'YYYY-MM-DD HH24:MI:SS') || ',' ||
        TO_CHAR(next_run_date, 'YYYY-MM-DD HH24:MI:SS')
    FROM dba_scheduler_jobs
    WHERE owner NOT IN ('SYS', 'SYSTEM', 'ORACLE_OCM')
    ORDER BY last_start_date DESC NULLS LAST
) WHERE ROWNUM <= 100;

PROMPT
PROMPT [11] INVALID OBJECTS
PROMPT =================================================================
SELECT 
    'INVALID_OBJECTS,' ||
    owner || ',' ||
    object_name || ',' ||
    object_type || ',' ||
    status || ',' ||
    TO_CHAR(last_ddl_time, 'YYYY-MM-DD HH24:MI:SS')
FROM dba_objects 
WHERE status = 'INVALID'
AND owner NOT IN ('SYS', 'SYSTEM', 'PUBLIC', 'SYSMAN');

PROMPT
PROMPT [12] REGISTRY COMPONENTS
PROMPT =================================================================
SELECT 
    'REGISTRY_COMP,' ||
    comp_id || ',' ||
    comp_name || ',' ||
    version || ',' ||
    status || ',' ||
    schema
FROM dba_registry
ORDER BY comp_name;

PROMPT
PROMPT [13] ARCHIVELOG INFORMATION
PROMPT =================================================================
SELECT 
    'ARCHIVE_LOG,' ||
    TO_CHAR(first_time, 'YYYY-MM-DD') || ',' ||
    COUNT(*) || ',' ||
    ROUND(SUM(blocks * block_size)/1024/1024/1024,2) || ',' ||
    'DATE,COUNT,SIZE_GB'
FROM v$archived_log
WHERE first_time > SYSDATE - 30
AND deleted = 'NO'
GROUP BY TO_CHAR(first_time, 'YYYY-MM-DD')
ORDER BY TO_CHAR(first_time, 'YYYY-MM-DD') DESC;

PROMPT
PROMPT [14] EXADATA SPECIFIC - CELL INFORMATION
PROMPT =================================================================
-- Note: This requires access to Exadata cell services
SELECT 
    'CELL_INFO,' ||
    cell_name || ',' ||
    cell_version || ',' ||
    cell_type || ',' ||
    ip_address
FROM v$cell_state
WHERE cell_name IS NOT NULL;

PROMPT
PROMPT [15] EXADATA SPECIFIC - SMART SCAN STATISTICS
PROMPT =================================================================
SELECT 
    'SMART_SCAN,' ||
    s.name || ',' ||
    st.value
FROM v$sesstat st, v$statname s
WHERE st.statistic# = s.statistic#
AND st.sid = (SELECT sid FROM v$mystat WHERE rownum = 1)
AND s.name LIKE '%cell%'
AND st.value > 0;

PROMPT
PROMPT [16] WORKLOAD ANALYSIS - TOP SQL (Last 7 Days)
PROMPT =================================================================
SELECT * FROM (
    SELECT 
        'TOP_SQL,' ||
        sql_id || ',' ||
        executions || ',' ||
        ROUND(elapsed_time/1000000,2) || ',' ||
        ROUND(cpu_time/1000000,2) || ',' ||
        ROUND(buffer_gets/GREATEST(executions,1)) || ',' ||
        ROUND(disk_reads/GREATEST(executions,1)) || ',' ||
        'SQL_ID,EXECUTIONS,ELAPSED_SEC,CPU_SEC,AVG_BUFFER_GETS,AVG_DISK_READS'
    FROM dba_hist_sqlstat
    WHERE snap_id IN (
        SELECT snap_id FROM dba_hist_snapshot 
        WHERE end_interval_time > SYSDATE - 7
    )
    ORDER BY elapsed_time DESC
) WHERE ROWNUM <= 20;

PROMPT
PROMPT [17] RESOURCE UTILIZATION TRENDS
PROMPT =================================================================
SELECT 
    'RESOURCE_TREND,' ||
    TO_CHAR(end_interval_time, 'YYYY-MM-DD') || ',' ||
    metric_name || ',' ||
    ROUND(AVG(average),2) || ',' ||
    ROUND(MAX(maxval),2) || ',' ||
    'DATE,METRIC,AVG_VALUE,MAX_VALUE'
FROM dba_hist_sysmetric_summary
WHERE end_interval_time > SYSDATE - 30
AND metric_name IN (
    'Database CPU Time Ratio',
    'Database Wait Time Ratio',
    'Memory Usage %',
    'Physical Reads Per Sec',
    'Physical Writes Per Sec',
    'User Transaction Per Sec'
)
GROUP BY TO_CHAR(end_interval_time, 'YYYY-MM-DD'), metric_name
ORDER BY TO_CHAR(end_interval_time, 'YYYY-MM-DD') DESC, metric_name;

PROMPT
PROMPT [18] BACKUP AND RECOVERY CONFIGURATION
PROMPT =================================================================
-- RMAN Configuration
SELECT 
    'RMAN_CONFIG,' ||
    name || ',' ||
    value
FROM v$rman_configuration
WHERE value IS NOT NULL;

-- Backup Summary
SELECT 
    'BACKUP_SUMMARY,' ||
    input_type || ',' ||
    status || ',' ||
    COUNT(*) || ',' ||
    ROUND(SUM(input_bytes)/1024/1024/1024,2) || ',' ||
    TO_CHAR(MAX(end_time), 'YYYY-MM-DD HH24:MI:SS') || ',' ||
    'TYPE,STATUS,COUNT,SIZE_GB,LAST_BACKUP'
FROM v$rman_backup_job_details
WHERE start_time > SYSDATE - 30
GROUP BY input_type, status;

PROMPT
PROMPT [19] SECURITY AND ENCRYPTION
PROMPT =================================================================
-- Encryption Status
SELECT 
    'ENCRYPTION,' ||
    con_id || ',' ||
    pdb_name || ',' ||
    wrl_type || ',' ||
    wrl_parameter || ',' ||
    status
FROM v$encryption_wallet;

-- Audit Configuration
SELECT 
    'AUDIT_CONFIG,' ||
    parameter || ',' ||
    value
FROM v$parameter
WHERE name LIKE '%audit%'
AND value IS NOT NULL;

PROMPT
PROMPT [20] NETWORK AND CONNECTIVITY
PROMPT =================================================================
-- Listener Status
SELECT 
    'LISTENER_INFO,' ||
    name || ',' ||
    protocol || ',' ||
    host || ',' ||
    port || ',' ||
    status
FROM v$listener_network
WHERE status = 'READY';

PROMPT
PROMPT [21] LICENSING ASSESSMENT
PROMPT =================================================================
-- CPU Count for Licensing
SELECT 
    'LICENSING,' ||
    'CPU_COUNT' || ',' ||
    value || ',' ||
    'Used for Oracle Processor Licensing'
FROM v$parameter 
WHERE name = 'cpu_count';

-- Core Count
SELECT 
    'LICENSING,' ||
    'CORE_COUNT' || ',' ||
    value || ',' ||
    'Physical CPU Cores'
FROM v$osstat 
WHERE stat_name = 'NUM_CPU_CORES';

PROMPT
PROMPT [22] GROWTH ANALYSIS
PROMPT =================================================================
-- Database Growth (Last 30 Days)
SELECT 
    'GROWTH_ANALYSIS,' ||
    TO_CHAR(end_interval_time, 'YYYY-MM-DD') || ',' ||
    ROUND(SUM(space_used_total)/1024/1024/1024,2) || ',' ||
    'DATE,SIZE_GB'
FROM dba_hist_seg_stat s, dba_hist_snapshot sn
WHERE s.snap_id = sn.snap_id
AND sn.end_interval_time > SYSDATE - 30
GROUP BY TO_CHAR(end_interval_time, 'YYYY-MM-DD')
ORDER BY TO_CHAR(end_interval_time, 'YYYY-MM-DD') DESC;

PROMPT
PROMPT =================================================================
PROMPT ASSESSMENT COMPLETE
SELECT 'Report generated: ' || TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') FROM DUAL;
PROMPT =================================================================

SPOOL OFF

-- Generate AWR Report for the last 7 days
PROMPT Generating AWR Reports...
SET TERM ON
SET PAGESIZE 50
SET LINESIZE 150

-- Get snapshot IDs for last 7 days
COLUMN begin_snap NEW_VALUE begin_snap
COLUMN end_snap NEW_VALUE end_snap

SELECT MIN(snap_id) begin_snap, MAX(snap_id) end_snap
FROM dba_hist_snapshot
WHERE end_interval_time BETWEEN SYSDATE - 7 AND SYSDATE;

-- Generate AWR report
SPOOL &output_dir/awr_report.html
SELECT output FROM TABLE(
    DBMS_WORKLOAD_REPOSITORY.AWR_REPORT_HTML(
        (SELECT dbid FROM v$database),
        (SELECT instance_number FROM v$instance),
        &begin_snap,
        &end_snap
    )
);
SPOOL OFF

-- Generate ASH Report
SPOOL &output_dir/ash_report.html
SELECT output FROM TABLE(
    DBMS_WORKLOAD_REPOSITORY.ASH_REPORT_HTML(
        (SELECT dbid FROM v$database),
        (SELECT instance_number FROM v$instance),
        SYSDATE - 1,
        SYSDATE
    )
);
SPOOL OFF

SET TERM ON
SET FEEDBACK ON
SET HEADING ON

PROMPT
PROMPT =================================================================
PROMPT EXADATA ASSESSMENT COMPLETE!
PROMPT =================================================================
PROMPT Files generated:
PROMPT 1. &output_dir/exadata_assessment_report.txt - Main assessment data
PROMPT 2. &output_dir/awr_report.html - AWR Performance Report
PROMPT 3. &output_dir/ash_report.html - ASH Analysis Report
PROMPT =================================================================
PROMPT Next Steps:
PROMPT 1. Review the generated reports
PROMPT 2. Analyze performance patterns and resource usage
PROMPT 3. Plan target Oracle Database@Azure configuration
PROMPT 4. Develop migration strategy and timeline
PROMPT =================================================================
