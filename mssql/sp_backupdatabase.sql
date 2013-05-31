USE [master]
GO

/****** Object:  StoredProcedure [dbo].[sp_backupdatabase]    Script Date: 05/31/2013 11:37:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER proc [dbo].[sp_backupdatabase]
 @bak_path nvarchar(4000)=''       --备份路径;
,@baktype int = null               --备份类型为全备,1为差异备,2为日志备份
,@type int = null                  --设置需要备份的库,0为全部库,1为系统库,2为全部用户库,3为指定库,4为排除指定库;
,@dbnames nvarchar(4000)=''        --需要备份或排除的数据库，用,隔开，当@type=3或4时生效
,@overdueDay int = null            --设置过期天数，默认天;
,@compression int =0               --0为否,1为采用压缩
,@prefix nvarchar(1000)=''         --备份文件名前缀
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
-- 使用rar压缩标记
declare @rarcompression int =0
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

--判断是否支持压缩
if @compression=1 
	if charindex('2008',@@version)=0 or charindex('Enterprise',@@version)=0
	begin
	    set @rarcompression = 1
		print('MSSQL引擎非2008企业版将使用rar进行压缩')
	end
	else
	begin
	    set @rarcompression =0
	    print(N'MSSQL引擎为2008企业版，将使用内部驱动进行压缩')
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
declare @bak_sql nvarchar(max),@del_sql nvarchar(max),@i int,@maxid int,@rar_cmd nvarchar(max),@bakfile nvarchar(max)
declare @dirtree_1 table (id int identity(1,1) primary key,subdirectory nvarchar(600),depth int,files int)
declare @dirtree_2 table (id int identity(1,1) primary key,subdirectory nvarchar(600),depth int,files int,
dbname varchar(300),baktime datetime,isLastbak int)
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
insert into @dirtree_1 exec('master.dbo.xp_dirtree '''+@bak_path+''',0,1')
select @createfolder=isnull(@createfolder,'')+'exec master.dbo.xp_cmdshell ''md '+@bak_path+''+name+''',no_output '+char(13)
from @t as a left join @dirtree_1 as b on a.name=b.subdirectory and b.files=0 and depth=1 where  b.id is null
--获取需要创建的文件夹-------------------end


--生成处理过期备份的sql语句-------------start
if @overdueDay>0
begin
	insert into @dirtree_2(subdirectory,depth,files) exec('master.dbo.xp_dirtree '''+@bak_path+''',0,1')
	if @baktype =0 
	delete from @dirtree_2 where depth=1 or files=0 or charindex('_Full_bak_',subdirectory)=0 
	if @baktype =1 
	delete from @dirtree_2 where depth=1 or files=0 or charindex('_Diff_bak_',subdirectory)=0 
	if @baktype=2
	delete from @dirtree_2 where depth=1 or files=0 or charindex('_Log_bak_',subdirectory)=0 
	if exists(select 1 from @dirtree_2)
	delete from @dirtree_2 where isdate(
			left(right(subdirectory,19),8)+' '+ substring(right(subdirectory,20),11,2) + ':' +  
			substring(right(subdirectory,20),13,2) +':'+substring(right(subdirectory,20),15,2) 
			)=0
	if exists(select 1 from @dirtree_2)
	update @dirtree_2 set dbname = case when @baktype=0 then left(subdirectory,charindex('_Full_bak_',subdirectory)-1)
		when @baktype=1 then left(subdirectory,charindex('_Diff_bak_',subdirectory)-1) 
		when @baktype=2 then left(subdirectory,charindex('_Log_bak_',subdirectory)-1) 
		else '' end	
		,baktime=left(right(subdirectory,19),8)+' '+ substring(right(subdirectory,20),11,2) + ':' +  
			substring(right(subdirectory,20),13,2) +':'+substring(right(subdirectory,20),15,2) 
	from @dirtree_2 as a
	delete @dirtree_2 from @dirtree_2 as a left join @t as b on b.name=a.dbname where b.id is null
	update @dirtree_2 set isLastbak= case when (select max(baktime) from @dirtree_2 where dbname=a.dbname)=baktime 
	then 1 else 0 end from @dirtree_2 as a
	select @delbak=isnull(@delbak,'')+'exec master.dbo.xp_cmdshell ''del '+@bak_path+''+dbname+'\'
	+subdirectory+''',no_output '+char(13) from @dirtree_2 where isLastbak=0 and datediff(day,baktime,getdate())>@overdueDay
end
--生成处理过期备份的sql语句--------------end




begin try
    exec( 'exec master.dbo.xp_cmdshell ''md c:\dba\logs\backup\''' )
	print(@createfolder)  --创建备份所需文件夹
	exec(@createfolder)   --创建备份所需文件夹
end try
begin catch
	print 'err:'+ltrim(error_number())
	print 'err:'+error_message()
	return
end catch


select @i=1 ,@maxid=max(id) from @t
while @i<=@maxid
begin
    select @bakfile=@prefix + 
                     case when RIGHT(ISNULL(@prefix,''),1) = '_' then '' else '_' end +
                     'mssql_backup_'+ Name + '_' +
                     replace(replace(replace(convert(varchar(20),getdate(),120),'-',''),' ','_'),':','') +
                     case when @baktype=0 then '_full_' 
                          when @baktype=1 then '_diff_' 
			              when @baktype=2 then '_logs_' 
			              else null end + 
			         case when @compression=1 and @rarcompression <> 1 then 'compr' 
			              else '' end +
			         case when @baktype=2 then '.trn' 
			              when @baktype=1 then '.dif' 
			              else '.bak' end 
    from @t where id=@i
	select @bak_sql='backup '+ case when @baktype=2 then 'log ' else 'database ' end
			+ quotename(Name)+' to disk='''+ @bak_path + @bakfile +'''' 
			+ case when @compression=1 or @baktype=1 then ' with ' else '' end
			+ case when @compression=1 and @rarcompression=0 then 'compression,' else '' end
			+ case when @baktype=1 then 'differential,' else '' end
			+ case when @compression=1 or @baktype=1 then ' noformat' else '' end 
		  ,@rar_cmd='exec master.dbo.xp_cmdshell ''' 
		            + 'rar.exe a -r -k -ep '  
		            + ' "' + @bak_path + @bakfile + '.rar"' 
		            + ' "' + @bak_path + @bakfile +'" ' 
		       --     + '>> "c:\dba\logs\backup\' + @prefix + '_' + name +'.txt"'
		            + ''''
	from @t where id=@i
	set @i=@i+1
	begin try
		print(@bak_sql)--循环执行备份
		exec(@bak_sql) --循环执行备份
		--if @rarcompression =0
		print(@rar_cmd)
		exec(@rar_cmd) --压缩备份文件
	end try
	begin catch
		print 'err:'+ltrim(error_number())
		print 'err:'+error_message()
	end catch
end

begin try
	print(@delbak)   --删除超期的备份
	exec(@delbak)    --删除超期的备份
end try
begin catch
	print 'err:'+ltrim(error_number())
	print 'err:'+error_message()
end catch


--关闭xp_cmdshell支持
--exec sp_configure 'show advanced options', 1
--reconfigure with override
--exec sp_configure 'xp_cmdshell', 1 
--reconfigure with override
--exec sp_configure 'show advanced options', 0
--reconfigure with override




GO


