USE [ekvelb2]
GO
/****** Object:  User [nedopilm]    Script Date: 08/17/2010 13:58:33 ******/
CREATE USER [nedopilm] FOR LOGIN [nedopilm] WITH DEFAULT_SCHEMA=[dbo]
GO
/****** Object:  Table [dbo].[DOKANFS]    Script Date: 08/17/2010 13:58:34 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DOKANFS](
	[IDFILE] [int] IDENTITY(1,1) NOT NULL,
	[FILENAME] [varchar](255) NULL,
	[ISDIRECTORY] [bit] NULL,
	[CONTENT] [varbinary](max) NULL,
	[LastAccessTime] [datetime] NOT NULL,
	[LastWriteTime] [datetime] NOT NULL,
	[CreationTime] [datetime] NOT NULL,
	[Attributes] [bigint] NULL,
	[IsZipped] [bit] NULL,
	[IsEncrypted] [bit] NULL,
	[OriginalSize] [bigint] NULL,
	[Version] [int] NULL,
 CONSTRAINT [PK_DOKANFS] PRIMARY KEY CLUSTERED 
(
	[IDFILE] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
) ON [PRIMARY]
GO
SET ANSI_PADDING OFF
GO
CREATE UNIQUE NONCLUSTERED INDEX [IX_DOKANFS] ON [dbo].[DOKANFS] 
(
	[FILENAME] ASC,
	[Version] ASC
)WITH (PAD_INDEX  = OFF, STATISTICS_NORECOMPUTE  = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS  = ON, ALLOW_PAGE_LOCKS  = ON) ON [PRIMARY]
GO
/****** Object:  StoredProcedure [dbo].[WriteFile]    Script Date: 08/17/2010 13:58:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[WriteFile]
	(
	@filename varchar(255),
	@data varbinary(max),
	@IsZipped bit,
	@OriginalSize bigint
	)
	
AS
    declare @isVersioned int
    set @isVersioned = 0
    
	SET NOCOUNT ON
	if patindex('%.version',@filename) > 0 begin
	   set @filename = substring(@filename,1,patindex('%.version',@filename)-1)
	   set @isVersioned = 1
	   end
	   
    if 1=(select top 1 1 from DOKANFS where FILENAME = @filename and Version is null) begin
	   
	  	   /* get last version number and increment */
	    if @isVersioned = 1 begin	   
		   declare @version int
		   select @version = isnull(version,0) + 1
		   From DOKANFS
		   where FILENAME = @filename 
			 and isnull(Version,0) = (select MAX(isnull(version,0)) 
							  from DOKANFS 
							 where FILENAME = @filename)
		   
		   /* save current to version file */
		   insert into DOKANFS
		   (FILENAME,ISDIRECTORY,CONTENT,IsZipped,OriginalSize,CreationTime,IsEncrypted,LastAccessTime,LastWriteTime, Version)
		   select FILENAME,ISDIRECTORY,CONTENT,IsZipped,OriginalSize,CreationTime,IsEncrypted,LastAccessTime,LastWriteTime, @version
		   From DOKANFS
		   where FILENAME = @filename and Version is null
	       end
	   
	   /* update current context file */
	   update DOKANFS
	      set CONTENT = @data,
	          LastAccessTime = GetDate(),
	          LastWriteTime = GETDATE(),
	          OriginalSize = @OriginalSize,
	          isZipped = @IsZipped
	      where FILENAME = @filename and Version is null
	   end else begin
	   
   	   insert into DOKANFS(FILENAME,ISDIRECTORY,CONTENT,IsZipped, OriginalSize,CreationTime, LastAccessTime, LastWriteTime) 
   	   values(@filename,0,@data,@IsZipped,@OriginalSize, GetDate(), GetDate(), GetDate()) 
   	   
   	   end
	 
	RETURN
GO
/****** Object:  StoredProcedure [dbo].[ReadFile]    Script Date: 08/17/2010 13:58:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[ReadFile]
	
	(
	@filename varchar(255)
	)
	
AS

/*



exec ReadFile '\bc.JPG'

  
 */
 
	SET NOCOUNT ON
    

	
    SELECT DATALENGTH(CONTENT) as size, IsZipped, DOKANFS.CONTENT
	  from DOKANFS
	  where (filename +  
	 case when Version IS not null then '.'+cast(ISNULL(version,'') as varchar(10)) 
	 else ''
	 end) = @filename 
	
	RETURN
GO
/****** Object:  StoredProcedure [dbo].[MoveFile]    Script Date: 08/17/2010 13:58:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[MoveFile]
	
	(
	@filename varchar(255),
	@newname varchar(255),
	@replace bit
	)
	
AS
	/* SET NOCOUNT ON */
	
	if @replace = 0 begin
	   if 1=(select top 1 1 from DOKANFS where FILENAME = @newname) 
	      raiserror('File already exists',16,1)
	   end
	delete from dokanfs
	where filename = @newname and Version is null
	
	update dokanfs
	set filename = @newname
	where filename = @filename
	  and Version is null
	
	RETURN
GO
/****** Object:  StoredProcedure [dbo].[GetFileInformation]    Script Date: 08/17/2010 13:58:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[GetFileInformation]
	(
	@filename varchar(255) ,
	@IsDirectory  bit OUTPUT,
	@Length bigint OUTPUT,
	@LastAccessTime DateTime OUTPUT,
	@LastWriteTime DateTime OUTPUT,
	@CreationTime DateTime OUTPUT
	
	)
	
	/*
	declare @isdir bit
	declare @len bigint
	declare @La  datetime
	declare @lw  datetime
	declare @cr  datetime
	declare @file varchar(255)
	set @file = '\bc.JPG'
	exec GetFileInformation @file , @isdir out, @len out, @La out, @lw out, @cr out
	print @file
	print @cr
	
	*/
	
AS
	SET NOCOUNT ON 

	select @filename = [filename], @IsDirectory = isdirectory, @Length = IsNull(OriginalSize,DATALENGTH([CONTENT])),
	       @LastAccessTime = LastAccessTime, @LastWriteTime = LastWriteTime,
	       @CreationTime = CreationTime
	  from DOKANFS 
	 
	  
	where (filename +  
	 case when Version IS not null then '.'+cast(ISNULL(version,'') as varchar(10)) 
	 else ''
	 end) = @filename 
	 
	   
	
	RETURN
GO
/****** Object:  StoredProcedure [dbo].[FindFiles]    Script Date: 08/17/2010 13:58:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[FindFiles]
	(
	@filename varchar(255)
	)
	
AS
    /*
    exec FindFiles @filename = '\' 
    */
	SET NOCOUNT ON 
	
	if @filename = '\' set @filename = '\' else set @filename = @filename+'\'
	
	select filename, isdirectory, IsNull(OriginalSize,DATALENGTH([CONTENT])) as size, filename as fullfilename,
	       LastAccessTime,LastWriteTime,CreationTime
	  into #TEMP
	  from DOKANFS 
	 where (filename like @filename+'%' and FILENAME not like @filename+'%\%' and Version is null)
	
	/* all versions */
	declare @allVersion int
	select @allVersion = isnull(cast(content as int),0) from DOKANFS where FILENAME = '\'
	print @allVersion
	if @allVersion = 1 begin
	   select filename+ '.'+ cast(ISNULL(version,'0') as varchar(10)) as filename, 
	         isdirectory, 
	         IsNull(OriginalSize,DATALENGTH([CONTENT])) as size, 
	         filename+ '.'+ cast(ISNULL(version,'0') as varchar(10)) as fullfilename,
	         LastAccessTime,LastWriteTime,CreationTime
	  into #TEMP2
	  from DOKANFS 
	  where (filename like @filename+'%' and FILENAME not like @filename+'%\%' and Version is not null)
	  update #TEMP2 set filename = SUBSTRING(filename, CHARINDEX(@filename,filename)+LEN(@filename),255)
	  end
	
	
	update #TEMP set filename = SUBSTRING(filename, CHARINDEX(@filename,filename)+LEN(@filename),255)
	
	insert into #TEMP (filename, isdirectory,size,fullfilename,LastAccessTime,LastWriteTime,CreationTime) 
	       values ('.',1,0,'.',GETDATE(),GETDATE(),GETDATE())
	if @filename <> '\' 
	   insert into #TEMP (filename,isdirectory,size,fullfilename,LastAccessTime,LastWriteTime,CreationTime) 
	          values ('..',1,0,'..',GETDATE(),GETDATE(),GETDATE())
	
	if @allVersion = 1 begin
	   select * from #TEMP 
	   union
	   select * from #TEMP2
	   order by filename
	   
	   end else begin
	   
	   select * from #TEMP 
	   order by filename
	   end
	
	
	
	RETURN
GO
/****** Object:  StoredProcedure [dbo].[DeleteFile]    Script Date: 08/17/2010 13:58:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[DeleteFile]
	
	(
	@filename varchar(255)
	)
	
AS
    SET NOCOUNT ON 
    
    delete from DOKANFS where FILENAME like @filename+'%' and Version is null
    
    RETURN
GO
/****** Object:  StoredProcedure [dbo].[CreateDirectory]    Script Date: 08/17/2010 13:58:37 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CreateDirectory]
	
	(
	@filename varchar(255)
	)
	
AS
    SET NOCOUNT ON 
    insert into DOKANFS(FILENAME, ISDIRECTORY) VALUES (@Filename,1) 
	RETURN
GO
/****** Object:  Default [DF_DOKANFS_LastAccessTime]    Script Date: 08/17/2010 13:58:34 ******/
ALTER TABLE [dbo].[DOKANFS] ADD  CONSTRAINT [DF_DOKANFS_LastAccessTime]  DEFAULT (getdate()) FOR [LastAccessTime]
GO
/****** Object:  Default [DF_DOKANFS_LastWriteTime]    Script Date: 08/17/2010 13:58:34 ******/
ALTER TABLE [dbo].[DOKANFS] ADD  CONSTRAINT [DF_DOKANFS_LastWriteTime]  DEFAULT (getdate()) FOR [LastWriteTime]
GO
/****** Object:  Default [DF_DOKANFS_CreationTime]    Script Date: 08/17/2010 13:58:34 ******/
ALTER TABLE [dbo].[DOKANFS] ADD  CONSTRAINT [DF_DOKANFS_CreationTime]  DEFAULT (getdate()) FOR [CreationTime]
GO
/****** Object:  Default [DF_DOKANFS_IsZipped]    Script Date: 08/17/2010 13:58:34 ******/
ALTER TABLE [dbo].[DOKANFS] ADD  CONSTRAINT [DF_DOKANFS_IsZipped]  DEFAULT ((0)) FOR [IsZipped]
GO
/****** Object:  Default [DF_DOKANFS_IsEncrypted]    Script Date: 08/17/2010 13:58:34 ******/
ALTER TABLE [dbo].[DOKANFS] ADD  CONSTRAINT [DF_DOKANFS_IsEncrypted]  DEFAULT ((0)) FOR [IsEncrypted]
GO
