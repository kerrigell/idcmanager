USE [master]
GO

/****** Object:  StoredProcedure [dbo].[sp_backupdatabase]    Script Date: 05/31/2013 11:37:59 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


ALTER proc [dbo].[sp_backupdatabase]
 @bak_path nvarchar(4000)=''       --����·��;
,@baktype int = null               --��������Ϊȫ��,1Ϊ���챸,2Ϊ��־����
,@type int = null                  --������Ҫ���ݵĿ�,0Ϊȫ����,1Ϊϵͳ��,2Ϊȫ���û���,3Ϊָ����,4Ϊ�ų�ָ����;
,@dbnames nvarchar(4000)=''        --��Ҫ���ݻ��ų������ݿ⣬��,��������@type=3��4ʱ��Ч
,@overdueDay int = null            --���ù���������Ĭ����;
,@compression int =0               --0Ϊ��,1Ϊ����ѹ��
,@prefix nvarchar(1000)=''         --�����ļ���ǰ׺
as
--sql server 2005/2008����/ɾ�����ڱ���T-sql �汾v1.0
/*
author:perfectaction
date  :2009.04
desc  :������sql2005/2008���ݣ��Զ����ɿ��ļ��У������Զ��屸�����ͺͱ��ݿ�����
	  �����Զ��屸�ݹ��ڵ�����
              ɾ�����ڱ��ݹ��ܲ���ɾ�����һ�α��ݣ������Ѿ�����
              ���ĳ�ⲻ�ٱ��ݣ���ôҲ������ɾ��֮ǰ���ڵı��� 
       ���д�����ָ����лл.
*/

set nocount on
--����xp_cmdshell֧��
exec sp_configure 'show advanced options', 1
reconfigure with override
exec sp_configure 'xp_cmdshell', 1 
reconfigure with override
exec sp_configure 'show advanced options', 0
reconfigure with override
print char(13)+'------------------------'
-- ʹ��rarѹ�����
declare @rarcompression int =0
--�ж��Ƿ���д·��
if isnull(@bak_path,'')=''
	begin
		print('error:��ָ������·��')
		return 
	end

--�ж��Ƿ�ָ����Ҫ���ݵĿ�
if isnull(ltrim(@baktype),'')=''
	begin
		print('error:��ָ����������aa:0Ϊȫ��,1Ϊ���챸,2Ϊ��־����')
		return 
	end
else
	begin
		if @baktype not between 0 and 2
		begin
			print('error:ָ����������ֻ��Ϊ,1,2:  0Ϊȫ��,1Ϊ���챸,2Ϊ��־����')
			return 
		end
	end
--�ж��Ƿ�ָ����Ҫ���ݵĿ�
if isnull(ltrim(@type),'')=''
	begin
		print('error:��ָ����Ҫ���ݵĿ�,0Ϊȫ����,1Ϊϵͳ��,2Ϊȫ���û���,3Ϊָ����,4Ϊ�ų�ָ����')
		return 
	end
else
	begin
		if @type not between 0 and 4
		begin
			print('error:��ָ����Ҫ���ݵĿ�,0Ϊȫ����,1Ϊϵͳ��,2Ϊȫ���û���,3Ϊָ����,4Ϊ�ų�ָ����')
			return 
		end
	end

--�ж�ָ������ų���ʱ���Ƿ���д����
if @type>2
	if @dbnames=''
	begin
		print('error:��������Ϊ'+ltrim(@type)+'ʱ����Ҫָ��@dbnames����')
		return 
	end

--�ж�ָ��ָ������ʱ��
if isnull(ltrim(@overdueDay),'')=''
begin
	print('error:����ָ�����ݹ���ʱ��,��λΪ��,0Ϊ��������')
	return 
end

--�ж��Ƿ�֧��ѹ��
if @compression=1 
	if charindex('2008',@@version)=0 or charindex('Enterprise',@@version)=0
	begin
	    set @rarcompression = 1
		print('MSSQL�����2008��ҵ�潫ʹ��rar����ѹ��')
	end
	else
	begin
	    set @rarcompression =0
	    print(N'MSSQL����Ϊ2008��ҵ�棬��ʹ���ڲ���������ѹ��')
	end

--�ж��Ƿ���ڸô���
declare @drives table(drive varchar(1),[size] varchar(20))
insert into @drives exec('master.dbo.xp_fixeddrives')
if not exists(select 1 from @drives where drive=left(@bak_path,1))
	begin
		print('error:�����ڸô���:'+left(@bak_path,1))
		return 
	end

--��ʽ������
select @bak_path=rtrim(ltrim(@bak_path)),@dbnames=rtrim(ltrim(@dbnames))
if right(isnull(@bak_path,''),1)!='\' set @bak_path=@bak_path+'\'
if isnull(@dbnames,'')!='' set @dbnames = ','+@dbnames+','
set @dbnames=replace(@dbnames,' ','')

--�������
declare @bak_sql nvarchar(max),@del_sql nvarchar(max),@i int,@maxid int,@rar_cmd nvarchar(max),@bakfile nvarchar(max)
declare @dirtree_1 table (id int identity(1,1) primary key,subdirectory nvarchar(600),depth int,files int)
declare @dirtree_2 table (id int identity(1,1) primary key,subdirectory nvarchar(600),depth int,files int,
dbname varchar(300),baktime datetime,isLastbak int)
declare @createfolder nvarchar(max),@delbackupfile nvarchar(max),@delbak nvarchar(max)

--��ȡ��Ҫ���ݵĿ���--------------------start
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
--��ȡ��Ҫ���ݵĿ���---------------------end

--��ȡ��Ҫ�������ļ���------------------start
insert into @dirtree_1 exec('master.dbo.xp_dirtree '''+@bak_path+''',0,1')
select @createfolder=isnull(@createfolder,'')+'exec master.dbo.xp_cmdshell ''md '+@bak_path+''+name+''',no_output '+char(13)
from @t as a left join @dirtree_1 as b on a.name=b.subdirectory and b.files=0 and depth=1 where  b.id is null
--��ȡ��Ҫ�������ļ���-------------------end


--���ɴ�����ڱ��ݵ�sql���-------------start
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
--���ɴ�����ڱ��ݵ�sql���--------------end




begin try
    exec( 'exec master.dbo.xp_cmdshell ''md c:\dba\logs\backup\''' )
	print(@createfolder)  --�������������ļ���
	exec(@createfolder)   --�������������ļ���
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
		print(@bak_sql)--ѭ��ִ�б���
		exec(@bak_sql) --ѭ��ִ�б���
		--if @rarcompression =0
		print(@rar_cmd)
		exec(@rar_cmd) --ѹ�������ļ�
	end try
	begin catch
		print 'err:'+ltrim(error_number())
		print 'err:'+error_message()
	end catch
end

begin try
	print(@delbak)   --ɾ�����ڵı���
	exec(@delbak)    --ɾ�����ڵı���
end try
begin catch
	print 'err:'+ltrim(error_number())
	print 'err:'+error_message()
end catch


--�ر�xp_cmdshell֧��
--exec sp_configure 'show advanced options', 1
--reconfigure with override
--exec sp_configure 'xp_cmdshell', 1 
--reconfigure with override
--exec sp_configure 'show advanced options', 0
--reconfigure with override




GO


