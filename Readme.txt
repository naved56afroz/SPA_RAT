Stage code : ${CUR_DIR}/spa_replay_v5.sh ${CUR_DIR}/orcl/orascripts_v10.env [ ${CUR_DIR} = Your choice any dir]

Trigger Cature :

sh spa_replay_v5.sh -s orcl11204 -t orcl19800 -T 10.64.98.128 -m CAPTURE -u SYSTEM -g MYSTS2 -d 10 -i 1 -a -c  "parsing_schema_name not like ''%ADW%'' and parsing_schema_name not like ''%EXA%''"

Trigger Replay :

scp -r oracle@celvpvm09104.us.oracle.com:/refresh/home/acs/data/oracle/logs/rat/* .
 
sh spa_replay_v5.sh -t orcl19800 -T 10.64.98.128 -m REPLAY

-s source tns 
-t target tns
-T target IP
-m run mode   <CAPTURE/REPLAY>  * incaps
-u user       <SYSTEM>          * must have necessary privileges to run RAT (STS+STA+SPA+CAP+REP)
-g STS NAME
-d duration in minutes
-i STS capture interval in minutes
-a generate report
-c filter clause for sts capture

Create Load : open multiple sqldev session and run load profile present in Create Load Manual directory


#----------------- HLL -------------------------------------------------------------------------------
Prerequesites : Source TNS, Target TNS,  
--- duration , schema_list , Mount point to captured RAT files , shared NFS


Section 1.
-- Source 
#--1)		Create the SQL Tuning Set (STS) and capture for all nodes (* while Sample workload running )
#--1.1) 	Capture Workload for RAT= SPA + REPLAY
#--2)		Merge STS for all nodes
#--3)		Load->Stage->Pack in older version  
#--4.2)		Export->Import->UnPack STS in Target # Via DBLINK since Source and Target is provided # 
#--4.2.1)	Import the STS in Target
#--4.2.2)	Unpack the STS in Target
#--1.2)		Transfer RAT capture files to target   (* if NFS is not shared ONE TOUCH )
#--5)   	SPA: Create->Convert->Execute->Compare
#--5.1)   	SPA: Generate Reports

Section 2.

-- Target 
 STEP#1 copy the capture files to target and perform the Physical directory comparision
 STEP#2.1  Create GRP for CYCLE 1 
 STEP#3  -- Give a new name for Replay_name and check new replay_ID --> REPLAY_DBNAMEPERF_CYC1_13MAY_T1
 STEP#4 --> critical steps.
 Step#4A:  - verify replay_conn is null 
 Look for the latest conn_id and this is the connection id you must be using in step#4B. The conn_id will change when we process the capture, so 
 Step#4B:
 STEP#5 -- Verify remapping. replay_conn column should have updated values of cloned environment.
 STEP#6 
 STEP#7
 STEP#8 -- debug=on (no debug) it will generate trace 
 open number of putty client sessions on different cluster other than the cluster where cloned database is running(recommended from step#7 - this example recommends to use 1 clients ...see below pasted output of wrc mode)
 STEP#9

-- Enhancements :

SIngle script - merge spa+replay script with different options
Add option to add filter for replay
Replay script can also be run from source and target both 
preq: shred NFS , if not then manually transfer the files
** Do not display spooled reports 
** connection remap

#--6) 		Build a subset of the regressed SQL statements as a SQL tuning set
-- 				Splitting STS subsets into multiple sets based on Elapsed timings of SQLs
-- 				Split based on specific SQL-IDs
-- 			Build a set of statements that are UNSUPPORTED


#--7) 		Run STA - SQL Tuning Advisor only on the regressed subset and review the recommendations

#----------------------------------- END ---------------------------------------------------------------
