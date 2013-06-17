USE [master]
GO

/****** Object:  StoredProcedure [dbo].[usp_dba_backupdatabase]    Script Date: 06/29/2013 17:12:00 ******/
IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[usp_dba_backupdatabase]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[usp_dba_backupdatabase]
GO

USE [master]
GO

/****** Object:  StoredProcedure [dbo].[usp_dba_backupdatabase]    Script Date: 06/29/2013 17:12:00 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





CREATE proc [dbo].[usp_dba_backupdatabase]
 @bak_path nvarchar(4000)=''       --备份路径;
,@baktype int = null               --备份类型为全备,1为差异备,2为日志备份
,@type int = null                  --设置需要备份的库,0为全部库,1为系统库,2为全部用户库,3为指定库,4为排除指定库;
,@dbnames nvarchar(4000)=''        --需要备份或排除的数据库，用,隔开，当@type=3或4时生效
,@overdueDay int = null            --设置过期天数，默认天;
,@compression int =0               --0为否,1为采用压缩
,@prefix nvarchar(1000)=''         --备份文件名前缀
,@md5 int =0                       --计算MD5
as
--sql server 2005/2008备份/删除过期备份T-sql 版本v1.0
/*
author:perfectaction
date  :2009.04
desc  :适用于sql2005/2008备份，自动生成库文件夹，可以自定义备份类型和备份库名等
	  可以自定义备份过期的天数
              删除过期备份功能不会删除最后一次备份，哪怕已经过期
              如果某库不再备份，那么也不会再删除之前过期的备份 
       如有错误请指正，谢谢.
*/

set nocount on
--开启xp_cmdshell支持
exec sp_configure 'show advanced options', 1
reconfigure with override
exec sp_configure 'xp_cmdshell', 1 
reconfigure with override
exec sp_configure 'show advanced options', 0
reconfigure with override
print char(13)+'------------------------'
--判断是否填写路径
if isnull(@bak_path,'')=''
	begin
		print('error:请指定备份路径')
		return 
	end

--判断是否指定需要备份的库
if isnull(ltrim(@baktype),'')=''
	begin
		print('error:请指定备份类型aa:0为全备,1为差异备,2为日志备份')
		return 
	end
else
	begin
		if @baktype not between 0 and 2
		begin
			print('error:指定备份类型只能为,1,2:  0为全备,1为差异备,2为日志备份')
			return 
		end
	end
--判断是否指定需要备份的库
if isnull(ltrim(@type),'')=''
	begin
		print('error:请指定需要备份的库,0为全部库,1为系统库,2为全部用户库,3为指定库,4为排除指定库')
		return 
	end
else
	begin
		if @type not between 0 and 4
		begin
			print('error:请指定需要备份的库,0为全部库,1为系统库,2为全部用户库,3为指定库,4为排除指定库')
			return 
		end
	end

--判断指定库或排除库时，是否填写库名
if @type>2
	if @dbnames=''
	begin
		print('error:备份类型为'+ltrim(@type)+'时，需要指定@dbnames参数')
		return 
	end

--判断指定指定过期时间
if isnull(ltrim(@overdueDay),'')=''
begin
	print('error:必须指定备份过期时间,单位为天,0为永不过期')
	return 
end


--判断是否存在该磁盘
declare @drives table(drive varchar(1),[size] varchar(20))
insert into @drives exec('master.dbo.xp_fixeddrives')
if not exists(select 1 from @drives where drive=left(@bak_path,1))
	begin
		print('error:不存在该磁盘:'+left(@bak_path,1))
		return 
	end

--格式化参数
select @bak_path=rtrim(ltrim(@bak_path)),@dbnames=rtrim(ltrim(@dbnames))
if right(isnull(@bak_path,''),1)!='\' set @bak_path=@bak_path+'\'
if isnull(@dbnames,'')!='' set @dbnames = ','+@dbnames+','
set @dbnames=replace(@dbnames,' ','')

--定义变量
declare @bak_sql nvarchar(max),@del_sql nvarchar(max),@i int,@maxid int,@bak_cmd nvarchar(max),@bakfile nvarchar(max),@md5_cmd nvarchar(max)
declare @dirtree_1 table (id int identity(1,1) primary key,subdirectory nvarchar(600),depth int,files int)
declare @createfolder nvarchar(max),@delbackupfile nvarchar(max),@delbak nvarchar(max)

--获取需要备份的库名--------------------start
declare @t table(id int identity(1,1) primary key,name nvarchar(max))
declare @sql nvarchar(max)
set @sql = 'select name from sys.databases where state=0 and name!=''tempdb''  '
	+ case when @baktype=2 then ' and recovery_model!=3 ' else '' end
	+ case @type when 0 then 'and 1=1'
		when 1 then 'and database_id<=4'
		when 2 then 'and database_id>4'
		when 3 then 'and charindex('',''+Name+'','','''+@dbnames+''')>0'
		when 4 then 'and charindex('',''+Name+'','','''+@dbnames+''')=0 and database_id>4'
		else '1>2' end
insert into @t exec(@sql)
--获取需要备份的库名---------------------end

--获取需要创建的文件夹------------------start
--insert into @dirtree_1 exec('master.dbo.xp_dirtree '''+@bak_path+''',0,1')
--select @createfolder=isnull(@createfolder,'')+'exec master.dbo.xp_cmdshell ''md '+@bak_path+''+name+''',no_output '+char(13)
--from @t as a left join @dirtree_1 as b 
--on a.name=b.subdirectory and b.files=0 and depth=1 
--where  b.id is null
--获取需要创建的文件夹-------------------end




--生成处理过期备份的sql语句-------------start

--生成处理过期备份的sql语句--------------end

begin try
    exec( 'exec master.dbo.xp_cmdshell ''md c:\dba\logs\backup\''' )
	--print(@createfolder)  --创建备份所需文件夹
	--exec(@createfolder)   --创建备份所需文件夹
end try
begin catch
	print 'err:'+ltrim(error_number())
	print 'err:'+error_message()
	return
end catch

--获取机器ip B段信息
declare @ip nvarchar(20)=''
if exists (select * from dbo.sysobjects where id = object_id(N'[dbo].[usp_dba_getmachineip]') and OBJECTPROPERTY(id, N'IsProcedure') = 1)
begin
    declare @lip nvarchar(50)='',@rip nvarchar(50)=''
    exec [dbo].[usp_dba_getmachineip] @rip output
    set @lip=@lip + LEFT(@rip,charindex('.',@rip))
    set @rip=right(@rip,len(@rip)-charindex('.',@rip))
    set @lip=@lip + LEFT(@rip,charindex('.',@rip))
    set @rip=right(@rip,len(@rip)-charindex('.',@rip))
    set @ip =@ip + @rip
end

declare @dbname nvarchar(200)=''
declare @strdate nvarchar(200)
set @strdate = replace(replace(replace(convert(varchar(20),getdate(),120),'-',''),' ','_'),':','')
set @strdate = LEFT(@strdate,len(@strdate)-2)
select @i=1 ,@maxid=max(id) from @t
while @i<=@maxid
begin
    select @dbname=Name from @t where id=@i
    if @prefix = ''
    begin
        if (EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[dba_dblist]') AND type in (N'U')))
           and
           (exists ( select * from dba_dblist where dbname= @dbname))
        begin
            select @prefix=region + '_' + product + '_' 
                 + case when groupnum is  null then groupname + '_'
                        else convert(nvarchar(20),groupnum) + '_' end
                 + case when @ip = '' then ''
                        else @ip end
                 + '_'
            from dba_dblist where dbname = @dbname
        end
    end
    else
        set @prefix=@prefix 
                    + case when RIGHT(ISNULL(@prefix,''),1) = '_' then '' else '_' end 
    


    select @bakfile= @prefix + 
                     'mssql_backup_'+ @dbname + '_' +
                     @strdate +
                     case when @baktype=0 then '_full' 
                          when @baktype=1 then '_diff' 
			              when @baktype=2 then '_log' 
			              else null end + 
			         case when @baktype=2 then '.trn' 
			              when @baktype=1 then '.dif' 
			              else '.bak' end, 
	        @bak_cmd='exec master.dbo.xp_cmdshell '''
	                + 'msbp backup db(database=' + @dbname
	                    + ';backuptype=' + case when @baktype =2 then 'log'
	                                            when @baktype =1 then 'differential'
	                                            else 'full' end
	                    + ';checksum'
	                    + ')'
	                    + ' ' + case when @compression =1 then 'zip64(level=6;filename='+ @bakfile +';)'
	                                 else null end + ' '
	                    + 'local(path="' + @bak_path + @bakfile + '.zip")'
	                    + '''',
	        @md5_cmd='exec master.dbo.xp_cmdshell '''
	                + 'md5sum ' + @bak_path + @bakfile + '.zip > ' + @bak_path + @bakfile + '.zip.md5'
	                + ''''			              


	set @i=@i+1
	begin try
		--print(@bak_sql)--循环执行备份
		--exec(@bak_sql) --循环执行备份
		--if @rarcompression =0
		print(@bak_cmd)
		exec(@bak_cmd) --压缩备份文件
		if @md5 =1
		begin
		    print(@md5_cmd)
		    exec(@md5_cmd)
		end
		--删除具有prefix和dbname特征的备份文件，保留最后一份，避免完全删除
        if @overdueDay>0
        begin
            declare @dirtree_2 table (
                id int identity(1,1) primary key,
                subdirectory nvarchar(600),
                depth int,
                files int,
                dbname varchar(300),
                baktime datetime,
                isLastbak int)
	        insert into @dirtree_2(subdirectory,depth,files) exec('master.dbo.xp_dirtree '''+@bak_path+''',0,1')
	        if @baktype =0 
	        delete from @dirtree_2 where depth>1 or files=0 or charindex('_full',subdirectory)=0 
	        if @baktype =1 
	        delete from @dirtree_2 where depth>1 or files=0 or charindex('_diff',subdirectory)=0 
	        if @baktype=2
	        delete from @dirtree_2 where depth>1 or files=0 or charindex('_log',subdirectory)=0 
	        if @prefix != ''
	            delete from @dirtree_2 where CHARINDEX(@prefix,subdirectory)=0
	        if @dbname != ''
	            delete from @dirtree_2 where charindex(@dbname,subdirectory)=0
	        if exists (select 1 from @dirtree_2)
	        begin
	            select * from @dirtree_2
	            update @dirtree_2 set dbname=@dbname,
	                                  baktime=SUBSTRING(subdirectory,len(@prefix+'mssql_backup_'+ @dbname + '_')+1,8)
	                                        + ' '
	                                        + SUBSTRING(subdirectory,len(@prefix+'mssql_backup_'+ @dbname + '_')+1+8 +1,2)
	                                        + ':'
	                                        + SUBSTRING(subdirectory,len(@prefix+'mssql_backup_'+ @dbname + '_')+1+8 +1 +2,2)
	                                        + ':00'
	           select * from @dirtree_2
	        end
            delete @dirtree_2 from @dirtree_2 as a left join @t as b on b.name=a.dbname where b.id is null
	        update @dirtree_2 set isLastbak= case when (select max(baktime) from @dirtree_2 where dbname=a.dbname)=baktime 
	        then 1 else 0 end from @dirtree_2 as a
	        select @delbak=isnull(@delbak,'')
	                     + ' del ' + @bak_path + subdirectory + ' &&'            
	        from @dirtree_2 where isLastbak=0 and datediff(day,baktime,getdate())>@overdueDay
	        set @delbak=LEFT(@delbak,len(@delbak)-2) 
	        print(@delbak)
	        set @delbak = 'exec master.dbo.xp_cmdshell '''
	                     + isnull(@delbak,'')
	                     + ''''
	                 --    + ',no_output'
	        print(@delbak)   --删除超期的备份
	        exec(@delbak)    --删除超期的备份
        end
	end try
	begin catch
		print 'err:'+ltrim(error_number())
		print 'err:'+error_message()
	end catch
end

--关闭xp_cmdshell支持
exec sp_configure 'show advanced options', 1
reconfigure with override
exec sp_configure 'xp_cmdshell', 1 
reconfigure with override
exec sp_configure 'show advanced options', 0
reconfigure with override
GO


