USE [master]
GO
/****** Object:  Database [JobPortalSR]    Script Date: 8/28/2020 10:24:17 PM ******/
CREATE DATABASE [JobPortalSR]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'JobPortalSR', FILENAME = N'D:\rdsdbdata\DATA\JobPortalSR.mdf' , SIZE = 5312KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'JobPortalSR_log', FILENAME = N'D:\rdsdbdata\DATA\JobPortalSR_log.ldf' , SIZE = 3200KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
ALTER DATABASE [JobPortalSR] SET COMPATIBILITY_LEVEL = 120
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [JobPortalSR].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [JobPortalSR] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [JobPortalSR] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [JobPortalSR] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [JobPortalSR] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [JobPortalSR] SET ARITHABORT OFF 
GO
ALTER DATABASE [JobPortalSR] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [JobPortalSR] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [JobPortalSR] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [JobPortalSR] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [JobPortalSR] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [JobPortalSR] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [JobPortalSR] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [JobPortalSR] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [JobPortalSR] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [JobPortalSR] SET  ENABLE_BROKER 
GO
ALTER DATABASE [JobPortalSR] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [JobPortalSR] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [JobPortalSR] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [JobPortalSR] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [JobPortalSR] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [JobPortalSR] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [JobPortalSR] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [JobPortalSR] SET RECOVERY FULL 
GO
ALTER DATABASE [JobPortalSR] SET  MULTI_USER 
GO
ALTER DATABASE [JobPortalSR] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [JobPortalSR] SET DB_CHAINING OFF 
GO
ALTER DATABASE [JobPortalSR] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [JobPortalSR] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE [JobPortalSR] SET DELAYED_DURABILITY = DISABLED 
GO
USE [JobPortalSR]
GO
/****** Object:  User [steeprise]    Script Date: 8/28/2020 10:24:20 PM ******/
CREATE USER [steeprise] FOR LOGIN [steeprise] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [steeprise]
GO
/****** Object:  UserDefinedFunction [dbo].[f_split]    Script Date: 8/28/2020 10:24:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[f_split]
(
@param NVARCHAR(MAX), 
@delimiter CHAR(1)
)
RETURNS @t TABLE (val NVARCHAR(MAX), seq INT)
AS
BEGIN
	SET @param += @delimiter

	;WITH A AS
	(
	SELECT CAST(1 AS BIGINT) f, CHARINDEX(@delimiter, @param) t, 1 seq
	UNION ALL
	SELECT t + 1, CHARINDEX(@delimiter, @param, t + 1), seq + 1
	FROM a
	WHERE CHARINDEX(@delimiter, @param, t + 1) > 0
	)
	INSERT @t
	SELECT SUBSTRING(@param, f, t - f), seq FROM a
	OPTION (maxrecursion 0)
	RETURN
END






GO
/****** Object:  UserDefinedFunction [dbo].[parseJSON]    Script Date: 8/28/2020 10:24:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[parseJSON]( @JSON NVARCHAR(MAX))
RETURNS @hierarchy TABLE
  (
   element_id INT IDENTITY(1, 1) NOT NULL, /* internal surrogate primary key gives the order of parsing and the list order */
   sequenceNo [int] NULL, /* the place in the sequence for the element */
   parent_ID INT,/* if the element has a parent then it is in this column. The document is the ultimate parent, so you can get the structure from recursing from the document */
   Object_ID INT,/* each list or object has an object id. This ties all elements to a parent. Lists are treated as objects here */
   NAME NVARCHAR(2000),/* the name of the object */
   StringValue NVARCHAR(MAX) NOT NULL,/*the string representation of the value of the element. */
   ValueType VARCHAR(10) NOT null /* the declared type of the value represented as a string in StringValue*/
  )
AS
BEGIN
  DECLARE
    @FirstObject INT, --the index of the first open bracket found in the JSON string
    @OpenDelimiter INT,--the index of the next open bracket found in the JSON string
    @NextOpenDelimiter INT,--the index of subsequent open bracket found in the JSON string
    @NextCloseDelimiter INT,--the index of subsequent close bracket found in the JSON string
    @Type NVARCHAR(10),--whether it denotes an object or an array
    @NextCloseDelimiterChar CHAR(1),--either a '}' or a ']'
    @Contents NVARCHAR(MAX), --the unparsed contents of the bracketed expression
    @Start INT, --index of the start of the token that you are parsing
    @end INT,--index of the end of the token that you are parsing
    @param INT,--the parameter at the end of the next Object/Array token
    @EndOfName INT,--the index of the start of the parameter at end of Object/Array token
    @token NVARCHAR(200),--either a string or object
    @value NVARCHAR(MAX), -- the value as a string
    @SequenceNo int, -- the sequence number within a list
    @name NVARCHAR(200), --the name as a string
    @parent_ID INT,--the next parent ID to allocate
    @lenJSON INT,--the current length of the JSON String
    @characters NCHAR(36),--used to convert hex to decimal
    @result BIGINT,--the value of the hex symbol being parsed
    @index SMALLINT,--used for parsing the hex value
    @Escape INT --the index of the next escape character
   
 
  DECLARE @Strings TABLE /* in this temporary table we keep all strings, even the names of the elements, since they are 'escaped' in a different way, and may contain, unescaped, brackets denoting objects or lists. These are replaced in the JSON string by tokens representing the string */
    (
     String_ID INT IDENTITY(1, 1),
     StringValue NVARCHAR(MAX)
    )
  SELECT--initialise the characters to convert hex to ascii
    @characters='0123456789abcdefghijklmnopqrstuvwxyz',
    @SequenceNo=0, --set the sequence no. to something sensible.
  /* firstly we process all strings. This is done because [{} and ] aren't escaped in strings, which complicates an iterative parse. */
    @parent_ID=0;
  WHILE 1=1 --forever until there is nothing more to do
    BEGIN
      SELECT
        @start=PATINDEX('%[^a-zA-Z]["]%', @json collate SQL_Latin1_General_CP850_Bin);--next delimited string
      IF @start=0 BREAK --no more so drop through the WHILE loop
      IF SUBSTRING(@json, @start+1, 1)='"'
        BEGIN --Delimited Name
          SET @start=@Start+1;
          SET @end=PATINDEX('%[^\]["]%', RIGHT(@json, LEN(@json+'|')-@start) collate SQL_Latin1_General_CP850_Bin);
        END
      IF @end=0 --no end delimiter to last string
        BREAK --no more
      SELECT @token=SUBSTRING(@json, @start+1, @end-1)
      --now put in the escaped control characters
      SELECT @token=REPLACE(@token, FROMString, TOString)
      FROM
        (SELECT
          '\"' AS FromString, '"' AS ToString
         UNION ALL SELECT '\\', '\'
         UNION ALL SELECT '\/', '/'
         UNION ALL SELECT '\b', CHAR(08)
         UNION ALL SELECT '\f', CHAR(12)
         UNION ALL SELECT '\n', CHAR(10)
         UNION ALL SELECT '\r', CHAR(13)
         UNION ALL SELECT '\t', CHAR(09)
        ) substitutions
      SELECT @result=0, @escape=1
  --Begin to take out any hex escape codes
      WHILE @escape>0
        BEGIN
          SELECT @index=0,
          --find the next hex escape sequence
          @escape=PATINDEX('%\x[0-9a-f][0-9a-f][0-9a-f][0-9a-f]%', @token collate SQL_Latin1_General_CP850_Bin)
          IF @escape>0 --if there is one
            BEGIN
              WHILE @index<4 --there are always four digits to a \x sequence  
                BEGIN
                  SELECT --determine its value
                    @result=@result+POWER(16, @index)
                    *(CHARINDEX(SUBSTRING(@token, @escape+2+3-@index, 1),
                                @characters)-1), @index=@index+1 ;
        
                END
                -- and replace the hex sequence by its unicode value
              SELECT @token=STUFF(@token, @escape, 6, NCHAR(@result))
            END
        END
      --now store the string away
      INSERT INTO @Strings (StringValue) SELECT @token
      -- and replace the string with a token
      SELECT @JSON=STUFF(@json, @start, @end+1,
                    '@string'+CONVERT(NVARCHAR(5), @@identity))
    END
  -- all strings are now removed. Now we find the first leaf. 
  WHILE 1=1  --forever until there is nothing more to do
  BEGIN
 
  SELECT @parent_ID=@parent_ID+1
  --find the first object or list by looking for the open bracket
  SELECT @FirstObject=PATINDEX('%[{[[]%', @json collate SQL_Latin1_General_CP850_Bin)--object or array
  IF @FirstObject = 0 BREAK
  IF (SUBSTRING(@json, @FirstObject, 1)='{')
    SELECT @NextCloseDelimiterChar='}', @type='object'
  ELSE
    SELECT @NextCloseDelimiterChar=']', @type='array'
  SELECT @OpenDelimiter=@firstObject
 
  WHILE 1=1 --find the innermost object or list...
    BEGIN
      SELECT
        @lenJSON=LEN(@JSON+'|')-1
  --find the matching close-delimiter proceeding after the open-delimiter
      SELECT
        @NextCloseDelimiter=CHARINDEX(@NextCloseDelimiterChar, @json,
                                      @OpenDelimiter+1)
  --is there an intervening open-delimiter of either type
      SELECT @NextOpenDelimiter=PATINDEX('%[{[[]%',
             RIGHT(@json, @lenJSON-@OpenDelimiter)collate SQL_Latin1_General_CP850_Bin)--object
      IF @NextOpenDelimiter=0
        BREAK
      SELECT @NextOpenDelimiter=@NextOpenDelimiter+@OpenDelimiter
      IF @NextCloseDelimiter<@NextOpenDelimiter
        BREAK
      IF SUBSTRING(@json, @NextOpenDelimiter, 1)='{'
        SELECT @NextCloseDelimiterChar='}', @type='object'
      ELSE
        SELECT @NextCloseDelimiterChar=']', @type='array'
      SELECT @OpenDelimiter=@NextOpenDelimiter
    END
  ---and parse out the list or name/value pairs
  SELECT
    @contents=SUBSTRING(@json, @OpenDelimiter+1,
                        @NextCloseDelimiter-@OpenDelimiter-1)
  SELECT
    @JSON=STUFF(@json, @OpenDelimiter,
                @NextCloseDelimiter-@OpenDelimiter+1,
                '@'+@type+CONVERT(NVARCHAR(5), @parent_ID))
  WHILE (PATINDEX('%[A-Za-z0-9@+.e]%', @contents collate SQL_Latin1_General_CP850_Bin))<>0
    BEGIN
      IF @Type='Object' --it will be a 0-n list containing a string followed by a string, number,boolean, or null
        BEGIN
          SELECT
            @SequenceNo=0,@end=CHARINDEX(':', ' '+@contents)--if there is anything, it will be a string-based name.
          SELECT  @start=PATINDEX('%[^A-Za-z@][@]%', ' '+@contents collate SQL_Latin1_General_CP850_Bin)--AAAAAAAA
          SELECT @token=SUBSTRING(' '+@contents, @start+1, @End-@Start-1),
            @endofname=PATINDEX('%[0-9]%', @token collate SQL_Latin1_General_CP850_Bin),
            @param=RIGHT(@token, LEN(@token)-@endofname+1)
          SELECT
            @token=LEFT(@token, @endofname-1),
            @Contents=RIGHT(' '+@contents, LEN(' '+@contents+'|')-@end-1)
          SELECT  @name=stringvalue FROM @strings
            WHERE string_id=@param --fetch the name
        END
      ELSE
        SELECT @Name=null,@SequenceNo=@SequenceNo+1
      SELECT
        @end=CHARINDEX(',', @contents)-- a string-token, object-token, list-token, number,boolean, or null
      IF @end=0
        SELECT  @end=PATINDEX('%[A-Za-z0-9@+.e][^A-Za-z0-9@+.e]%', @Contents+' ' collate SQL_Latin1_General_CP850_Bin)
          +1
       SELECT
         @start=PATINDEX('%[^A-Za-z0-9@+.e][A-Za-z0-9@+.e][\-]%', ' '+@contents collate SQL_Latin1_General_CP850_Bin)
		-- Edited: add more condition [\-] in order to detect negative number 08-20-2014
      --select @start,@end, LEN(@contents+'|'), @contents 
      SELECT
        @Value=RTRIM(SUBSTRING(@contents, @start, @End-@Start)),
        @Contents=RIGHT(@contents+' ', LEN(@contents+'|')-@end)
      IF SUBSTRING(@value, 1, 7)='@object'
        INSERT INTO @hierarchy
          (NAME, SequenceNo, parent_ID, StringValue, Object_ID, ValueType)
          SELECT @name, @SequenceNo, @parent_ID, SUBSTRING(@value, 8, 5),
            SUBSTRING(@value, 8, 5), 'object'
      ELSE
        IF SUBSTRING(@value, 1, 6)='@array'
          INSERT INTO @hierarchy
            (NAME, SequenceNo, parent_ID, StringValue, Object_ID, ValueType)
            SELECT @name, @SequenceNo, @parent_ID, SUBSTRING(@value, 7, 5),
              SUBSTRING(@value, 7, 5), 'array'
        ELSE
          IF SUBSTRING(@value, 1, 7)='@string'
            INSERT INTO @hierarchy
              (NAME, SequenceNo, parent_ID, StringValue, ValueType)
              SELECT @name, @SequenceNo, @parent_ID, stringvalue, 'string'
              FROM @strings
              WHERE string_id=SUBSTRING(@value, 8, 5)
          ELSE
            IF @value IN ('true', 'false')
              INSERT INTO @hierarchy
                (NAME, SequenceNo, parent_ID, StringValue, ValueType)
                SELECT @name, @SequenceNo, @parent_ID, @value, 'boolean'
            ELSE
              IF @value='null'
                INSERT INTO @hierarchy
                  (NAME, SequenceNo, parent_ID, StringValue, ValueType)
                  SELECT @name, @SequenceNo, @parent_ID, @value, 'null'
              ELSE
                IF PATINDEX('%[^0-9]%', @value collate SQL_Latin1_General_CP850_Bin)>0
                  INSERT INTO @hierarchy
                    (NAME, SequenceNo, parent_ID, StringValue, ValueType)
                    SELECT @name, @SequenceNo, @parent_ID, @value, 'real'
                ELSE
                  INSERT INTO @hierarchy
                    (NAME, SequenceNo, parent_ID, StringValue, ValueType)
                    SELECT @name, @SequenceNo, @parent_ID, @value, 'int'
      if @Contents=' ' Select @SequenceNo=0
    END
  END
INSERT INTO @hierarchy (NAME, SequenceNo, parent_ID, StringValue, Object_ID, ValueType)
  SELECT '-',1, NULL, '', @parent_id-1, @type
--
   RETURN
END





GO
/****** Object:  UserDefinedFunction [dbo].[udf_PivotParameters]    Script Date: 8/28/2020 10:24:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[udf_PivotParameters]

    (

      @ParamaterList VARCHAR(MAX),

      @Delimiter CHAR(1)

    )

RETURNS @ReturnList TABLE

    (

      FieldValue VARCHAR(MAX)

    )

AS BEGIN

    DECLARE @ArrayList TABLE

        (

          FieldValue VARCHAR(MAX)

        )

    DECLARE @Value VARCHAR(MAX)

    DECLARE @CurrentPosition INT

 

    SET @ParamaterList = LTRIM(RTRIM(@ParamaterList))

        + CASE WHEN RIGHT(@ParamaterList, 1) = @Delimiter THEN ''

               ELSE @Delimiter

          END

    SET @CurrentPosition = ISNULL(CHARINDEX(@Delimiter, @ParamaterList, 1), 0)

    IF @CurrentPosition = 0

        INSERT  INTO @ArrayList ( FieldValue )

                SELECT  @ParamaterList

    ELSE

        BEGIN

            WHILE @CurrentPosition > 0

                BEGIN

                    SET @Value = LTRIM(RTRIM(LEFT(@ParamaterList,

                                                  @CurrentPosition - 1))) --make sure a value exists between the delimiters

                    IF LEN(@ParamaterList) > 0

                        AND @CurrentPosition <= LEN(@ParamaterList)

                        BEGIN

                            INSERT  INTO @ArrayList ( FieldValue )

                                    SELECT  @Value

                        END

                    SET @ParamaterList = SUBSTRING(@ParamaterList,

                                                   @CurrentPosition

                                                   + LEN(@Delimiter),

                                                   LEN(@ParamaterList))

                    SET @CurrentPosition = CHARINDEX(@Delimiter,

                                                     @ParamaterList, 1)

                END

        END

    INSERT  @ReturnList ( FieldValue )

            SELECT  FieldValue

            FROM    @ArrayList

    RETURN

   END





GO
/****** Object:  UserDefinedFunction [dbo].[udf_Split]    Script Date: 8/28/2020 10:24:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-----------------------------------------------------------------------------------------------------------
-- Rev	| Date Modified	|	Developer    | Change Summary

-- 1	| 08-12-2020	| Rajesh P	 | Created
-----------------------------------------------------------------------------------------------------------
*/

CREATE FUNCTION [dbo].[udf_Split](@String VARCHAR(8000), @Delimiter CHAR(1))     
RETURNS @temptable TABLE (items VARCHAR(8000))     
AS     
BEGIN     
	DECLARE @idx INT     
	DECLARE @slice VARCHAR(8000)     
    
	SELECT @idx = 1     
		IF len(@String)<1 or @String is null  RETURN     
    
	WHILE @idx!= 0     
	BEGIN     
		SET @idx = charindex(@Delimiter,@String)     
		IF @idx!=0     
			SET @slice = left(@String,@idx - 1)     
		ELSE     
			SET @slice = @String     
		
		if(LEN(@slice)>0)
			INSERT INTO @temptable(Items) VALUES(@slice)     

		SET @String = right(@String,len(@String) - @idx)     
		IF len(@String) = 0 BREAK     
	END 
RETURN     
END




----------2-------------------


GO
/****** Object:  UserDefinedFunction [dbo].[UTC2Indian]    Script Date: 8/28/2020 10:24:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[UTC2Indian] (
  @UTCTime datetime)
RETURNS datetime
AS

BEGIN

  SET @UTCTime = DATEADD(mi, 330, @UTCTime)
  RETURN @UTCTime

END


GO
/****** Object:  Table [dbo].[AppliedJobs]    Script Date: 8/28/2020 10:24:21 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[AppliedJobs](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[JobPostId] [int] NULL,
	[AppliedDate] [date] NULL,
	[Status] [bit] NULL,
	[CreatedBy] [varchar](max) NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedBy] [varchar](max) NULL,
	[UpdatedDate] [datetime] NULL,
 CONSTRAINT [PK_appliedJobs] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[BulkJobPostSummary]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[BulkJobPostSummary](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[SerialNo] [int] NULL,
	[CompanyName] [varchar](250) NULL,
	[State] [varchar](70) NULL,
	[JobLocation] [varchar](70) NULL,
	[JobTitle] [varchar](200) NULL,
	[JobRole1] [varchar](150) NULL,
	[JobRole2] [varchar](150) NULL,
	[JobRole3] [varchar](150) NULL,
	[SPOC] [varchar](200) NULL,
	[SPOCEmail] [varchar](100) NULL,
	[SPOCContact] [varchar](15) NULL,
	[CTC] [varchar](50) NULL,
	[HiringCriteria] [varchar](max) NULL,
	[MinExp] [varchar](5) NULL,
	[MaxExp] [varchar](5) NULL,
	[JobType] [varchar](75) NULL,
	[JobDetails] [varchar](max) NULL,
	[FinancialYear] [varchar](10) NULL,
	[Quarter1] [int] NULL,
	[Quarter2] [int] NULL,
	[Quarter3] [int] NULL,
	[Quarter4] [int] NULL,
	[Total] [int] NULL,
	[ProcessedBy] [varchar](200) NULL,
	[ProcessedOn] [datetime] NULL,
	[Status] [varchar](25) NULL,
	[ErrorDetails] [varchar](max) NULL,
	[FileName] [varchar](500) NULL,
	[CreatedOn] [datetime] NULL DEFAULT (getdate()),
	[CreatedBy] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cities]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Cities](
	[CityCode] [nvarchar](15) NOT NULL,
	[Name] [nvarchar](50) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
	[StateCode] [nvarchar](5) NULL,
PRIMARY KEY CLUSTERED 
(
	[CityCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Countries]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Countries](
	[CountryCode] [nvarchar](5) NOT NULL,
	[Name] [nvarchar](50) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[CountryCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CourseCategories]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CourseCategories](
	[CategoryId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](25) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[CategoryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Courses]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Courses](
	[CourseId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](25) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
	[Category] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[CourseId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[CourseType]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CourseType](
	[CourseTypeId] [int] IDENTITY(1,1) NOT NULL,
	[Type] [nvarchar](25) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[CourseTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Designations]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Designations](
	[DesignationId] [int] IDENTITY(1,1) NOT NULL,
	[Abbr] [nvarchar](15) NULL,
	[Designation] [nvarchar](200) NULL,
	[IsActive] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[DesignationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[EmailQueue]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[EmailQueue](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[FromId] [int] NULL,
	[ToId] [int] NULL,
	[Subject] [nvarchar](1000) NULL,
	[Body] [nvarchar](3999) NULL,
	[IsReplied] [bit] NULL DEFAULT ((0)),
	[RepliedOn] [datetime] NULL,
	[CreatedBy] [int] NULL,
	[CreatedOn] [datetime] NULL DEFAULT (getdate()),
	[UpdatedBy] [int] NULL,
	[UpdatedOn] [datetime] NULL,
	[FromEmail] [varchar](72) NULL,
	[ToEmail] [varchar](72) NULL,
	[MailType] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[EmployerFollower]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmployerFollower](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[JobSeekerID] [int] NOT NULL,
	[EmployerID] [int] NOT NULL,
	[CreatedDate] [datetime] NULL,
	[IsActive] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[EmploymentStatus]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmploymentStatus](
	[EmploymentStatusId] [int] IDENTITY(1,1) NOT NULL,
	[EmploymentStatusName] [nvarchar](max) NULL,
	[Status] [bit] NULL,
	[CreatedBy] [nvarchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedBy] [nvarchar](50) NULL,
	[UpdatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[EmploymentStatusId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[EmploymentType]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[EmploymentType](
	[EmploymentTypeId] [int] IDENTITY(1,1) NOT NULL,
	[EmploymentTypeName] [nvarchar](max) NULL,
	[Status] [bit] NULL,
	[CreatedBy] [nvarchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedBy] [nvarchar](50) NULL,
	[UpdatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[EmploymentTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Gender]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Gender](
	[GenderId] [int] IDENTITY(1,1) NOT NULL,
	[GenderCode] [nvarchar](10) NULL,
	[Gender] [nvarchar](20) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[GenderId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[INSDMSUsers]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[INSDMSUsers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Email] [varchar](100) NULL,
	[Firstname] [varchar](200) NULL,
	[Lastname] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ITSkills]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[ITSkills](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Skill] [varchar](50) NULL,
	[SkillVersion] [varchar](50) NULL,
	[LastUsed] [varchar](10) NULL,
	[ExperienceYear] [varchar](10) NULL,
	[ExperienceMonth] [varchar](10) NULL,
	[CreatedDate] [datetime] NULL,
	[CreatedBy] [varchar](50) NULL,
	[UpdateDate] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[Status] [bit] NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[JobIndustryArea]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JobIndustryArea](
	[JobIndustryAreaId] [int] IDENTITY(1,1) NOT NULL,
	[JobIndustryAreaName] [nvarchar](max) NULL,
	[Status] [bit] NULL,
	[CreatedBy] [nvarchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedBy] [nvarchar](50) NULL,
	[UpdatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[JobIndustryAreaId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[JobPostDetail]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[JobPostDetail](
	[JobPostId] [int] IDENTITY(1,1) NOT NULL,
	[JobIndustryAreaId] [int] NULL,
	[CountryCode] [nvarchar](5) NULL,
	[StateCode] [nvarchar](5) NULL,
	[CityCode] [nvarchar](15) NULL,
	[EmploymentStatusId] [int] NULL,
	[EmploymentTypeId] [int] NULL,
	[Skills] [varchar](max) NULL,
	[MonthlySalary] [nvarchar](50) NULL,
	[NoPosition] [int] NULL,
	[Nationality] [nvarchar](10) NULL,
	[PositionStartDate] [nvarchar](50) NULL,
	[PositionEndDate] [nvarchar](50) NULL,
	[HiringCriteria] [nvarchar](max) NULL,
	[Status] [bit] NULL,
	[CreatedBy] [nvarchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedBy] [nvarchar](50) NULL,
	[UpdatedDate] [datetime] NULL,
	[JobType] [int] NULL,
	[Gender] [varchar](10) NULL,
	[JobDetails] [nvarchar](max) NULL,
	[UserId] [int] NULL,
	[SPOC] [varchar](50) NOT NULL,
	[SPOCEmail] [varchar](50) NOT NULL,
	[SPOCContact] [varchar](15) NOT NULL,
	[CTC] [varchar](50) NULL,
	[Quarter1] [int] NOT NULL,
	[Quarter2] [int] NOT NULL,
	[Quarter3] [int] NOT NULL,
	[Quarter4] [int] NOT NULL,
	[Featured] [bit] NOT NULL CONSTRAINT [DF_JobPostDetail_Featured]  DEFAULT ((0)),
	[JobTitleByEmployer] [nvarchar](255) NULL,
	[MinExperience] [int] NULL,
	[MaxExperience] [int] NULL,
	[FinancialYear] [int] NULL,
	[FeaturedJobDisplayOrder] [int] NULL,
	[IsFromBulkUpload] [bit] NULL DEFAULT ((0)),
	[OtherJobIndustryArea] [varchar](100) NULL,
	[IsWalkIn] [bit] NULL,
 CONSTRAINT [PK__JobPostD__57689C3A625A8D56] PRIMARY KEY CLUSTERED 
(
	[JobPostId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[JobRoleMapping]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JobRoleMapping](
	[MapId] [int] IDENTITY(1,1) NOT NULL,
	[JobId] [int] NULL,
	[JobRoleId] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[MapId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[JobTitle]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JobTitle](
	[JobTitleId] [int] IDENTITY(1,1) NOT NULL,
	[JobTitleName] [nvarchar](max) NULL,
	[Status] [bit] NULL DEFAULT ((1)),
	[CreatedBy] [nvarchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedBy] [nvarchar](50) NULL,
	[UpdatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[JobTitleId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
/****** Object:  Table [dbo].[JobTypes]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[JobTypes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Type] [varchar](50) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Logging]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Logging](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[LogType] [varchar](30) NULL,
	[Message] [varchar](500) NULL,
	[Data] [varchar](max) NULL,
	[Exception] [varchar](max) NULL,
	[AssemblyInfo] [varchar](200) NULL,
	[ClassInfo] [varchar](200) NULL,
	[CreatedDate] [datetime] NULL,
	[CreatedBy] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[MailType]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MailType](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Type] [nvarchar](50) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[MaritalStatus]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MaritalStatus](
	[StatusId] [int] IDENTITY(1,1) NOT NULL,
	[StatusCode] [nvarchar](10) NULL,
	[Status] [nvarchar](20) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
PRIMARY KEY CLUSTERED 
(
	[StatusId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Modules]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Modules](
	[ModuleCode] [nvarchar](20) NOT NULL,
	[Name] [nvarchar](20) NOT NULL,
	[IsActive] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[ModuleCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[NonPmkvkQPList]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[NonPmkvkQPList](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[Sector] [varchar](10) NULL,
	[QPName] [varchar](100) NULL,
	[QPID] [varchar](50) NULL,
	[QPLevel] [int] NULL,
	[MinEntryLevel] [varchar](500) NULL,
	[filepath] [nvarchar](1000) NULL,
	[filepathQPPdf] [nvarchar](1000) NULL,
	[filepathNSQCWord] [nvarchar](1000) NULL,
	[filepathNSQCPDF] [nvarchar](1000) NULL,
	[filepathOBFWord] [nvarchar](1000) NULL,
	[filepathOBFPDF] [nvarchar](1000) NULL,
	[filepathCurriculumWord] [nvarchar](1000) NULL,
	[filepathCurriculumPDF] [nvarchar](1000) NULL,
	[Price] [int] NULL,
	[Project] [varchar](200) NULL,
	[Description] [varchar](255) NOT NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Organizations]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Organizations](
	[OrganizationId] [int] IDENTITY(1,1) NOT NULL,
	[Name] [nvarchar](250) NULL,
	[Address] [nvarchar](500) NULL,
	[IsActive] [bit] NULL,
	[CreatedOn] [datetime] NULL,
	[CreatedBy] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[OrganizationId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[OTPData]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[OTPData](
	[id] [bigint] IDENTITY(1,1) NOT NULL,
	[EmailID] [nvarchar](150) NULL,
	[OTP] [nvarchar](5) NULL,
	[CreatedDate] [datetime] NULL,
	[IsUsed] [bit] NULL,
 CONSTRAINT [PK_OTPData] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[PlacedCandidateDetails]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PlacedCandidateDetails](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[SumofCandidateContactNo] [varchar](255) NULL,
	[CandidateEmail] [varchar](255) NULL,
	[CandidateID] [varchar](255) NULL,
	[CandidateName] [varchar](255) NULL,
	[Castecategory] [varchar](255) NULL,
	[CertificateDate] [varchar](255) NULL,
	[Certified] [varchar](255) NULL,
	[EmployerspocEmail] [varchar](255) NULL,
	[EmployerspocMobile] [varchar](255) NULL,
	[EmployerType] [varchar](255) NULL,
	[EmployerSpocName] [varchar](255) NULL,
	[FirstEmploymentCreatedDate] [varchar](255) NULL,
	[FromDate] [varchar](255) NULL,
	[FYWise] [varchar](255) NULL,
	[Gender] [varchar](255) NULL,
	[Jobrole] [varchar](255) NULL,
	[AvgofNoofdaysbetweennDOCDOP] [varchar](255) NULL,
	[AverageofNoOfMonthsofPlacement] [varchar](255) NULL,
	[OrganisationDistrict] [varchar](255) NULL,
	[OrganisationState] [varchar](255) NULL,
	[OrganizationAddress] [varchar](255) NULL,
	[OrganizationName] [varchar](255) NULL,
	[PartnerName] [varchar](255) NULL,
	[PartnerSPOCMobile] [varchar](255) NULL,
	[PartnerSPOCName] [varchar](255) NULL,
	[CountofPartnerID] [varchar](255) NULL,
	[SumofSalleryPerMonth] [varchar](255) NULL,
	[PartnerSPOCEmail] [varchar](255) NULL,
	[CountofSCTrainingCentreID] [varchar](255) NULL,
	[SectorName] [varchar](255) NULL,
	[SelfEmployedDistrict] [varchar](255) NULL,
	[SelfEmployedState] [varchar](255) NULL,
	[TCDistrict] [varchar](255) NULL,
	[TCSPOCEmail] [varchar](255) NULL,
	[SumofTCSPOCMobile] [varchar](255) NULL,
	[TCSPOCName] [varchar](255) NULL,
	[TCState] [varchar](255) NULL,
	[ToDate] [varchar](255) NULL,
	[TrainingCentreName] [varchar](255) NULL,
	[TrainingType] [varchar](255) NULL,
	[EducationAttained] [varchar](255) NULL,
	[CreatedDate] [datetime] NULL,
	[CreatedBy] [varchar](255) NULL
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[PopularJobSearches]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PopularJobSearches](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[FilterName] [varchar](50) NULL,
	[FilterValue] [varchar](100) NULL,
	[Count] [int] NULL DEFAULT ((1)),
	[CreatedBy] [varchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[UpdatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[PreferredLocation]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[PreferredLocation](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NOT NULL,
	[LocationId] [nvarchar](100) NULL,
	[OtherLocation] [varchar](200) NULL,
	[LocationOrder] [int] NOT NULL,
	[CreatedDate] [date] NULL,
	[CreatedBy] [varchar](50) NULL,
	[UpdatedDate] [date] NULL,
	[UpdatedBy] [varchar](50) NULL,
 CONSTRAINT [PK__Preferre__3214EC07FEAA686C] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[ProfileViewSummary]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ProfileViewSummary](
	[SummaryId] [int] IDENTITY(1,1) NOT NULL,
	[ViewerId] [int] NULL,
	[ViewedId] [int] NULL,
	[ViewedOn] [datetime] NULL DEFAULT (getdate()),
	[ModifiedViewedOn] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[SummaryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[RESULTS]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[RESULTS](
	[AB] [varchar](50) NULL,
	[Results] [varchar](max) NULL,
	[CreatedDate] [datetime] NULL,
	[BatchNumber] [varchar](50) NULL,
	[Project] [varchar](50) NULL,
	[qualificationPackId] [varchar](50) NULL,
	[CandidateId] [varchar](50) NULL,
	[CandidateFirstName] [varchar](100) NULL,
	[Status] [varchar](50) NULL,
	[CandidateLastName] [varchar](100) NULL,
	[DOB] [datetime] NULL,
	[TestLocation] [varchar](100) NULL,
	[TestDate] [datetime] NULL,
	[AverageMarks] [decimal](18, 2) NULL,
	[IsModeratedScore] [int] NULL,
	[TPName] [nvarchar](500) NULL,
	[GuardianName] [nvarchar](200) NULL,
	[Gender] [nvarchar](10) NULL,
	[idtype] [nvarchar](100) NULL,
	[idnumber] [nvarchar](500) NULL,
	[Relationship] [nvarchar](3) NULL,
	[Salutation] [nvarchar](5) NULL,
	[CanPhoto] [nvarchar](1000) NULL,
	[IsDeleted] [bit] NOT NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Roles]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Roles](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RoleName] [varchar](100) NULL,
	[IsActive] [bit] NULL,
	[Createddate] [datetime] NULL,
	[CreatedBy] [varchar](100) NULL,
	[IsEmployee] [bit] NULL DEFAULT ((0)),
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[SSCJobRole]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SSCJobRole](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Sector] [varchar](10) NULL,
	[JobRole] [varchar](100) NULL,
	[JobId] [varchar](50) NULL,
	[Level] [int] NULL,
	[Project] [varchar](200) NULL,
	[CreatedDate] [date] NULL,
	[CreatedBy] [varchar](50) NULL,
	[UpdatedDate] [date] NULL,
	[UpadtedBy] [varchar](50) NULL,
	[IsActive] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[States]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[States](
	[StateCode] [nvarchar](5) NOT NULL,
	[Name] [nvarchar](50) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
	[CountryCode] [nvarchar](5) NULL,
PRIMARY KEY CLUSTERED 
(
	[StateCode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[SuccessSotry]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SuccessSotry](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](max) NULL,
	[Email] [varchar](max) NULL,
	[TagLine] [varchar](max) NULL,
	[Message] [varchar](max) NULL,
	[CreatedBy] [varchar](max) NULL,
	[CreatedDate] [date] NULL,
	[IsApproved] [bit] NULL,
	[Status] [bit] NULL,
	[UpdatedBy] [varchar](max) NULL,
	[UpdatedDate] [date] NULL,
	[UserId] [int] NULL,
 CONSTRAINT [PK_SuccessSotry] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[SuccessStoryVideo]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SuccessStoryVideo](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Title] [varchar](max) NULL,
	[FileName] [varchar](max) NULL,
	[Type] [varchar](max) NULL,
	[DisplayOrder] [int] NULL,
	[CreatedBy] [varchar](max) NULL,
	[CreatedDate] [varchar](max) NULL,
	[UpdatedBy] [varchar](max) NULL,
	[UpdatedDate] [varchar](max) NULL,
	[Status] [bit] NULL,
 CONSTRAINT [PK_SuccessStoryVideo] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[TrainingPartners]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[TrainingPartners](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[TPID] [bigint] NULL,
	[TrainingPartner] [varchar](500) NULL,
	[Email] [varchar](100) NULL,
	[Phone] [varchar](10) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserActivity]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserActivity](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[LoginDateTime] [datetime] NULL,
	[Url] [varchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserProfessionalDetails]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserProfessionalDetails](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[ExperienceDetails] [varchar](max) NULL,
	[EducationalDetails] [varchar](max) NULL,
	[Skills] [varchar](max) NULL,
	[CurrentSalary] [varchar](50) NULL,
	[ExpectedSalary] [varchar](50) NULL,
	[DateOfBirth] [varchar](50) NULL,
	[Resume] [varchar](max) NULL,
	[AboutMe] [varchar](max) NULL,
	[ProfileSummary] [varchar](max) NULL,
	[Status] [varchar](50) NULL,
	[CreatedDate] [datetime] NULL,
	[CreatedBy] [varchar](50) NULL,
	[UpdatedDate] [datetime] NULL,
	[UpdatedBy] [varchar](50) NULL,
	[EmploymentStatusId] [int] NULL,
	[JobIndustryAreaId] [int] NULL,
	[TotalExperience] [varchar](5) NULL,
	[LinkedinProfile] [varchar](max) NULL,
	[IsJobAlert] [bit] NULL DEFAULT ((0)),
	[JobTitleId] [int] NULL,
 CONSTRAINT [PK_UserProfessionalDetails] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UserRoles]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UserRoles](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RoleId] [int] NULL,
	[UserId] [int] NULL,
	[Createddate] [datetime] NULL,
	[CreatedBy] [varchar](100) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Users]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Users](
	[UserId] [int] IDENTITY(1,1) NOT NULL,
	[FirstName] [nvarchar](max) NULL,
	[LastName] [nvarchar](20) NULL,
	[MobileNo] [nvarchar](15) NULL,
	[Email] [nvarchar](50) NULL,
	[Password] [nvarchar](max) NULL,
	[Address1] [nvarchar](100) NULL,
	[Address2] [nvarchar](100) NULL,
	[Address3] [nvarchar](100) NULL,
	[City] [nvarchar](50) NULL,
	[State] [nvarchar](50) NULL,
	[Country] [nvarchar](25) NULL,
	[MaritalStatus] [nvarchar](10) NULL,
	[ProfilePic] [nvarchar](max) NULL,
	[IsActive] [bit] NULL DEFAULT ((1)),
	[CreatedBy] [int] NULL DEFAULT ((0)),
	[CreatedOn] [datetime] NULL DEFAULT (getdate()),
	[UpdatedBy] [int] NULL,
	[UpdatedOn] [datetime] NULL,
	[Gender] [varchar](8) NULL,
	[IsApproved] [bit] NULL DEFAULT ((0)),
	[CompanyName] [nvarchar](max) NULL,
	[PasswordExpiryDate] [date] NULL,
	[Candidateid] [varchar](50) NULL,
	[ContactPerson] [varchar](100) NULL,
	[ActivationKey] [varchar](100) NULL,
	[IsViewedByAdmin] [bit] NULL DEFAULT ((0)),
	[IsHired] [bit] NULL DEFAULT ((0)),
	[IsRegisterOnlyForDemandAggregationData] [bit] NULL DEFAULT ((0)),
	[JobPortalTPID] [varchar](max) NULL DEFAULT (left(CONVERT([int],rand()*(1000000000)+(999999999)),(8))),
PRIMARY KEY CLUSTERED 
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[UsersBatch]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[UsersBatch](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[BatchNumber] [nvarchar](100) NULL,
	[CreatedDate] [date] NULL,
	[CreatedBy] [nvarchar](100) NULL,
	[UpdatedOn] [date] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  UserDefinedFunction [dbo].[TotalMonthCount]    Script Date: 8/28/2020 10:24:22 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[TotalMonthCount] (
    @date datetime,
	@id int,
	@tablename  varchar(max)
)
RETURNS Table
as
Return
SELECT  [1] AS January,
  [2] AS February,
  [3] AS March,
  [4] AS April,
  [5] AS May,
  [6] AS June,
  [7] AS July,
  [8] AS August,
  [9] AS September,
  [10] AS October,
  [11] AS November, 
  [12] AS December 
FROM
(
SELECT MONTH(CreatedDate) AS MONTH, [UserId] FROM JobPostDetail
) AS t
PIVOT (
COUNT([UserId])
  FOR MONTH IN([1], [2], [3], [4], [5],[6],[7],[8],[9],[10],[11],[12])
) p





GO
SET IDENTITY_INSERT [dbo].[AppliedJobs] ON 

INSERT [dbo].[AppliedJobs] ([Id], [UserId], [JobPostId], [AppliedDate], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, 2, 2, CAST(N'2020-08-19' AS Date), 1, N'2', CAST(N'2020-08-19 14:59:00.973' AS DateTime), NULL, NULL)
INSERT [dbo].[AppliedJobs] ([Id], [UserId], [JobPostId], [AppliedDate], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, 2, 5, CAST(N'2020-08-20' AS Date), 1, N'2', CAST(N'2020-08-20 06:47:27.857' AS DateTime), NULL, NULL)
INSERT [dbo].[AppliedJobs] ([Id], [UserId], [JobPostId], [AppliedDate], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (3, 2, 8, CAST(N'2020-08-20' AS Date), 1, N'2', CAST(N'2020-08-20 06:48:08.190' AS DateTime), NULL, NULL)
INSERT [dbo].[AppliedJobs] ([Id], [UserId], [JobPostId], [AppliedDate], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (4, 2, 4, CAST(N'2020-08-20' AS Date), 1, N'2', CAST(N'2020-08-20 06:49:46.863' AS DateTime), NULL, NULL)
INSERT [dbo].[AppliedJobs] ([Id], [UserId], [JobPostId], [AppliedDate], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (5, 2, 7, CAST(N'2020-08-20' AS Date), 1, N'2', CAST(N'2020-08-20 06:50:18.843' AS DateTime), NULL, NULL)
INSERT [dbo].[AppliedJobs] ([Id], [UserId], [JobPostId], [AppliedDate], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (6, 2, 6, CAST(N'2020-08-21' AS Date), 1, N'2', CAST(N'2020-08-21 14:57:17.800' AS DateTime), NULL, NULL)
SET IDENTITY_INSERT [dbo].[AppliedJobs] OFF
SET IDENTITY_INSERT [dbo].[BulkJobPostSummary] ON 

INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (1, 1, N'Test7July', N'Uttar Pradesh', N'Noida', N'Senior Software Developer', NULL, NULL, NULL, N'Test1', N'shiv.singh@steeprise1.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Software Development releted work', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-24 07:16:50.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:16:50.933' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (2, 2, N'Test7July', N'Uttar Pradesh', N'Noida', N'Senior Software Developer', NULL, NULL, NULL, N'Test2', N'shiv.singh@steeprise2.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Software Development releted work', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 07:16:50.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:16:51.190' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (3, 3, N'Test7July', N'Uttar Pradesh', N'Noida', N'Associate Software Engineer', NULL, NULL, NULL, N'Test3', N'rajesh.prajapati@steeprise3.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Software Development releted work', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 07:16:51.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:16:51.293' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (4, 4, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Software Trainee', NULL, NULL, NULL, N'Test4', N'rajesh.prajapati@steeprise3.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Software Development releted work', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-24 07:16:51.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:16:51.400' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (5, 5, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Business Development Analyst', NULL, NULL, NULL, N'Test5', N'avanesh.sharma@steeprise3.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Software Development releted work', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-24 07:16:51.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:16:51.503' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (6, 1, N'Test7July', N'Uttar Pradesh', N'Noida', N'Senior Software Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise11.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'QA Automation', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-24 07:23:40.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:23:40.270' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (7, 2, N'Test7July', N'Uttar Pradesh', N'Noida', N'Senior Software Developer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise22.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'QA Automation', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 07:23:40.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:23:40.373' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (8, 3, N'Test7July', N'Uttar Pradesh', N'Noida', N'Associate Software Engineer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise33.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'QA Automation', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 07:23:40.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:23:40.493' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (9, 4, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Software Trainee', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise34.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'QA Automation', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-24 07:23:40.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:23:40.600' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (10, 5, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Business Development Analyst', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise31.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'QA Automation', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-24 07:23:40.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 07:23:40.703' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (11, 1, N'Test7July', N'Uttar Pradesh', N'Noida', N'Senior Software Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise11.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-24 08:08:22.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:22.463' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (12, 2, N'Test7July', N'Uttar Pradesh', N'Noida', N'Senior Software Developer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise22.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 08:08:22.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:22.577' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (13, 3, N'Test7July', N'Uttar Pradesh', N'Noida', N'Associate Software Engineer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise33.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 08:08:22.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:22.687' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (14, 4, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Software Trainee', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise34.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-24 08:08:22.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:22.800' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (15, 5, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Business Development Analyst', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise31.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-24 08:08:22.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:22.910' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (16, 6, N'Test7July', N'Uttar Pradesh', N'Noida', N'Software Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise111.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-24 08:08:22.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.020' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (17, 7, N'Test7July', N'Uttar Pradesh', N'Noida', N'Software Development Engineer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise222.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Success', N'', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.130' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (18, 8, N'Test7July', N'Uttar Pradesh', N'Noida', N'Associate Software Engineer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise333.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.373' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (19, 9, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Software Trainee', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise344.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.480' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (20, 10, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'C# Developer', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise311.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.580' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (21, 11, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Java Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise112.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.673' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (22, 12, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'.NET Developer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise223.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.770' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (23, 13, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Unity Developer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise332.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.867' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (24, 14, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Ruby Developer', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise314.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:23.963' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (25, 15, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Senior Analyst', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise312.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-24 08:08:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:24.060' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (26, 16, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Software Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise11d.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-24 08:08:24.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:24.157' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (27, 17, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Senior Software Developer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise22s.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 08:08:24.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:24.343' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (28, 18, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Associate Software Engineer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise33f.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-24 08:08:24.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:24.460' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (29, 19, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Software Trainee', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise34r.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-24 08:08:24.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:24.553' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (30, 20, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Business Development Analyst', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise31q.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-24 08:08:24.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-24 08:08:24.650' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (31, 1, N'Test7July', N'Uttar Pradesh', N'Noida', N'Senior Software Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise11.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-26 11:28:18.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:19.227' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (32, 2, N'Test7July', N'Uttar Pradesh', N'Noida', N'Senior Software Developer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise22.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-26 11:28:19.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:19.527' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (33, 3, N'Test7July', N'Uttar Pradesh', N'Noida', N'Associate Software Engineer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise33.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-26 11:28:19.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:19.810' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (34, 4, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Software Trainee', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise34.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-26 11:28:19.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:19.947' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (35, 5, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Business Development Analyst', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise31.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-26 11:28:19.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:20.277' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (36, 6, N'Test7July', N'Uttar Pradesh', N'Noida', N'Software Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise111.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-26 11:28:20.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:20.590' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (37, 7, N'Test7July', N'Uttar Pradesh', N'Noida', N'Software Development Engineer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise222.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-26 11:28:20.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:20.890' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (38, 8, N'Test7July', N'Uttar Pradesh', N'Noida', N'Associate Software Engineer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise333.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-26 11:28:20.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:21.207' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (39, 9, N'Test7July', N'Uttar Pradesh', N'Ghaziabad', N'Software Trainee', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise344.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-26 11:28:21.000' AS DateTime), N'Failed', N'<li>This job already exist</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:21.340' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (40, 10, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'C# Developer', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise311.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-26 11:28:21.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:21.627' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (41, 11, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Java Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise112.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-26 11:28:21.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:21.897' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (42, 12, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'.NET Developer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise223.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-26 11:28:21.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:22.000' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (43, 13, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Unity Developer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise332.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-26 11:28:22.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:22.287' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (44, 14, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Ruby Developer', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise314.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-26 11:28:22.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:22.377' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (45, 15, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Senior Analyst', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise312.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-26 11:28:22.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:22.647' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (46, 16, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Software Developer', NULL, NULL, NULL, N'Test11', N'shiv.singh@steeprise11d.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'5', N'8', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 117, N'Test7July ', CAST(N'2020-08-26 11:28:22.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:22.900' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (47, 17, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Senior Software Developer', NULL, NULL, NULL, N'Test22', N'shiv.singh@steeprise22s.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'7', N'9', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-26 11:28:22.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:22.990' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (48, 18, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Associate Software Engineer', NULL, NULL, NULL, N'Test33', N'rajesh.prajapati@steeprise33f.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'2', N'4', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 0, N'Test7July ', CAST(N'2020-08-26 11:28:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:23.260' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (49, 19, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Software Trainee', NULL, NULL, NULL, N'Test44', N'rajesh.prajapati@steeprise34r.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'3', N'6', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 480, N'Test7July ', CAST(N'2020-08-26 11:28:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:23.367' AS DateTime), 4)
INSERT [dbo].[BulkJobPostSummary] ([Id], [SerialNo], [CompanyName], [State], [JobLocation], [JobTitle], [JobRole1], [JobRole2], [JobRole3], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [HiringCriteria], [MinExp], [MaxExp], [JobType], [JobDetails], [FinancialYear], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Total], [ProcessedBy], [ProcessedOn], [Status], [ErrorDetails], [FileName], [CreatedOn], [CreatedBy]) VALUES (50, 20, N'Test7July', N'Uttar Pradesh', N'Gurugram', N'Business Development Analyst', NULL, NULL, NULL, N'Test55', N'avanesh.sharma@steeprise31q.com', N'+919718661083', N'900000', N'B.Tech.(CS,IT)', N'4', N'5', N'2', N'Test bulk job upload', NULL, NULL, NULL, NULL, NULL, 309, N'Test7July ', CAST(N'2020-08-26 11:28:23.000' AS DateTime), N'Failed', N'<li>City Not Found In Our Record</li>', N'Ravi21 August.xlsx', CAST(N'2020-08-26 11:28:23.620' AS DateTime), 4)
SET IDENTITY_INSERT [dbo].[BulkJobPostSummary] OFF
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ADIA', N'Adilabad', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AGAB', N'Agar', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AGRC', N'Agra', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AHMD', N'Ahmedabad', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AHME', N'Ahmednagar', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AIZG', N'Aizwl', 1, N'MI')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AJIH', N'Mohali', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AJMI', N'Ajmer', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AKOJ', N'Akola', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ALAK', N'Alapuzzha', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ALIL', N'Aligarh', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ALIM', N'Alirajpur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ALLN', N'Allahabad', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ALMO', N'Almora', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ALWP', N'Alwar', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AMBQ', N'Ambala', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AMBR', N'Ambedkar Nagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AMES', N'Amethi', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AMRT', N'Amravati', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AMRU', N'Amrela', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AMRV', N'Amritsar', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ANAW', N'Anand', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ANAX', N'Anantnag', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ANAY', N'Anantpur', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ANDZ', N'Andaman and Nicobar Islands', 1, N'AN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ANGA', N'Angul', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ANUB', N'Anuppur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ARAC', N'Araria', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ARID', N'Ariyalur', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ARUC', N'Arun city', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ASHE', N'Ashok Nagar', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AURG', N'Auraiya', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AURH', N'Aurangabad', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AURI', N'Aurangabad', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'AZAJ', N'Azamgarh', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BADK', N'Badgam', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BAGL', N'Bagalkot', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BAGM', N'Bageshwar', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BAGN', N'Bagpat', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BAHO', N'Bahraich', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BALP', N'Balaghat', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BALQ', N'Balangir', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BALR', N'Balasore', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BALS', N'Ballia', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BALT', N'Balrampur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BANA', N'Bankura', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BANB', N'Banswara', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BANU', N'Banaskantha', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BANV', N'Banda', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BANW', N'Bandipora', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BANX', N'Bangalore Rural', 0, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BANY', N'Bangalore', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BANZ', N'Banka', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARC', N'Barabanki', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARD', N'Baramulla', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARE', N'Baran', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARG', N'Bardhaman', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARH', N'Bareilly', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARI', N'Bargarh (Baragarh)', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARJ', N'Barmer', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARK', N'Barnala', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARL', N'Barpeta', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BARM', N'Barwani', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BASO', N'Basti', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BATP', N'Bathinda', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BEEQ', N'Beed', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BEGR', N'Begusarai', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BELS', N'Belgaum', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BELT', N'Bellary', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BETU', N'Betul', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHAA', N'Bharuch', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHAB', N'Bhavnagar', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHAV', N'Bhabua', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHAW', N'Bhadrak', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHAX', N'Bhagalpur', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHAY', N'Bhandara', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHAZ', N'Bharatpur', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHIC', N'Bhilwara', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHID', N'Bhind', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHIE', N'Bhiwani', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHOG', N'Bhojpur (Arah)', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHOH', N'Bhopal', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BHUB', N'Bhubaneswar', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BIDI', N'Bidar', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BIJK', N'Bijapur', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BIJL', N'Bijnor', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BIKM', N'Bikaner', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BILO', N'Bilaspur', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BIRP', N'Birbhum', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BISQ', N'Bishnupur', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BOKR', N'Bokaro', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BONS', N'Bongaigaon', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BOUT', N'Boudh (Bauda)', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BUDU', N'Budaun', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BULV', N'Bulandshahr', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BULW', N'Buldhana', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BUNX', N'Bundi', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BURY', N'Burhanpur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'BUXZ', N'Buxar', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CACA', N'Cachar', 1, N'AS')
GO
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CANB', N'Cannanore', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CENC', N'Central Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CH', N'chandigarh', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAD', N'Chamarajnagar', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAE', N'Chamba', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAG', N'Chamoli', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAH', N'Champawat', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAI', N'Champhai', 1, N'MI')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAJ', N'chandauli', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAK', N'Chandel', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAM', N'Charaideo Maidams', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHAN', N'Chatra', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHEO', N'Chennai', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHHP', N'Chhatarpur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHHQ', N'Chhindwara', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHIR', N'Chikkaballapur', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHIS', N'Chikkamagaluru', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHIT', N'Chitradurga', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHIU', N'Chitrakoot', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHIV', N'Chittor', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHIW', N'Chittorgarh', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHNX', N'Chndrapur', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHUY', N'Churachandpur', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CHUZ', N'Churu', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'COIA', N'Coimbatore', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'COOB', N'Cooch Behar', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CUDC', N'Cuddalore', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CUDD', N'Cuddapah', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'CUTE', N'Cuttack', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DADG', N'Dadra and Nagar Haveli', 1, N'DN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DAHH', N'Dahod', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DAKI', N'Dakshin Dinajpur', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DAKJ', N'Dakshina Kannada', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DAMK', N'Daman', 1, N'DD')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DAML', N'Damoh', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DANM', N'Dangs', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DARO', N'Darbhanga', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DARP', N'Darjeelimg', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DARQ', N'Darrang', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DATR', N'Datia', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DAUS', N'Dausa', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DAVT', N'Davanagere', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DDN', N'Dehradun', 1, N'UK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DEBU', N'Debagarh (Deogarh)', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DEHV', N'Dehradun', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DEOW', N'Deoghar', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DEOX', N'Deoria', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DEWY', N'Dewas', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHAB', N'Dhanbad', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHAC', N'Dhar', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHAD', N'Dharmapuri', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHAE', N'Dharwad', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHAZ', N'Dhalai', 1, N'TR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHEG', N'Dhemaji', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHEH', N'Dhenkanal', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHOI', N'Dholpur', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHUJ', N'Dhubri', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DHUK', N'Dhule', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DIBL', N'Dibin Valley (Anini Valley)', 1, N'AR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DIBM', N'Dibrugarh', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DIMN', N'Dimapur', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DINO', N'Dindigul', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DINP', N'Dindori', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DIUQ', N'Diu', 1, N'DD')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DLNR', N'Delhi NCR', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DODR', N'Doda', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DUMS', N'Dumka', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'DUNT', N'Dungapur', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASA', N'East Khasi Hills', 1, N'ME')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASB', N'East Siang (Passighat)', 1, N'AR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASC', N'East Sikkim', 1, N'SK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASD', N'East Singhbhum', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASV', N'East Champaran', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASW', N'East Commeng Seppa', 1, N'AR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASX', N'East Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASY', N'East Garo Hills', 1, N'ME')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EASZ', N'East Godavari', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'END', N'East New Delhi ', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ERNE', N'Ernakulam', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'EROG', N'Erode', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ETAH', N'Etah', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ETAI', N'Etawah', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FAIJ', N'Faizabad', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FARK', N'Faridabad', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FARL', N'Faridkot', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FARM', N'Farrukhabad', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FATN', N'Fatehabad', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FATO', N'Fatehgarh Sahib', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FATP', N'Fatehpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FAZQ', N'Fazilka [6]', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FIRR', N'Firozabad', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'FIRS', N'Firozpur', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GADT', N'Gadag', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GADU', N'Gadchiroli', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GAJV', N'Gajapati', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GANW', N'Ganderbal', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GANX', N'Gandhinagar', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GANY', N'Ganganagar', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GANZ', N'Ganjam', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GARA', N'Garhwa', 1, N'JH')
GO
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GAYB', N'Gaya', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GHAC', N'Ghaziabad', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GHAD', N'Ghazipur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GIRE', N'Giridih', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GOAG', N'Goalpara', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GODH', N'Godda', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GOLI', N'Golaghat', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GONJ', N'Gonda', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GONK', N'Gondia', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GOPL', N'Gopalganj', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GORM', N'Gorakhpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GOUN', N'Goutam Buddh Nagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GULO', N'Gulbarga', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GUMP', N'Gumla', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GUNQ', N'Guna', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GUNR', N'Guntur', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GURS', N'Gurdaspur', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GURT', N'Gurgaon', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GW', N'Guwahati', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'GWAU', N'Gwalior', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HAIV', N'Hailakandi', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HAMW', N'Hamirpur', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HAMX', N'Hamirpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HANY', N'Hanumangarh', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HARA', N'Hardoi', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HARB', N'Haridwar', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HARZ', N'Harda', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HASC', N'Hassan', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HATD', N'Hathras (Mahamaya Nagar)', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HAVE', N'Haveri', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HAZG', N'Hazaribag', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HINH', N'Hingoli', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HISI', N'Hissar', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HOOJ', N'Hooghly', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HOSK', N'Hoshangabad', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HOSL', N'Hoshiarpur', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HOWM', N'Howrah', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'HYDN', N'Hyderabad ', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'IDUO', N'Idukki', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'IMPP', N'Imphal East', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'IMPQ', N'Imphal West', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'INDR', N'Indore', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ITAS', N'Itanagar', 1, N'AR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JABT', N'Jabalpur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAGU', N'Jagatsinghpur', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAIV', N'Jaintia Hills', 1, N'ME')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAIW', N'Jaipur', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAIX', N'Jaisalmer', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAJY', N'Jajpur', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JALA', N'Jalaun', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JALB', N'Jalgaon', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JALC', N'Jalna', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JALD', N'Jalore', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JALE', N'Jalpaiguri', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JALZ', N'Jalandhar', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAMG', N'Jammu', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAMH', N'Jamnagar', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAMI', N'Jamtara', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAMJ', N'Jamui', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JAUM', N'Jaunpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JEHN', N'Jehanabad', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JHAO', N'Jhabua', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JHAP', N'Jhalawar', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JHAQ', N'Jhanjhar', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JHAR', N'Jhansi', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JHAS', N'Jharsuguda', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JHUT', N'Jhunjhunu', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JINU', N'Jind', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JODV', N'Jodhpur', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JORW', N'Jorhat', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JUNX', N'Junagadh', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'JYOY', N'Jyotiba Phule Nagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KAIA', N'Kaithal', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KALB', N'Kalanandi', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KAMC', N'Kamrup', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KAND', N'Kanchipuram', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KANE', N'Kandhamal', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KANG', N'Kangra', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KANI', N'Kannauj', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KANJ', N'Kanpur Dehat (Ramabai Nagar)', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KANK', N'Kanpur Nagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KANL', N'Kanshi Ram Nagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KANM', N'Kanyakumari', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KAPN', N'Kapurthala', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KARO', N'Karaikal', 1, N'PY')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KARP', N'Karauli', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KARQ', N'Karbi Anglong', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KARR', N'Kargil', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KARS', N'Karim Nagar', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KART', N'Karimganj', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KARU', N'Karnal', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KARV', N'Karur', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KASW', N'Kasaragod', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KATX', N'Kathua', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KATY', N'Katihar', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KATZ', N'Katni', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KAUA', N'Kaushambi', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KCH', N'Kochi', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KENB', N'Kendrapara', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KENC', N'Kendujhar (keonjhar)', 1, N'OR')
GO
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHAD', N'Khagaria', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHAE', N'Khammam', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHAG', N'Khandwa (East Nimar)', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHAH', N'Khargone (West Nimar)', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHEI', N'Kheda', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHOJ', N'Khonsa', 1, N'AR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHOK', N'Khordha', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHOL', N'Khowai [7]', 1, N'TR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KHUM', N'Khunti', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KINN', N'Kinnaur', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KIPO', N'Kiphire', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KISP', N'Kishanganj', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KISQ', N'Kishtwar', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KODR', N'Kodagu', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KODS', N'Koderma', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOHT', N'Kohima', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOKU', N'Kokrajhar', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOLV', N'Kolaru', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOLW', N'Kolasib', 1, N'MI')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOLX', N'Kolhapur', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOLY', N'Kolkata', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOPZ', N'Koppal', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KORA', N'Koraput', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOTD', N'Kota', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOTE', N'Kottayam', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KOZG', N'kozhikode', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KPR', N'Kanpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KRIH', N'Krishna', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KRII', N'Krishnagiri', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KULJ', N'Kulgam', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KULK', N'Kullu', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KUPL', N'Kupwara', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KURM', N'Kurnool', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KURN', N'Kurukshetra', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KUSO', N'Kushinagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'KUTP', N'Kutch', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LAHQ', N'Lahaul Spiti', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LAKR', N'Lakhisarai', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LAKS', N'Lakshadweep', 1, N'LD')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LAKT', N'Lakshimpur', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LAKU', N'Lakshimpur Kheri', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LALV', N'Lalitpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LATW', N'Latehar', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LATX', N'Latur', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LAWY', N'Lawngt Lai', 1, N'MI')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LEHZ', N'Leh', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LOHA', N'Lohardaga', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LOHB', N'Lohit (Tezu)', 1, N'AR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LONC', N'Longleng', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LOWD', N'Lower Subansiri (Ziro)', 1, N'AR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LUCE', N'Lucknow', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LUDG', N'Ludhiana', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'LUNH', N'Lunglei', 1, N'MI')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MADI', N'Madhepura', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MADJ', N'Madhubani', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MADK', N'Madurai', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAHL', N'Maharajganj', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAHN', N'Mahboobnagar', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAHO', N'Mahe', 1, N'PY')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAHP', N'Mahendragarh', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAHQ', N'Mahoba', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAIR', N'Mainpuri', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MALS', N'Maldah', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MALT', N'Malkangiri', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MALU', N'Mallapuram', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAMV', N'Mamit', 1, N'MI')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MANA', N'Mansa', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MANW', N'Mandi', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MANX', N'Mandla', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MANY', N'Mandsaur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MANZ', N'Mandya', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MATB', N'Mathura', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAUC', N'Mau', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MAYD', N'Mayurbhanj', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MEDE', N'Medak', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MEEG', N'Meerut', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MEHH', N'Mehsana', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MIRI', N'Mirzapur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MOGJ', N'Moga', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MOKK', N'Mokokchung', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MONL', N'Mon', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MORM', N'Moradabad', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MORN', N'Morena', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MORO', N'Morigaon', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MUMP', N'Mumbai City', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MUMQ', N'Mumbai Suburban', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MUNR', N'Munger', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MURS', N'Murshidabad', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MUZT', N'Muzaffarnagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MUZU', N'Muzaffarpur', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'MYSV', N'Mysore', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'N.CW', N'N.C.Hills', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NABX', N'Nabarangpur', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NADY', N'Nadia', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAGA', N'Nagapattinam', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAGB', N'Nagaur', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAGC', N'Nagpur', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAGZ', N'Nagaon', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAID', N'Nainital', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NALE', N'Nalanda', 1, N'BH')
GO
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NALG', N'Nalbari', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NALH', N'Nalgonda', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAMI', N'Namakkal', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NANJ', N'Nanded', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NANK', N'Nandurbar', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NARM', N'Narmada', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NARN', N'Narsinghpur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NASO', N'Nashik', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAVP', N'Navsari', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAWQ', N'Nawada', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NAYR', N'Nayagarh', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NEES', N'Neemuch', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NELT', N'Nellore', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NEWU', N'New Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NILV', N'Nilgiris', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NIZW', N'Nizamabad', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NOI', N'Noida', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NORA', N'North Goa', 1, N'GA')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NORB', N'North Sikkim', 1, N'SK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NORC', N'North Tripura', 1, N'TR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NORD', N'North West Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NORX', N'North 24 Parganas', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NORY', N'North Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NORZ', N'North East Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'NUAE', N'Nuapada', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'OSMG', N'Osmanabad', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PAKH', N'Pakur', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PALI', N'Palamu', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PALJ', N'Palghar', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PALK', N'Palghat', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PALL', N'Pali', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PANM', N'Panchkula', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PANN', N'Panchmahals', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PANO', N'Panchsheel Nagar (Hapur)', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PANP', N'Panipat', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PANQ', N'Panna', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PARR', N'Parbhani', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PASS', N'Paschim Medinipur', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PATT', N'Patan', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PATU', N'Pathanamthitta', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PATV', N'Pathankot', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PATW', N'Patiala', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PATX', N'Patna', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PAUY', N'Pauri Garhwal', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PERA', N'Peren', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PERZ', N'Perambalur', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PHEB', N'Phek', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PILC', N'Pilibhit', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PITD', N'Pithoragarh', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PONE', N'Pondicherry', 1, N'PY')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'POOG', N'Poonch', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PORH', N'Porbander', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PRAI', N'Prakasam', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PRAJ', N'Pratapgarh', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PRAK', N'Pratapgarh', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PUDL', N'Pudukkottai', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PULM', N'Pulwama', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PUNN', N'Pune', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PURO', N'Purba Medinipur', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PURP', N'Puri', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PURQ', N'Purnea', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'PURR', N'Purulia', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'QUIS', N'Quilon', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAET', N'Raebareli', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAIU', N'Raichur', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAIV', N'Raigad', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAIY', N'Raisen', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAJA', N'Rajkot', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAJC', N'Rajouri', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAJD', N'Rajsamand', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAJZ', N'Rajgarh', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAME', N'Ramanagara', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAMG', N'Ramanthapuram', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAMH', N'Ramban', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAMI', N'Ramgarh', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAMJ', N'Rampur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RANK', N'Ranchi', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RANL', N'Ranga Reddy', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RATM', N'Ratlam', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RATN', N'Ratnagiri', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RAYO', N'Rayagada', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'REAP', N'Reasi', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'REWQ', N'Rewa', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'REWR', N'Rewari', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RI S', N'Ri Bhoi', 1, N'ME')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ROHT', N'Rohtak', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'ROHU', N'Rohtas (sasaram)', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RPR', N'Raipur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RUDV', N'Rudraprayag', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'RUPW', N'Rupnagar', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SABX', N'Sabarkantha', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAGY', N'Sagar', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAHA', N'Saharsa', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAHB', N'Sahibganj', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAHZ', N'Saharanpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAIC', N'Saiha', 1, N'MI')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SALD', N'Salem', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAME', N'Samastipur', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAMG', N'Samba', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAMH', N'Sambalpur', 1, N'OR')
GO
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAMI', N'Sambha (Bheem Nagar)', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SANJ', N'Sangli', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SANK', N'Sangrur', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SANL', N'Sant Kabir Nagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SANM', N'Sant Ravidas Nagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SARN', N'Saran (Chapra)', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SATO', N'Satara', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SATP', N'Satna', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SAWQ', N'Sawai Madhopur', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SEHR', N'Sehore', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SEKS', N'Sekhpura', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SENT', N'Senapati', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SEOU', N'Seohar', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SEOV', N'Seoni', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SERW', N'Seraikela Kharsawan', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SERX', N'Serchhip', 1, N'MI')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHAA', N'Shahjahanpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHAB', N'Shajapur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHAC', N'Shamli [9]', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHAY', N'Shahdol', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHAZ', N'Shahid Bhagat Singh Nagar', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHED', N'Sheopur', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHIE', N'Shimla', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHIG', N'Shimoga', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHIH', N'Shivpuri', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHOI', N'Shopian', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SHRJ', N'Shravasti', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIBK', N'Sibsagar', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIDL', N'Siddarthnagar', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIDM', N'Sidhi', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIKN', N'Sikar', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIMO', N'Simdega', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SINP', N'Sindhudurg', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SINQ', N'Singrauli', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIRR', N'Sirmour', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIRS', N'Sirohi', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIRT', N'Sirsa', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SITU', N'Sitamarhi', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SITV', N'Sitapur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIVW', N'Siva Ganga', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SIWX', N'Siwan', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOLY', N'Solan', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOLZ', N'Solapur', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SONA', N'Sonbhadra', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SONB', N'Sonipat', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SONC', N'Sonitpur', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOUD', N'South 24 Parganas', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOUE', N'South Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOUG', N'South Garo Hills', 1, N'ME')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOUH', N'South Goa', 1, N'GA')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOUI', N'South Sikkim', 1, N'SK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOUJ', N'South Tripura', 1, N'TR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SOUK', N'South West Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SRIL', N'Sri Muktsar Sahib', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SRIM', N'Srikakulam', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SRIN', N'Srinagar', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SUBO', N'Subarnapur (Sonepur)', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SULP', N'Sultanpur', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SUNQ', N'Sundergarh', 1, N'OR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SUPR', N'Supaul', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SURT', N'Surat', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'SURU', N'Surendranagar', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TAMW', N'Tamenglong', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TARX', N'Tarn Taran', 1, N'PB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TE', N'TestCity', 1, N'TE')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TEHY', N'Tehri Garhwal', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'THAA', N'Thanjavur', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'THAZ', N'Thane', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'THEB', N'Theni', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'THOC', N'Thoothukudi', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'THOD', N'Thoubal', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TIKE', N'Tikamgarh', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TING', N'Tinsukia', 1, N'AS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TIRH', N'Tiruchirapalli', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TIRI', N'Tirunelveli', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TIRJ', N'Tirupur', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TIRK', N'Tiruvallur', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TIRL', N'Tiruvannamalai', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TONM', N'Tonk', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TRIN', N'Trichur', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TRIO', N'Trivandrum', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TSB', N'Test Bihar1', 0, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TUEP', N'Tuensang', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'TUMQ', N'Tumkur', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UDAR', N'Udaipur', 1, N'RJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UDHS', N'Udham Singh Nagar', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UDHT', N'Udhampur', 1, N'JK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UDUU', N'Udupi', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UJJV', N'Ujjain', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UKHW', N'Ukhrul', 1, N'MN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UMAX', N'Umaria', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UNAY', N'Una', 1, N'HP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UNNZ', N'Unnao', 1, N'UP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UTTA', N'Uttar Dinajpur', 1, N'WB')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UTTB', N'Uttara Kannada', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'UTTC', N'Uttarkashi', 1, N'UT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VADD', N'Vadodara', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VAIE', N'Vaishali (Hajipur)', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VALG', N'Valsad', 1, N'GJ')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VARH', N'Varanasi', 1, N'UP')
GO
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VELI', N'Vellore', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VIDJ', N'Vidisha', 1, N'MP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VILK', N'Viluppuram', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VIRL', N'Virudhunagar', 1, N'TN')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VISM', N'Vishakapatnam', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'VIZN', N'Vizianagaram', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WARO', N'Warangal', 1, N'TS')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WARP', N'Wardha', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WASQ', N'Washim', 1, N'MH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WAYR', N'Wayand', 1, N'KL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WESS', N'West Champaran', 1, N'BH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WEST', N'West Delhi', 1, N'DL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WESU', N'West Garo Hills', 1, N'ME')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WESV', N'West Godavari', 1, N'AP')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WESW', N'West Khasi Hills', 1, N'ME')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WESX', N'West Sikkim', 1, N'SK')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WESY', N'West Singhbhum', 1, N'JH')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WESZ', N'West Tripura', 1, N'TR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'WOKA', N'Wokha', 1, N'NL')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'YADB', N'Yadgir', 1, N'KT')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'YAMC', N'Yamunanagar', 1, N'HR')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'YAND', N'Yanam', 1, N'PY')
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'YAVE', N'Yavatmal', 1, N'MH')
INSERT [dbo].[Countries] ([CountryCode], [Name], [IsActive]) VALUES (N'IN', N'India', 1)
SET IDENTITY_INSERT [dbo].[CourseCategories] ON 

INSERT [dbo].[CourseCategories] ([CategoryId], [Name], [IsActive]) VALUES (1, N'Post Graduate', 1)
INSERT [dbo].[CourseCategories] ([CategoryId], [Name], [IsActive]) VALUES (2, N'Graduate', 1)
INSERT [dbo].[CourseCategories] ([CategoryId], [Name], [IsActive]) VALUES (3, N'12th', 1)
INSERT [dbo].[CourseCategories] ([CategoryId], [Name], [IsActive]) VALUES (4, N'10th', 1)
SET IDENTITY_INSERT [dbo].[CourseCategories] OFF
SET IDENTITY_INSERT [dbo].[Courses] ON 

INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (1, N'M.Tech', 1, 1)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (2, N'MCA', 1, 1)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (3, N'MBA', 1, 1)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (4, N'M.Com.', 1, 1)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (5, N'B.Tech', 1, 2)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (6, N'BCA', 1, 2)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (7, N'BBA', 1, 2)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (8, N'B.Com.', 1, 2)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (9, N'12th', 1, 3)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (10, N'10th', 1, 4)
INSERT [dbo].[Courses] ([CourseId], [Name], [IsActive], [Category]) VALUES (11, N'Other', 1, 2)
SET IDENTITY_INSERT [dbo].[Courses] OFF
SET IDENTITY_INSERT [dbo].[CourseType] ON 

INSERT [dbo].[CourseType] ([CourseTypeId], [Type], [IsActive]) VALUES (1, N'Full Time', 1)
INSERT [dbo].[CourseType] ([CourseTypeId], [Type], [IsActive]) VALUES (2, N'Part Time', 1)
INSERT [dbo].[CourseType] ([CourseTypeId], [Type], [IsActive]) VALUES (3, N'Correspondence', 1)
SET IDENTITY_INSERT [dbo].[CourseType] OFF
SET IDENTITY_INSERT [dbo].[EmailQueue] ON 

INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (2, NULL, 2, N'Resgistration completed successfully', N'Dear Aayodha,<br/>You have successfully registered with us.<br>Your login details are below:<br>User Name: aayodhatest@icanav.net<br>Password: Test@123<br><br>Thank You<br>Placement Portal Team', 0, NULL, -1, CAST(N'2020-08-05 13:18:22.773' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'aayodhatest@icanav.net', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (3, NULL, 2, N'Account Approval', N'Dear                                     Aayodha                                ,<br/>You have successfully registered with us.You are one step away to explore our application.<br/><br/>Please <a href=://localhost:44319/Auth/Index>click here</a> to proceed.<br/><br/><br/>Thank You<br/>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-05 13:28:20.283' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'aayodhatest@icanav.net', 4)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (4, NULL, 4, N'Resgistration completed successfully', N'Dear Test7July,<br/>You have successfully registered with us.<br>Your login details are below:<br>User Name: testmailcompany@test.com<br>Password: Test@123<br><br>Thank You<br>Placement Portal Team', 0, NULL, -1, CAST(N'2020-08-07 15:35:27.453' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'testmailcompany@test.com', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (5, NULL, 4, N'Account Approval', N'Dear                                     Test7July                                ,<br/>You have successfully registered with us.You are one step away to explore our application.<br/><br/>Please <a href=://localhost:44319/Auth/Index>click here</a> to proceed.<br/><br/><br/>Thank You<br/>Placement Portal Team', 0, NULL, 4, CAST(N'2020-08-07 15:36:17.523' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'testmailcompany@test.com', 4)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (6, 4, 2, N'Applied Job from Placement Portal', N'Dear Aayodha Singh,<br/><br/> We have successfully forwarded your application for the position of Test<br/><br/>Corporate Name  : Test7July<br/>JobRole  : Web Manager<br/>Job Description  : <p>Test the details</p>
<br/><br/>In case you don''t find the above details appropriate, <a href=://18.219.209.88:83/JobSeekerManagement/Profile>update profile</a> and apply again.<br/><br/>Recruiters will be contacting you on this mobile number +91<br/>To update it, please <a href=://18.219.209.88:83/JobSeekerManagement/Profile>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-19 14:59:02.653' AS DateTime), NULL, NULL, N'testmailcompany@test.com', N'aayodhatest@icanav.net', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (7, 2, 4, N'You have recevied one job application', N'Dear Test7July ,<br/><br/> You have received a new application for the job post Test<br/><br/>JobRole  : Web Manager<br/>Job Description  : <p>Test the details</p>
<br/>Job Posted On  : 8/19/2020 2:48:36 PM<br/><br/>To Check Completed details please <a href=://18.219.209.88:83/Job/JobDetails/?jobid=2>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-19 14:59:03.793' AS DateTime), NULL, NULL, N'aayodhatest@icanav.net', N'testmailcompany@test.com', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (8, NULL, 5, N'Welcome aboard!', N'<b>Hi Tech First</b>,<br/><br/>Thank You for signing up with SRJobPortal.com. We are delighted to have you on board.<br/><br/>Your login details are below:<br/><br/>User Name: techfirst@senduvu.com<br>Password: Test@123<br/><br/>You can update your contact and registration details at any time by logging on to SRJobPortal.com<br/><br/>See you on board!<br/><a href=http://18.219.209.88:83/Auth/EmployerLogin> SRTechJob/</a> Team', 0, NULL, -1, CAST(N'2020-08-20 05:43:35.890' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'techfirst@senduvu.com', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (9, NULL, 5, N'Account Approval', N'Dear                                     Tech First                                ,<br/>You have successfully registered with us.You are one step away to explore our application.<br/><br/>Please <a href=://18.219.209.88:83/Auth/Index>click here</a> to proceed.<br/><br/><br/>Thank You<br/>Placement Portal Team', 0, NULL, 5, CAST(N'2020-08-20 05:45:40.180' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'techfirst@senduvu.com', 4)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (10, NULL, 6, N'Welcome aboard!', N'<b>Hi Property First</b>,<br/><br/>Thank You for signing up with SRJobPortal.com. We are delighted to have you on board.<br/><br/>Your login details are below:<br/><br/>User Name: propertyfirst@inbox-me.top<br>Password: Test@123<br/><br/>You can update your contact and registration details at any time by logging on to SRJobPortal.com<br/><br/>See you on board!<br/><a href=http://18.219.209.88:83/Auth/EmployerLogin> SRTechJob/</a> Team', 0, NULL, -1, CAST(N'2020-08-20 06:04:08.867' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'propertyfirst@inbox-me.top', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (11, NULL, 6, N'Account Approval', N'Dear                                     Property First                                ,<br/>You have successfully registered with us.You are one step away to explore our application.<br/><br/>Please <a href=://18.219.209.88:83/Auth/Index>click here</a> to proceed.<br/><br/><br/>Thank You<br/>Placement Portal Team', 0, NULL, 6, CAST(N'2020-08-20 06:05:23.203' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'propertyfirst@inbox-me.top', 4)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (12, NULL, 7, N'Welcome aboard!', N'<b>Hi Wheel balance </b>,<br/><br/>Thank You for signing up with SRJobPortal.com. We are delighted to have you on board.<br/><br/>Your login details are below:<br/><br/>User Name: wheelblance@senduvu.com<br>Password: Test@123<br/><br/>You can update your contact and registration details at any time by logging on to SRJobPortal.com<br/><br/>See you on board!<br/><a href=http://18.219.209.88:83/Auth/EmployerLogin> SRTechJob/</a> Team', 0, NULL, -1, CAST(N'2020-08-20 06:19:46.890' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'wheelblance@senduvu.com', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (13, NULL, 7, N'Account Approval', N'Dear                                     Wheel balance                                 ,<br/>You have successfully registered with us.You are one step away to explore our application.<br/><br/>Please <a href=://18.219.209.88:83/Auth/Index>click here</a> to proceed.<br/><br/><br/>Thank You<br/>Placement Portal Team', 0, NULL, 7, CAST(N'2020-08-20 06:20:18.180' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'wheelblance@senduvu.com', 4)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (14, 6, 2, N'Applied Job from Placement Portal', N'Dear Aayodha Singh,<br/><br/> We have successfully forwarded your application for the position of Software Developer and UI designer<br/><br/>Corporate Name  : Property First<br/>JobRole  : Software Developer<br/>Job Description  : <p>looking for a software developer and designer that could work with our us client according us timing.</p>
<br/><br/>In case you don''t find the above details appropriate, <a href=://18.219.209.88:83/JobSeekerManagement/Profile>update profile</a> and apply again.<br/><br/>Recruiters will be contacting you on this mobile number +91<br/>To update it, please <a href=://18.219.209.88:83/JobSeekerManagement/Profile>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-20 06:47:29.253' AS DateTime), NULL, NULL, N'propertyfirst@inbox-me.top', N'aayodhatest@icanav.net', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (15, 2, 6, N'You have recevied one job application', N'Dear Property First ,<br/><br/> You have received a new application for the job post Software Developer and UI designer<br/><br/>JobRole  : Software Developer<br/>Job Description  : <p>looking for a software developer and designer that could work with our us client according us timing.</p>
<br/>Job Posted On  : 8/20/2020 6:10:36 AM<br/><br/>To Check Completed details please <a href=://18.219.209.88:83/Job/JobDetails/?jobid=5>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-20 06:47:30.453' AS DateTime), NULL, NULL, N'aayodhatest@icanav.net', N'propertyfirst@inbox-me.top', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (16, 7, 2, N'Applied Job from Placement Portal', N'Dear Aayodha Singh,<br/><br/> We have successfully forwarded your application for the position of Mobile and communicator trainee <br/><br/>Corporate Name  : Wheel balance <br/>JobRole  : Management Trainee - Marketing<br/>Job Description  : <p>this is test doc for job portal</p>
<br/><br/>In case you don''t find the above details appropriate, <a href=://18.219.209.88:83/JobSeekerManagement/Profile>update profile</a> and apply again.<br/><br/>Recruiters will be contacting you on this mobile number +91<br/>To update it, please <a href=://18.219.209.88:83/JobSeekerManagement/Profile>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-20 06:48:09.310' AS DateTime), NULL, NULL, N'wheelblance@senduvu.com', N'aayodhatest@icanav.net', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (17, 2, 7, N'You have recevied one job application', N'Dear Wheel balance  ,<br/><br/> You have received a new application for the job post Mobile and communicator trainee <br/><br/>JobRole  : Management Trainee - Marketing<br/>Job Description  : <p>this is test doc for job portal</p>
<br/>Job Posted On  : 8/20/2020 6:32:56 AM<br/><br/>To Check Completed details please <a href=://18.219.209.88:83/Job/JobDetails/?jobid=8>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-20 06:48:10.507' AS DateTime), NULL, NULL, N'aayodhatest@icanav.net', N'wheelblance@senduvu.com', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (18, 5, 2, N'Applied Job from Placement Portal', N'Dear Aayodha Singh,<br/><br/> We have successfully forwarded your application for the position of Academic Instructor Verbal<br/><br/>Corporate Name  : Tech First<br/>JobRole  : Engineer Trainee<br/>Job Description  : <p>Looking for a trainer cum teacher that could make our training sector better</p>
<br/><br/>In case you don''t find the above details appropriate, <a href=://18.219.209.88:83/JobSeekerManagement/Profile>update profile</a> and apply again.<br/><br/>Recruiters will be contacting you on this mobile number +91<br/>To update it, please <a href=://18.219.209.88:83/JobSeekerManagement/Profile>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-20 06:49:47.973' AS DateTime), NULL, NULL, N'techfirst@senduvu.com', N'aayodhatest@icanav.net', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (19, 2, 5, N'You have recevied one job application', N'Dear Tech First ,<br/><br/> You have received a new application for the job post Academic Instructor Verbal<br/><br/>JobRole  : Engineer Trainee<br/>Job Description  : <p>Looking for a trainer cum teacher that could make our training sector better</p>
<br/>Job Posted On  : 8/20/2020 5:59:33 AM<br/><br/>To Check Completed details please <a href=://18.219.209.88:83/Job/JobDetails/?jobid=4>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-20 06:49:49.100' AS DateTime), NULL, NULL, N'aayodhatest@icanav.net', N'techfirst@senduvu.com', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (20, 7, 2, N'Applied Job from Placement Portal', N'Dear Aayodha Singh,<br/><br/> We have successfully forwarded your application for the position of Retail Store Administrator <br/><br/>Corporate Name  : Wheel balance <br/>JobRole  : Market Research Associate<br/>Job Description  : <p>Looking for stuff that could do administration work as well as marketing department</p>
<br/><br/>In case you don''t find the above details appropriate, <a href=://18.219.209.88:83/JobSeekerManagement/Profile>update profile</a> and apply again.<br/><br/>Recruiters will be contacting you on this mobile number +91<br/>To update it, please <a href=://18.219.209.88:83/JobSeekerManagement/Profile>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-20 06:50:20.390' AS DateTime), NULL, NULL, N'wheelblance@senduvu.com', N'aayodhatest@icanav.net', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (21, 2, 7, N'You have recevied one job application', N'Dear Wheel balance  ,<br/><br/> You have received a new application for the job post Retail Store Administrator <br/><br/>JobRole  : Market Research Associate<br/>Job Description  : <p>Looking for stuff that could do administration work as well as marketing department</p>
<br/>Job Posted On  : 8/20/2020 6:26:11 AM<br/><br/>To Check Completed details please <a href=://18.219.209.88:83/Job/JobDetails/?jobid=7>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-20 06:50:21.700' AS DateTime), NULL, NULL, N'aayodhatest@icanav.net', N'wheelblance@senduvu.com', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (22, NULL, 8, N'Welcome to SRJobPortal.com', N'<b>Dear Mohit</b>,<br/><br/>Congratulations! You have successfully registered with SRJobPortal.com<br/><br/>Please note that your username and password are both case sensitive.<br/><br/>Your login details are below:<br/><br/>User Name: mohitrana@academail.net<br>Password: Test@123<br/><br/>You can update your contact and registration details at any time by logging on to SRJobPortal.com<br/><br/>Wish you all the best!<br/><a href=http://18.219.209.88:83/Auth/JobSeekerLogin> SrJobPortal.com</a> Team', 0, NULL, -1, CAST(N'2020-08-20 14:29:12.740' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'mohitrana@academail.net', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (23, 6, 2, N'Applied Job from Placement Portal', N'Dear Aayodha Singh,<br/><br/> We have successfully forwarded your application for the position of Property Sales and Marketing <br/><br/>Corporate Name  : Property First<br/>JobRole  : Marketing Head<br/>Job Description  : <p>looking a marketing executive officer for&nbsp;property sales marketing&nbsp;</p>
<br/><br/>In case you don''t find the above details appropriate, <a href=://18.219.209.88:83/JobSeekerManagement/Profile>update profile</a> and apply again.<br/><br/>Recruiters will be contacting you on this mobile number +91<br/>To update it, please <a href=://18.219.209.88:83/JobSeekerManagement/Profile>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-21 14:57:20.190' AS DateTime), NULL, NULL, N'propertyfirst@inbox-me.top', N'aayodhatest@icanav.net', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (24, 2, 6, N'You have recevied one job application', N'Dear Property First ,<br/><br/> You have received a new application for the job post Property Sales and Marketing <br/><br/>JobRole  : Marketing Head<br/>Job Description  : <p>looking a marketing executive officer for&nbsp;property sales marketing&nbsp;</p>
<br/>Job Posted On  : 8/20/2020 6:15:34 AM<br/><br/>To Check Completed details please <a href=://18.219.209.88:83/Job/JobDetails/?jobid=6>click here</a><br><br>Thank You<br>Placement Portal Team', 0, NULL, 2, CAST(N'2020-08-21 14:57:21.307' AS DateTime), NULL, NULL, N'aayodhatest@icanav.net', N'propertyfirst@inbox-me.top', 6)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (25, NULL, 9, N'Welcome to SRJobPortal.com', N'<b>Dear rajesh</b>,<br/><br/>Congratulations! You have successfully registered with SRJobPortal.com<br/><br/>Please note that your username and password are both case sensitive.<br/><br/>Your login details are below:<br/><br/>User Name: rajeshkprajapati@gmail.com<br>Password: 123456<br/><br/>You can update your contact and registration details at any time by logging on to SRJobPortal.com<br/><br/>Wish you all the best!<br/><a href=http://18.219.209.88:83/Auth/JobSeekerLogin> SrJobPortal.com</a> Team', 0, NULL, -1, CAST(N'2020-08-24 03:53:52.247' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'rajeshkprajapati@gmail.com', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (26, NULL, 10, N'Welcome to SRJobPortal.com', N'<b>Dear Amardeep</b>,<br/><br/>Congratulations! You have successfully registered with SRJobPortal.com<br/><br/>Please note that your username and password are both case sensitive.<br/><br/>Your login details are below:<br/><br/>User Name: amardeepkmr86@gmail.com<br>Password: amardeep<br/><br/>You can update your contact and registration details at any time by logging on to SRJobPortal.com<br/><br/>Wish you all the best!<br/><a href=http://18.219.209.88:83/Auth/JobSeekerLogin> SrJobPortal.com</a> Team', 0, NULL, -1, CAST(N'2020-08-28 08:25:31.280' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'amardeepkmr86@gmail.com', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (27, NULL, 10, N'Account Approval', N'Dear                                     Amardeep                                ,<br/>You have successfully registered with us.You are one step away to explore our application.<br/><br/>Please <a href=://18.219.209.88:83/Auth/Index>click here</a> to proceed.<br/><br/><br/>Thank You<br/>Placement Portal Team', 0, NULL, 10, CAST(N'2020-08-28 08:51:26.900' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'amardeepkmr86@gmail.com', 4)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (28, NULL, 11, N'Welcome to SRJobPortal.com', N'<b>Dear Suresh</b>,<br/><br/>Congratulations! You have successfully registered with SRJobPortal.com<br/><br/>Please note that your username and password are both case sensitive.<br/><br/>Your login details are below:<br/><br/>User Name: rikiye9539@delotti.com<br>Password: Test@123<br/><br/>You can update your contact and registration details at any time by logging on to SRJobPortal.com<br/><br/>Wish you all the best!<br/><a href=http://18.219.209.88:83/Auth/JobSeekerLogin> SrJobPortal.com</a> Team', 0, NULL, -1, CAST(N'2020-08-28 14:59:56.633' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'rikiye9539@delotti.com', 5)
SET IDENTITY_INSERT [dbo].[EmailQueue] OFF
SET IDENTITY_INSERT [dbo].[EmployerFollower] ON 

INSERT [dbo].[EmployerFollower] ([ID], [JobSeekerID], [EmployerID], [CreatedDate], [IsActive]) VALUES (1, 2, 4, CAST(N'2020-08-19 14:59:19.200' AS DateTime), 1)
INSERT [dbo].[EmployerFollower] ([ID], [JobSeekerID], [EmployerID], [CreatedDate], [IsActive]) VALUES (2, 7, 5, CAST(N'2020-08-20 07:08:39.950' AS DateTime), 1)
SET IDENTITY_INSERT [dbo].[EmployerFollower] OFF
SET IDENTITY_INSERT [dbo].[EmploymentStatus] ON 

INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'Full Time', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, N'Part Time', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (3, N'Free Lancer', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (4, N'Contract', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (5, N'Not Disclosed', 1, NULL, NULL, NULL, NULL)
SET IDENTITY_INSERT [dbo].[EmploymentStatus] OFF
SET IDENTITY_INSERT [dbo].[EmploymentType] ON 

INSERT [dbo].[EmploymentType] ([EmploymentTypeId], [EmploymentTypeName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'Manager', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentType] ([EmploymentTypeId], [EmploymentTypeName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, N'Junior Designer', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentType] ([EmploymentTypeId], [EmploymentTypeName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (3, N'Senior Developer', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentType] ([EmploymentTypeId], [EmploymentTypeName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (4, N'Mid Level Designer', 1, NULL, NULL, NULL, NULL)
SET IDENTITY_INSERT [dbo].[EmploymentType] OFF
SET IDENTITY_INSERT [dbo].[Gender] ON 

INSERT [dbo].[Gender] ([GenderId], [GenderCode], [Gender], [IsActive]) VALUES (1, N'male', N'Male', 1)
INSERT [dbo].[Gender] ([GenderId], [GenderCode], [Gender], [IsActive]) VALUES (2, N'female', N'Female', 1)
INSERT [dbo].[Gender] ([GenderId], [GenderCode], [Gender], [IsActive]) VALUES (3, N'all', N'ALL', 1)
SET IDENTITY_INSERT [dbo].[Gender] OFF
SET IDENTITY_INSERT [dbo].[ITSkills] ON 

INSERT [dbo].[ITSkills] ([Id], [Skill], [SkillVersion], [LastUsed], [ExperienceYear], [ExperienceMonth], [CreatedDate], [CreatedBy], [UpdateDate], [UpdatedBy], [Status]) VALUES (1, N'C#', N'2020', N'2012', N'2', N'', CAST(N'2020-08-07 15:30:50.027' AS DateTime), N'2', CAST(N'2020-08-07 15:56:23.850' AS DateTime), N'2', 1)
INSERT [dbo].[ITSkills] ([Id], [Skill], [SkillVersion], [LastUsed], [ExperienceYear], [ExperienceMonth], [CreatedDate], [CreatedBy], [UpdateDate], [UpdatedBy], [Status]) VALUES (2, N'Java core', N'2020', N'2011', N'2', N'1', CAST(N'2020-08-07 15:33:12.110' AS DateTime), N'2', NULL, NULL, 1)
INSERT [dbo].[ITSkills] ([Id], [Skill], [SkillVersion], [LastUsed], [ExperienceYear], [ExperienceMonth], [CreatedDate], [CreatedBy], [UpdateDate], [UpdatedBy], [Status]) VALUES (3, N'JAVA', N'2020', N'2017', N'3', N'2', CAST(N'2020-08-28 15:03:52.270' AS DateTime), N'11', NULL, NULL, 1)
SET IDENTITY_INSERT [dbo].[ITSkills] OFF
SET IDENTITY_INSERT [dbo].[JobIndustryArea] ON 

INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'Banking', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, N'BFSI', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (3, N'Business Process Outsourcing (BPO)', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (4, N'Consumer Services', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (5, N'E-Commerce', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (6, N'Education & Training', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (7, N'Electronics', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (8, N'Information Technology', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (9, N'IT Consulting', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (10, N'IT Services', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (11, N'Knowledge Process Outsourcing (KPO)', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (12, N'Marketing', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (13, N'NBFC', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (14, N'Other', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (15, N'Publishing House', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (16, N'Retail', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (17, N'Telecom', 1, NULL, CAST(N'2020-04-03 18:32:15.110' AS DateTime), NULL, NULL)
SET IDENTITY_INSERT [dbo].[JobIndustryArea] OFF
SET IDENTITY_INSERT [dbo].[JobPostDetail] ON 

INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (1, 1, N'IN', N'AR', N'DIBL', 1, NULL, N'c++', NULL, 11, NULL, N'2020-08-14', N'2020-09-14', N'MCA', 1, N'4', CAST(N'2020-08-14 15:03:43.777' AS DateTime), N'4', CAST(N'2020-08-14 15:21:38.153' AS DateTime), 1, NULL, N'<p>Need Qualified person and in depth knowlwdge</p>', 4, N'Jecab', N'covid_19@amail.in', N'9876543210', N'1', 0, 0, 0, 0, 1, N'Software Enginnering', -1, -1, 2020, 1, 0, NULL, 1)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (2, 2, N'IN', N'AN', N'ANDZ', 2, NULL, N'Java', NULL, 1, NULL, N'2020-08-19', N'2020-09-19', N'B.tech', 1, N'4', CAST(N'2020-08-19 14:48:36.433' AS DateTime), NULL, NULL, 1, NULL, N'<p>Test the details</p>
', 4, N'John', N'adf2@mail.in', N'098765321', N'12', 0, 0, 0, 0, 1, N'Test', -1, -1, 2020, 2, 0, NULL, 1)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (3, 5, N'IN', N'MH', N'MUMP', 1, NULL, N'Marketing, sales', NULL, 2, NULL, N'2020-08-20', N'2020-09-20', N'BA, MBA, BBA', 1, N'5', CAST(N'2020-08-20 05:53:02.817' AS DateTime), NULL, NULL, 1, NULL, N'<p>looking a candidate that could understand marketing strategy and improve sales of electronic department</p>
', 5, N'manas', N'techfirst@senduvu.com', N'9087654321', N'400000', 0, 0, 0, 0, 0, N'Ecommerce Executive', -1, -1, 2020, NULL, 0, NULL, 1)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (4, 6, N'IN', N'DL', N'CENC', 1, NULL, N'Teaching, Training', NULL, 2, NULL, N'2020-08-20', N'2020-09-20', N'BA, MBA, BBA', 1, N'5', CAST(N'2020-08-20 05:59:33.823' AS DateTime), NULL, NULL, 1, NULL, N'<p>Looking for a trainer cum teacher that could make our training sector better</p>
', 5, N'Manas', N'techfirst@senduvu.com', N'9087654321', N'500000', 0, 0, 0, 0, 0, N'Academic Instructor Verbal', -1, -1, 2020, NULL, 0, NULL, 1)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (5, 8, N'IN', N'UP', N'NOI', 1, NULL, N'Java,jquery,my sql,html 5, css', NULL, 79, NULL, N'2020-08-20', N'2020-09-20', N'B.Tech,BCA', 1, N'6', CAST(N'2020-08-20 06:10:36.493' AS DateTime), NULL, NULL, 1, NULL, N'<p>looking for a software developer and designer that could work with our us client according us timing.</p>
', 6, N'Gopal', N'propertyfirst@inbox-me.top', N'8907654321', N'700000', 0, 0, 0, 0, 0, N'Software Developer and UI designer', -1, -1, 2020, NULL, 0, NULL, 1)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (6, 12, N'IN', N'UP', N'LUCE', 5, NULL, N'sales, marketing', NULL, 2, NULL, N'2020-08-20', N'2020-09-20', N'MBA, BBA', 1, N'6', CAST(N'2020-08-20 06:15:34.843' AS DateTime), NULL, NULL, 1, NULL, N'<p>looking a marketing executive officer for&nbsp;property sales marketing&nbsp;</p>
', 6, N'Gopal', N'propertyfirst@inbox-me.top', N'8907654321', N'800000', 0, 0, 0, 0, 0, N'Property Sales and Marketing ', -1, -1, 2020, NULL, 0, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (7, 16, N'IN', N'PB', N'AJIH', 1, NULL, N'Marketing analyst , sales, marketing', NULL, 1, NULL, N'2020-08-20', N'2020-09-20', N'BA, MBA, BBA', 1, N'7', CAST(N'2020-08-20 06:26:11.300' AS DateTime), NULL, NULL, 1, NULL, N'<p>Looking for stuff that could do administration work as well as marketing department</p>
', 7, N'Manohar lal', N'wheelblance@senduvu.com', N'7890654321', N'700000', 0, 0, 0, 0, 0, N'Retail Store Administrator ', -1, -1, 2020, NULL, 0, NULL, 1)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (8, 17, N'IN', N'PB', N'AMRV', 1, NULL, N'BA, MBA, BBA', NULL, 4, NULL, N'2020-08-20', N'2020-09-20', N'MBA, BBA', 1, N'7', CAST(N'2020-08-20 06:32:56.357' AS DateTime), NULL, NULL, 1, NULL, N'<p>this is test doc for job portal</p>
', 7, N'Manik', N'wheelblance@senduvu.com', N'7890654321', N'560000', 0, 0, 0, 0, 0, N'Mobile and communicator trainee ', -1, -1, 2020, NULL, 0, NULL, 1)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (9, 4, N'IN', N'UP', N'NOI', 5, NULL, N'', NULL, 0, NULL, N'29-Jun-20 12:00:00 AM', N'25-Aug-20 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-21 15:00:18.547' AS DateTime), NULL, NULL, 2, NULL, N'Software Development releted work', 4, N'Test1', N'shiv.singh@steeprise1.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Senior Software Developer', 5, 8, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (10, 4, N'IN', N'UP', N'NOI', 5, NULL, N'', NULL, 0, NULL, N'29-Jun-20 12:00:00 AM', N'25-Aug-20 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-21 15:00:25.340' AS DateTime), NULL, NULL, 2, NULL, N'Software Development releted work', 4, N'Test3', N'rajesh.prajapati@steeprise3.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Associate Software Engineer', 2, 4, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (11, 4, N'IN', N'UP', N'GHAC', 5, NULL, N'', NULL, 0, NULL, N'29-Jun-20 12:00:00 AM', N'25-Aug-20 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-21 15:00:28.503' AS DateTime), NULL, NULL, 2, NULL, N'Software Development releted work', 4, N'Test4', N'rajesh.prajapati@steeprise3.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Software Trainee', 3, 6, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (12, 4, N'IN', N'UP', N'GHAC', 5, NULL, N'', NULL, 0, NULL, N'29-Jun-20 12:00:00 AM', N'25-Aug-20 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-21 15:00:31.700' AS DateTime), NULL, NULL, 2, NULL, N'Software Development releted work', 4, N'Test5', N'avanesh.sharma@steeprise3.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Business Development Analyst', 4, 5, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (13, 4, N'IN', N'UP', N'NOI', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 07:23:40.253' AS DateTime), NULL, NULL, 2, NULL, N'QA Automation', 4, N'Test11', N'shiv.singh@steeprise11.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Senior Software Developer', 5, 8, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (14, 4, N'IN', N'UP', N'NOI', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 07:23:40.480' AS DateTime), NULL, NULL, 2, NULL, N'QA Automation', 4, N'Test33', N'rajesh.prajapati@steeprise33.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Associate Software Engineer', 2, 4, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (15, 4, N'IN', N'UP', N'GHAC', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 07:23:40.583' AS DateTime), NULL, NULL, 2, NULL, N'QA Automation', 4, N'Test44', N'rajesh.prajapati@steeprise34.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Software Trainee', 3, 6, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (16, 4, N'IN', N'UP', N'GHAC', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 07:23:40.690' AS DateTime), NULL, NULL, 2, NULL, N'QA Automation', 4, N'Test55', N'avanesh.sharma@steeprise31.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Business Development Analyst', 4, 5, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (17, 4, N'IN', N'UP', N'NOI', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 08:08:22.440' AS DateTime), NULL, NULL, 2, NULL, N'Test bulk job upload', 4, N'Test11', N'shiv.singh@steeprise11.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Senior Software Developer', 5, 8, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (18, 4, N'IN', N'UP', N'NOI', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 08:08:22.673' AS DateTime), NULL, NULL, 2, NULL, N'Test bulk job upload', 4, N'Test33', N'rajesh.prajapati@steeprise33.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Associate Software Engineer', 2, 4, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (19, 4, N'IN', N'UP', N'GHAC', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 08:08:22.783' AS DateTime), NULL, NULL, 2, NULL, N'Test bulk job upload', 4, N'Test44', N'rajesh.prajapati@steeprise34.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Software Trainee', 3, 6, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (20, 4, N'IN', N'UP', N'GHAC', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 08:08:22.897' AS DateTime), NULL, NULL, 2, NULL, N'Test bulk job upload', 4, N'Test55', N'avanesh.sharma@steeprise31.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Business Development Analyst', 4, 5, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (21, 4, N'IN', N'UP', N'NOI', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 08:08:23.007' AS DateTime), NULL, NULL, 2, NULL, N'Test bulk job upload', 4, N'Test11', N'shiv.singh@steeprise111.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Software Developer', 5, 8, 0, NULL, 1, NULL, 0)
INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn]) VALUES (22, 4, N'IN', N'UP', N'NOI', 5, NULL, N'', NULL, 0, NULL, N'6/29/2020 12:00:00 AM', N'8/25/2020 12:00:00 AM', N'B.Tech.(CS,IT)', 1, N'4', CAST(N'2020-08-24 08:08:23.117' AS DateTime), NULL, NULL, 2, NULL, N'Test bulk job upload', 4, N'Test22', N'shiv.singh@steeprise222.com', N'+919718661083', N'900000', 0, 0, 0, 0, 0, N'Software Development Engineer', 7, 9, 0, NULL, 1, NULL, 0)
SET IDENTITY_INSERT [dbo].[JobPostDetail] OFF
SET IDENTITY_INSERT [dbo].[JobRoleMapping] ON 

INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (2, 1, 2)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (3, 2, 1)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (4, 3, 93)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (5, 4, 77)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (6, 5, 2)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (7, 6, 7)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (8, 7, 92)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (9, 8, 74)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (10, 9, 112)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (11, 10, 113)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (12, 11, 114)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (13, 12, 115)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (14, 13, 112)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (15, 14, 113)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (16, 15, 114)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (17, 16, 115)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (18, 17, 112)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (19, 18, 113)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (20, 19, 114)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (21, 20, 115)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (22, 21, 2)
INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (23, 22, 116)
SET IDENTITY_INSERT [dbo].[JobRoleMapping] OFF
SET IDENTITY_INSERT [dbo].[JobTitle] ON 

INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'Web Manager', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, N'Software Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (3, N'IT Head', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (4, N'Manager', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (5, N'Web Designer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (6, N'Administrator', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (7, N'Marketing Head', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (8, N'Field Engg', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (9, N'Accountant', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (10, N'CRM- Voice', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (11, N'Foundation of Skills Internet IOT', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (12, N'DTP and Print Publishing AssistantDTP and Print Publishing Assistant', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (13, N'BPO-Non Voice', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (14, N'BPO Voice', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (15, N'Web Designing and Publishing Assistant', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (16, N'Engineer-Technical Support(Level 1)', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (17, N'Domestic IT Helpdesk Attendant', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (18, N'Application Maintenance Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (19, N'Deployment Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (20, N'Junior Data Associate', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (21, N'Software Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (22, N'UI Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (23, N'Web Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (24, N'Media Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (25, N'Technical Writer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (26, N'Language Translator', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (27, N'Engineer Trainee', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (28, N'Junior Software Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (29, N'Master Trainer for Junior Software Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (30, N'Analyst', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (31, N'Infrastructure Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (32, N'Security Analyst', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (33, N'Security Analyst Book 1', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (34, N'Security Analyst Book 2', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (35, N'Security Analyst Book 3', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (36, N'Analyst Application Security', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (37, N'Analyst Identity and Access Management', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (38, N'Analyst Endpoint Security', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (39, N'Analyst Compliance Audit', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (40, N'Analyst Security Operations Centre', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (41, N'Penetration Tester', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (42, N'Consultant Network Security ', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (43, N'Forensic specialist', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (44, N'Security Infrastructure Specialist', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (45, N'Architect Identity and Access Management', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (46, N'Sales and Pre-Sales Analyst', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (47, N'Test Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (48, N'QA Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (49, N'Associate - Analytics ', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (50, N'Associate-Analytics', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (51, N'Associate - Customer Care (Non-Voice)', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (52, N'Associate - CRM', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (53, N'CRM Domestic Voice', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (54, N'CRM Domestic Non-Voice', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (55, N'Domestic Data Entry Operator', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (56, N'Domestic Biometric Data Operator', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (57, N'Collections Executive', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (58, N'Associate - Transactional F&A ', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (59, N'Associate-Transactional F & A', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (60, N'Associate - F&A Complex ', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (61, N'Associate-F & A Complex Book 1', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (62, N'Associate-F & A Complex Book 2', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (63, N'Associate - Clinical Data Management', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (64, N'Associate-Medical Transcription', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (65, N'Associate-Recruitment', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (66, N'Associate - HRO ', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (67, N'Analyst - Research', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (68, N'Associate - Editorial', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (69, N'Associate - Desktop Publishing(DTP)', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (70, N'Associate-Learning', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (71, N'Document Coder/Processor', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (72, N'Legal Associate', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (73, N'Associate - SCM ', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (74, N'Management Trainee - Marketing', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (75, N'Market Research Associate', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (76, N'Product Design Engineer - Mechanical', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (77, N'Engineer Trainee', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (78, N'Design Engineer - PMS', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (79, N'Design Engineer - EA', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (80, N'Technical Writer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (81, N'Software Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (82, N'Hardware Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (83, N'Quality Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (84, N'Test Engineer - Software', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (85, N'Test Engineer - Hardware', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (86, N'Technical Support Engineer ', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (87, N'Engineer - Product Lifecycle Management (PLM)', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (88, N'Research Associate', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (89, N'Support Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (90, N'IP Executive', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (91, N'Management Trainee', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (92, N'Market Research Associate', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (93, N'Sales/Pre-Sales Executive', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (94, N'Product Executive', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (95, N'Design Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (96, N'Software Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (97, N'Media Developer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (98, N'Technical Writer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (99, N'Language Translator', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
GO
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (100, N'Engineer-Packaging', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (101, N'Test Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (102, N'QA Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (103, N'Engineer-Software Transition', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (104, N'Communications Analyst', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (105, N'AI - Machine Learning Engineer', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (106, N'Cloud Computing', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (107, N'IoT - Product Manager', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (108, N'marketing manager', 1, N'Admin', CAST(N'2020-04-03 18:08:53.273' AS DateTime), NULL, CAST(N'2020-05-12 17:47:45.823' AS DateTime))
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (109, N'Test Job tielsadfd', 0, NULL, CAST(N'2020-07-08 19:55:35.320' AS DateTime), N'1', CAST(N'2020-07-08 20:10:51.520' AS DateTime))
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (110, N'Job title test', 1, NULL, CAST(N'2020-07-08 20:12:46.457' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (111, N'dfdf', 0, NULL, CAST(N'2020-07-17 16:14:15.627' AS DateTime), N'1', CAST(N'2020-07-17 16:14:45.003' AS DateTime))
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (112, N'Senior Software Developer', 1, N'BulkJobPost', CAST(N'2020-08-21 15:00:15.940' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (113, N'Associate Software Engineer', 1, N'BulkJobPost', CAST(N'2020-08-21 15:00:22.833' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (114, N'Software Trainee', 1, N'BulkJobPost', CAST(N'2020-08-21 15:00:26.043' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (115, N'Business Development Analyst', 1, N'BulkJobPost', CAST(N'2020-08-21 15:00:29.193' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (116, N'Software Development Engineer', 1, N'BulkJobPost', CAST(N'2020-08-24 08:08:23.030' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (117, N'C# Developer', 1, N'BulkJobPost', CAST(N'2020-08-24 08:08:23.493' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (118, N'Java Developer', 1, N'BulkJobPost', CAST(N'2020-08-24 08:08:23.590' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (119, N'.NET Developer', 1, N'BulkJobPost', CAST(N'2020-08-24 08:08:23.687' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (120, N'Unity Developer', 1, N'BulkJobPost', CAST(N'2020-08-24 08:08:23.783' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (121, N'Ruby Developer', 1, N'BulkJobPost', CAST(N'2020-08-24 08:08:23.880' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (122, N'Senior Analyst', 1, N'BulkJobPost', CAST(N'2020-08-24 08:08:23.977' AS DateTime), NULL, NULL)
SET IDENTITY_INSERT [dbo].[JobTitle] OFF
SET IDENTITY_INSERT [dbo].[JobTypes] ON 

INSERT [dbo].[JobTypes] ([Id], [Type], [IsActive]) VALUES (1, N'Fresher', 1)
INSERT [dbo].[JobTypes] ([Id], [Type], [IsActive]) VALUES (2, N'Experience', 1)
INSERT [dbo].[JobTypes] ([Id], [Type], [IsActive]) VALUES (3, N'Any', 1)
SET IDENTITY_INSERT [dbo].[JobTypes] OFF
SET IDENTITY_INSERT [dbo].[Logging] ON 

INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (1, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 36\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-05 13:07:30.050' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (2, N'Error', N'Seems this user already exists in our record, please login with previous credentials.', NULL, N'{"Message":"Seems this user already exists in our record, please login with previous credentials.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Auth.AuthHandler.RegisterUser(JobSeekerViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 69\r\n   at JobPortal.Web.Controllers.AuthController.JobseekerRegistration(JobSeekerViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 664","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-05 13:16:24.093' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (3, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 63","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-05 13:18:55.580' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (4, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 36\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-05 13:19:30.650' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (5, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 36\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-05 13:26:27.440' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (6, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 36\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-06 05:28:53.107' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (7, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 63","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-07 15:24:48.347' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (8, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 36\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-07 15:25:07.787' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (9, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 36\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-07 15:34:04.760' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (10, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 36\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-07 15:35:43.580' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (11, N'Error', N'Data not found', NULL, N'{"Message":"Data not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Employer.SearchResume.SearchResumeRepository.GetSearchResumeList(SearchResumeModel searches) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Employer\\SearchResume\\SearchResumeRepository.cs:line 53\r\n   at JobPortal.Business.Handlers.Employer.SearchResume.SearchResumeHandler.GetSearchResumeList(SearchResumeViewModel searches) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\SearchResume\\SearchResumeHandler.cs:line 45\r\n   at JobPortal.Web.Areas.Employer.Controllers.SearchResumeController.SearchResumeList(SearchResumeViewModel searches) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\SearchResumeController.cs:line 78","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'SearchResumeController', CAST(N'2020-08-07 15:38:33.920' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (12, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 36\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-07 16:00:20.120' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (13, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 63","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-11 14:37:03.160' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (14, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 14:52:36.947' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (15, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:30:49.580' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (16, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 117","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:31:02.883' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (17, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:31:04.520' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (18, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 117","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:02.883' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (19, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 117","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:25.300' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (20, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 117","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:34.100' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (21, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:37.790' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (22, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 117","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:47.193' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (23, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:48.333' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (24, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:49.983' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (25, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:51.860' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (26, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 117","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:53.780' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (27, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:34:54.903' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (28, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:35:13.923' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (29, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 35\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-11 15:38:40.747' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (30, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 35\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-11 15:38:48.770' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (31, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 35\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 58","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-11 15:39:06.223' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (32, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:43:21.830' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (33, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 117","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:43:24.950' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (34, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:43:30.157' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (35, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 117","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:43:30.787' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (36, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 136","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-11 15:43:32.017' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (37, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 59","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-14 14:26:38.613' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (38, N'Error', N'Messages not found', NULL, N'{"Message":"Messages not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetMessages(DateTime msgsOnDate, Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 411\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetMessages(String date) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 239","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:26:59.450' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (39, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 118","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:27:03.920' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (40, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 118","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:27:10.103' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (41, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 137","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:27:10.843' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (42, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 137","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:27:52.413' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (43, N'Error', N'Messages not found', NULL, N'{"Message":"Messages not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetMessages(DateTime msgsOnDate, Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 411\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetMessages(String date) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 239","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:29:01.503' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (44, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 118","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:29:38.163' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (45, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 118","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:29:43.040' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (46, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 118","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:29:46.070' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (47, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 118","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:29:49.893' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (48, N'Error', N'Messages not found', NULL, N'{"Message":"Messages not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetMessages(DateTime msgsOnDate, Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 411\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetMessages(String date) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 239","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:29:56.810' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (49, N'Error', N'Messages not found', NULL, N'{"Message":"Messages not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetMessages(DateTime msgsOnDate, Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 411\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetMessages(String date) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 239","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-14 14:31:34.053' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (50, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 35\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 54","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-14 14:59:53.557' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (51, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 35\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 54","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-14 14:59:58.853' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (52, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 35\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 54","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-14 15:00:30.713' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (53, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 35\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 54","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-14 15:23:33.820' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (54, N'Error', N'Messages not found', NULL, N'{"Message":"Messages not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetMessages(DateTime msgsOnDate, Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 411\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetMessages(String date) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 239","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-19 14:47:04.677' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (55, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 118","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-19 14:47:16.083' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (56, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 103\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 118","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-19 14:47:18.577' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (57, N'Error', N'Job seekers for dashboard found, please contact your tech deck.', NULL, N'{"Message":"Job seekers for dashboard found, please contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Employer.DashboardRepository.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Employer\\DashboardRepository.cs:line 272\r\n   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 260\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekersBasedOnEmployerHiringCriteria(String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 90","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-19 14:47:20.800' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (58, N'Error', N'Job seekers for dashboard found, please contact your tech deck.', NULL, N'{"Message":"Job seekers for dashboard found, please contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Employer.DashboardRepository.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Employer\\DashboardRepository.cs:line 272\r\n   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 260\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekersBasedOnEmployerHiringCriteria(String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 90","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-19 14:47:29.937' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (59, N'Error', N'Jobseekers not found', NULL, N'{"Message":"Jobseekers not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekers(Int32 empId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 211\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekers() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 137","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-19 14:47:32.683' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (60, N'Error', N'Can not execute query', NULL, N'{"Message":"Can not execute query","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Home.HomeRepositories.ViewAllFeaturedJobs() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Home\\HomeRepositories.cs:line 329\r\n   at JobPortal.Business.Handlers.Home.HomeHandler.ViewAllFeaturedJobs() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Home\\HomeHandler.cs:line 243\r\n   at JobPortal.Web.Areas.Admin.Controllers.ManageJobsController.FeaturedJobs() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Admin\\Controllers\\ManageJobsController.cs:line 41","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'ManageJobsController', CAST(N'2020-08-19 14:49:19.950' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (61, N'Error', N'To apply job please complete your profile', NULL, N'{"Message":"To apply job please complete your profile","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Jobseeker.UserProfileHandler.ApplyJobDetails(UserViewModel user, Int32 jobPostId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Jobseeker\\UserProfileHandler.cs:line 380\r\n   at JobPortal.Web.Areas.Jobseeker.Controllers.JobController.ApplyJob(Int32 jobPostId, String currentUrl) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Jobseeker\\Controllers\\JobController.cs:line 122","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'JobController', CAST(N'2020-08-19 14:58:24.583' AS DateTime), 2)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (62, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-19 15:05:02.447' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (63, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-20 05:44:01.167' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (64, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-20 05:44:10.203' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (65, N'Error', N'Job seekers for dashboard found, please contact your tech deck.', NULL, N'{"Message":"Job seekers for dashboard found, please contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Employer.DashboardRepository.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Employer\\DashboardRepository.cs:line 272\r\n   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 260\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekersBasedOnEmployerHiringCriteria(String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 90","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-20 07:02:23.850' AS DateTime), 6)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (66, N'Error', N'Could not find stored procedure ''usp_GetCategoryJobVacancies''.', NULL, N'{"ClassName":"System.Data.SqlClient.SqlException","Message":"Could not find stored procedure ''usp_GetCategoryJobVacancies''.","Data":{"HelpLink.ProdName":"Microsoft SQL Server","HelpLink.ProdVer":"12.00.6329","HelpLink.EvtSrc":"MSSQLServer","HelpLink.EvtID":"2812","HelpLink.BaseHelpUrl":"https://go.microsoft.com/fwlink","HelpLink.LinkId":"20476","SqlError 1":"System.Data.SqlClient.SqlError: Could not find stored procedure ''usp_GetCategoryJobVacancies''."},"InnerException":null,"HelpURL":null,"StackTraceString":"   at System.Data.SqlClient.SqlConnection.OnError(SqlException exception, Boolean breakConnection, Action`1 wrapCloseInAction)\r\n   at System.Data.SqlClient.TdsParser.ThrowExceptionAndWarning(TdsParserStateObject stateObj, Boolean callerHasConnectionLock, Boolean asyncClose)\r\n   at System.Data.SqlClient.TdsParser.TryRun(RunBehavior runBehavior, SqlCommand cmdHandler, SqlDataReader dataStream, BulkCopySimpleResultSet bulkCopyHandler, TdsParserStateObject stateObj, Boolean& dataReady)\r\n   at System.Data.SqlClient.SqlDataReader.TryConsumeMetaData()\r\n   at System.Data.SqlClient.SqlDataReader.get_MetaData()\r\n   at System.Data.SqlClient.SqlCommand.FinishExecuteReader(SqlDataReader ds, RunBehavior runBehavior, String resetOptionsString)\r\n   at System.Data.SqlClient.SqlCommand.RunExecuteReaderTds(CommandBehavior cmdBehavior, RunBehavior runBehavior, Boolean returnStream, Boolean async, Int32 timeout, Task& task, Boolean asyncWrite, SqlDataReader ds)\r\n   at System.Data.SqlClient.SqlCommand.ExecuteReader(CommandBehavior behavior)\r\n   at System.Data.Common.DbCommand.System.Data.IDbCommand.ExecuteReader(CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.FillInternal(DataSet dataset, DataTable[] datatables, Int32 startRecord, Int32 maxRecords, String srcTable, IDbCommand command, CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.Fill(DataSet dataSet, Int32 startRecord, Int32 maxRecords, String srcTable, IDbCommand command, CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.Fill(DataSet dataSet)\r\n   at JobPortal.Data.Helper.SqlHelper.ExecuteDataset(SqlConnection connection, CommandType commandType, String commandText, SqlParameter[] commandParameters) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Helper\\SQLHelper.cs:line 616\r\n   at JobPortal.Data.Helper.SqlHelper.ExecuteDataset(SqlConnection connection, CommandType commandType, String commandText) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Helper\\SQLHelper.cs:line 585\r\n   at JobPortal.Data.Repositories.Home.HomeRepositories.CategoryJobVacancies() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Home\\HomeRepositories.cs:line 755\r\n   at JobPortal.Business.Handlers.Home.HomeHandler.CategoryJobVacancies() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Home\\HomeHandler.cs:line 586\r\n   at JobPortal.Web.Controllers.HomeController.FindJobVacancies() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\HomeController.cs:line 503\r\n   at lambda_method(Closure , Object , Object[] )\r\n   at Microsoft.Extensions.Internal.ObjectMethodExecutor.Execute(Object target, Object[] parameters)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ActionMethodExecutor.SyncActionResultExecutor.Execute(IActionResultTypeMapper mapper, ObjectMethodExecutor executor, Object controller, Object[] arguments)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeActionMethodAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeNextActionFilterAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.Rethrow(ActionExecutedContext context)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeInnerFilterAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ResourceInvoker.InvokeNextExceptionFilterAsync()","RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2146232060,"Source":"Core .Net SqlClient Data Provider","WatsonBuckets":null,"Errors":null,"ClientConnectionId":"8b5e7ea7-8901-48c7-aa57-e344cf7c214b"}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'HandleExceptions', CAST(N'2020-08-21 14:53:50.180' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (67, N'Error', N'A network-related or instance-specific error occurred while establishing a connection to SQL Server. The server was not found or was not accessible. Verify that the instance name is correct and that SQL Server is configured to allow remote connections. (provider: Named Pipes Provider, error: 40 - Could not open a connection to SQL Server)', NULL, N'{"ClassName":"System.Data.SqlClient.SqlException","Message":"A network-related or instance-specific error occurred while establishing a connection to SQL Server. The server was not found or was not accessible. Verify that the instance name is correct and that SQL Server is configured to allow remote connections. (provider: Named Pipes Provider, error: 40 - Could not open a connection to SQL Server)","Data":{"HelpLink.ProdName":"Microsoft SQL Server","HelpLink.EvtSrc":"MSSQLServer","HelpLink.EvtID":"53","HelpLink.BaseHelpUrl":"https://go.microsoft.com/fwlink","HelpLink.LinkId":"20476","SqlError 1":"System.Data.SqlClient.SqlError: A network-related or instance-specific error occurred while establishing a connection to SQL Server. The server was not found or was not accessible. Verify that the instance name is correct and that SQL Server is configured to allow remote connections. (provider: Named Pipes Provider, error: 40 - Could not open a connection to SQL Server)"},"InnerException":{"ClassName":"System.ComponentModel.Win32Exception","Message":"The network path was not found","Data":null,"InnerException":null,"HelpURL":null,"StackTraceString":null,"RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2147467259,"Source":null,"WatsonBuckets":null,"NativeErrorCode":53},"HelpURL":null,"StackTraceString":"   at System.Data.SqlClient.SqlInternalConnectionTds..ctor(DbConnectionPoolIdentity identity, SqlConnectionString connectionOptions, SqlCredential credential, Object providerInfo, String newPassword, SecureString newSecurePassword, Boolean redirectedUserInstance, SqlConnectionString userConnectionOptions, SessionData reconnectSessionData, Boolean applyTransientFaultHandling, String accessToken)\r\n   at System.Data.SqlClient.SqlConnectionFactory.CreateConnection(DbConnectionOptions options, DbConnectionPoolKey poolKey, Object poolGroupProviderInfo, DbConnectionPool pool, DbConnection owningConnection, DbConnectionOptions userOptions)\r\n   at System.Data.ProviderBase.DbConnectionFactory.CreatePooledConnection(DbConnectionPool pool, DbConnection owningObject, DbConnectionOptions options, DbConnectionPoolKey poolKey, DbConnectionOptions userOptions)\r\n   at System.Data.ProviderBase.DbConnectionPool.CreateObject(DbConnection owningObject, DbConnectionOptions userOptions, DbConnectionInternal oldConnection)\r\n   at System.Data.ProviderBase.DbConnectionPool.UserCreateRequest(DbConnection owningObject, DbConnectionOptions userOptions, DbConnectionInternal oldConnection)\r\n   at System.Data.ProviderBase.DbConnectionPool.TryGetConnection(DbConnection owningObject, UInt32 waitForMultipleObjectsTimeout, Boolean allowCreate, Boolean onlyOneCheckConnection, DbConnectionOptions userOptions, DbConnectionInternal& connection)\r\n   at System.Data.ProviderBase.DbConnectionPool.TryGetConnection(DbConnection owningObject, TaskCompletionSource`1 retry, DbConnectionOptions userOptions, DbConnectionInternal& connection)\r\n   at System.Data.ProviderBase.DbConnectionFactory.TryGetConnection(DbConnection owningConnection, TaskCompletionSource`1 retry, DbConnectionOptions userOptions, DbConnectionInternal oldConnection, DbConnectionInternal& connection)\r\n   at System.Data.ProviderBase.DbConnectionInternal.TryOpenConnectionInternal(DbConnection outerConnection, DbConnectionFactory connectionFactory, TaskCompletionSource`1 retry, DbConnectionOptions userOptions)\r\n   at System.Data.SqlClient.SqlConnection.TryOpen(TaskCompletionSource`1 retry)\r\n   at System.Data.SqlClient.SqlConnection.Open()\r\n   at JobPortal.Data.Helper.SqlHelper.PrepareCommand(SqlCommand command, SqlConnection connection, SqlTransaction transaction, CommandType commandType, String commandText, SqlParameter[] commandParameters, Boolean& mustCloseConnection) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Data\\Helper\\SQLHelper.cs:line 175\r\n   at JobPortal.Data.Helper.SqlHelper.ExecuteDataset(SqlConnection connection, CommandType commandType, String commandText, SqlParameter[] commandParameters) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Data\\Helper\\SQLHelper.cs:line 608\r\n   at JobPortal.Data.Helper.SqlHelper.ExecuteDataset(SqlConnection connection, CommandType commandType, String commandText) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Data\\Helper\\SQLHelper.cs:line 585\r\n   at JobPortal.Data.Repositories.Employer.JobPost.JobPostRepository.GetJobIndustryAreaDetail() in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Data\\Repositories\\Employer\\JobPost\\JobPostRepository.cs:line 27\r\n   at JobPortal.Business.Handlers.Employer.JobPost.JobPostHandler.GetJobIndustryAreaDetails() in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\JobPost\\JobPostHandler.cs:line 48\r\n   at JobPortal.Web.Controllers.HomeController.Index() in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Web\\Controllers\\HomeController.cs:line 52\r\n   at lambda_method(Closure , Object , Object[] )\r\n   at Microsoft.Extensions.Internal.ObjectMethodExecutor.Execute(Object target, Object[] parameters)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ActionMethodExecutor.SyncActionResultExecutor.Execute(IActionResultTypeMapper mapper, ObjectMethodExecutor executor, Object controller, Object[] arguments)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeActionMethodAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeNextActionFilterAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.Rethrow(ActionExecutedContext context)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeInnerFilterAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ResourceInvoker.InvokeNextExceptionFilterAsync()","RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2146232060,"Source":"Core .Net SqlClient Data Provider","WatsonBuckets":null,"Errors":null,"ClientConnectionId":"00000000-0000-0000-0000-000000000000"}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'HandleExceptions', CAST(N'2020-08-21 15:02:44.330' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (68, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-21 15:21:19.987' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (69, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-21 15:26:53.977' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (70, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-21 15:38:53.243' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (71, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in E:\\Steeprise\\SRJobPortal\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-21 15:39:12.190' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (72, N'Error', N'Column ''Total'' does not belong to table .', NULL, N'{"ClassName":"System.ArgumentException","Message":"Column ''Total'' does not belong to table .","Data":null,"InnerException":null,"HelpURL":null,"StackTraceString":"   at System.Data.DataRow.GetDataColumn(String columnName)\r\n   at System.Data.DataRow.get_Item(String columnName)\r\n   at JobPortal.Business.Handlers.Shared.BulkJobPostHandler.AddSummary(DataRow row) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Shared\\BulkJobPostHandler.cs:line 647\r\n   at JobPortal.Business.Handlers.Shared.BulkJobPostHandler.UploadJobs(UserViewModel user, IList`1 files) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Shared\\BulkJobPostHandler.cs:line 87\r\n   at JobPortal.Web.Areas.Shared.Controllers.BulkJobPostController.UploadJobs(List`1 files, Boolean inBackground) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Shared\\Controllers\\BulkJobPostController.cs:line 54","RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2147024809,"Source":"System.Data.Common","WatsonBuckets":null,"ParamName":null}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'BulkJobPostController', CAST(N'2020-08-21 15:49:26.530' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (73, N'Error', N'Column ''Total'' does not belong to table .', NULL, N'{"ClassName":"System.ArgumentException","Message":"Column ''Total'' does not belong to table .","Data":null,"InnerException":null,"HelpURL":null,"StackTraceString":"   at System.Data.DataRow.GetDataColumn(String columnName)\r\n   at System.Data.DataRow.get_Item(String columnName)\r\n   at JobPortal.Business.Handlers.Shared.BulkJobPostHandler.AddSummary(DataRow row) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Shared\\BulkJobPostHandler.cs:line 647\r\n   at JobPortal.Business.Handlers.Shared.BulkJobPostHandler.UploadJobs(UserViewModel user, IList`1 files) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Shared\\BulkJobPostHandler.cs:line 87\r\n   at JobPortal.Web.Areas.Shared.Controllers.BulkJobPostController.UploadJobs(List`1 files, Boolean inBackground) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Shared\\Controllers\\BulkJobPostController.cs:line 54","RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2147024809,"Source":"System.Data.Common","WatsonBuckets":null,"ParamName":null}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'BulkJobPostController', CAST(N'2020-08-21 16:01:32.423' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (74, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 57","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-24 03:54:41.207' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (75, N'Error', N'Column ''Total'' does not belong to table .', NULL, N'{"ClassName":"System.ArgumentException","Message":"Column ''Total'' does not belong to table .","Data":null,"InnerException":null,"HelpURL":null,"StackTraceString":"   at System.Data.DataRow.GetDataColumn(String columnName)\r\n   at System.Data.DataRow.get_Item(String columnName)\r\n   at JobPortal.Business.Handlers.Shared.BulkJobPostHandler.AddSummary(DataRow row) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Shared\\BulkJobPostHandler.cs:line 647\r\n   at JobPortal.Business.Handlers.Shared.BulkJobPostHandler.UploadJobs(UserViewModel user, IList`1 files) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Shared\\BulkJobPostHandler.cs:line 87\r\n   at JobPortal.Web.Areas.Shared.Controllers.BulkJobPostController.UploadJobs(List`1 files, Boolean inBackground) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Shared\\Controllers\\BulkJobPostController.cs:line 54","RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2147024809,"Source":"System.Data.Common","WatsonBuckets":null,"ParamName":null}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'BulkJobPostController', CAST(N'2020-08-24 06:09:31.757' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (76, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 57","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-24 07:25:22.313' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (77, N'Error', N'Column ''SSCJobRole'' does not belong to table .', NULL, N'{"ClassName":"System.ArgumentException","Message":"Column ''SSCJobRole'' does not belong to table .","Data":null,"InnerException":null,"HelpURL":null,"StackTraceString":"   at System.Data.DataRow.GetDataColumn(String columnName)\r\n   at System.Data.DataRow.get_Item(String columnName)\r\n   at JobPortal.Business.Handlers.Employer.SearchResume.SearchResumeHandler.ShowCandidateDetails(Int32 employerId, Int32 jobSeekerId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\SearchResume\\SearchResumeHandler.cs:line 146\r\n   at JobPortal.Web.Areas.Employer.Controllers.SearchResumeController.ShowCandidateDetail(Int32 userId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\SearchResumeController.cs:line 97\r\n   at lambda_method(Closure , Object , Object[] )\r\n   at Microsoft.Extensions.Internal.ObjectMethodExecutor.Execute(Object target, Object[] parameters)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ActionMethodExecutor.SyncActionResultExecutor.Execute(IActionResultTypeMapper mapper, ObjectMethodExecutor executor, Object controller, Object[] arguments)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeActionMethodAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeNextActionFilterAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.Rethrow(ActionExecutedContext context)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.Next(State& next, Scope& scope, Object& state, Boolean& isCompleted)\r\n   at Microsoft.AspNetCore.Mvc.Internal.ControllerActionInvoker.InvokeInnerFilterAsync()\r\n   at Microsoft.AspNetCore.Mvc.Internal.ResourceInvoker.InvokeNextExceptionFilterAsync()","RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2147024809,"Source":"System.Data.Common","WatsonBuckets":null,"ParamName":null}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'HandleExceptions', CAST(N'2020-08-24 13:38:58.250' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (78, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 12:56:09.693' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (79, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 12:56:19.247' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (80, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 12:56:30.863' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (81, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 12:56:42.787' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (82, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 12:57:27.980' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (83, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 12:58:15.120' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (84, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 12:58:38.527' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (85, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 12:58:47.210' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (86, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-26 13:00:38.630' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (87, N'Error', N'Procedure or function usp_GetSearchList has too many arguments specified.', NULL, N'{"ClassName":"System.Data.SqlClient.SqlException","Message":"Procedure or function usp_GetSearchList has too many arguments specified.","Data":{"HelpLink.ProdName":"Microsoft SQL Server","HelpLink.ProdVer":"12.00.6329","HelpLink.EvtSrc":"MSSQLServer","HelpLink.EvtID":"8144","HelpLink.BaseHelpUrl":"https://go.microsoft.com/fwlink","HelpLink.LinkId":"20476","SqlError 1":"System.Data.SqlClient.SqlError: Procedure or function usp_GetSearchList has too many arguments specified."},"InnerException":null,"HelpURL":null,"StackTraceString":"   at System.Data.SqlClient.SqlConnection.OnError(SqlException exception, Boolean breakConnection, Action`1 wrapCloseInAction)\r\n   at System.Data.SqlClient.TdsParser.ThrowExceptionAndWarning(TdsParserStateObject stateObj, Boolean callerHasConnectionLock, Boolean asyncClose)\r\n   at System.Data.SqlClient.TdsParser.TryRun(RunBehavior runBehavior, SqlCommand cmdHandler, SqlDataReader dataStream, BulkCopySimpleResultSet bulkCopyHandler, TdsParserStateObject stateObj, Boolean& dataReady)\r\n   at System.Data.SqlClient.SqlDataReader.TryConsumeMetaData()\r\n   at System.Data.SqlClient.SqlDataReader.get_MetaData()\r\n   at System.Data.SqlClient.SqlCommand.FinishExecuteReader(SqlDataReader ds, RunBehavior runBehavior, String resetOptionsString)\r\n   at System.Data.SqlClient.SqlCommand.RunExecuteReaderTds(CommandBehavior cmdBehavior, RunBehavior runBehavior, Boolean returnStream, Boolean async, Int32 timeout, Task& task, Boolean asyncWrite, SqlDataReader ds)\r\n   at System.Data.SqlClient.SqlCommand.ExecuteReader(CommandBehavior behavior)\r\n   at System.Data.Common.DbCommand.System.Data.IDbCommand.ExecuteReader(CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.FillInternal(DataSet dataset, DataTable[] datatables, Int32 startRecord, Int32 maxRecords, String srcTable, IDbCommand command, CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.Fill(DataSet dataSet, Int32 startRecord, Int32 maxRecords, String srcTable, IDbCommand command, CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.Fill(DataSet dataSet)\r\n   at JobPortal.Data.Helper.SqlHelper.ExecuteDataset(SqlConnection connection, CommandType commandType, String commandText, SqlParameter[] commandParameters) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Helper\\SQLHelper.cs:line 616\r\n   at JobPortal.Data.Repositories.Jobseeker.SearchJobRepository.GetSearchJobList(JobSearchModel searches, Int32 UserId, Int32 quarterStartMonth) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Jobseeker\\SearchJobRepository.cs:line 37\r\n   at JobPortal.Business.Handlers.Jobseeker.SearchJobHandler.SearchJobList(SearchJobViewModel searches, Int32 UserId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Jobseeker\\SearchJobHandler.cs:line 46\r\n   at JobPortal.Web.Areas.Jobseeker.Controllers.JobController.SearchJobList(SearchJobViewModel searches) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Jobseeker\\Controllers\\JobController.cs:line 90","RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2146232060,"Source":"Core .Net SqlClient Data Provider","WatsonBuckets":null,"Errors":null,"ClientConnectionId":"53007648-a63f-4f95-9a0f-28a786763e92"}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'JobController', CAST(N'2020-08-26 13:30:22.090' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (88, N'Error', N'Procedure or function usp_GetSearchList has too many arguments specified.', NULL, N'{"ClassName":"System.Data.SqlClient.SqlException","Message":"Procedure or function usp_GetSearchList has too many arguments specified.","Data":{"HelpLink.ProdName":"Microsoft SQL Server","HelpLink.ProdVer":"12.00.6329","HelpLink.EvtSrc":"MSSQLServer","HelpLink.EvtID":"8144","HelpLink.BaseHelpUrl":"https://go.microsoft.com/fwlink","HelpLink.LinkId":"20476","SqlError 1":"System.Data.SqlClient.SqlError: Procedure or function usp_GetSearchList has too many arguments specified."},"InnerException":null,"HelpURL":null,"StackTraceString":"   at System.Data.SqlClient.SqlConnection.OnError(SqlException exception, Boolean breakConnection, Action`1 wrapCloseInAction)\r\n   at System.Data.SqlClient.TdsParser.ThrowExceptionAndWarning(TdsParserStateObject stateObj, Boolean callerHasConnectionLock, Boolean asyncClose)\r\n   at System.Data.SqlClient.TdsParser.TryRun(RunBehavior runBehavior, SqlCommand cmdHandler, SqlDataReader dataStream, BulkCopySimpleResultSet bulkCopyHandler, TdsParserStateObject stateObj, Boolean& dataReady)\r\n   at System.Data.SqlClient.SqlDataReader.TryConsumeMetaData()\r\n   at System.Data.SqlClient.SqlDataReader.get_MetaData()\r\n   at System.Data.SqlClient.SqlCommand.FinishExecuteReader(SqlDataReader ds, RunBehavior runBehavior, String resetOptionsString)\r\n   at System.Data.SqlClient.SqlCommand.RunExecuteReaderTds(CommandBehavior cmdBehavior, RunBehavior runBehavior, Boolean returnStream, Boolean async, Int32 timeout, Task& task, Boolean asyncWrite, SqlDataReader ds)\r\n   at System.Data.SqlClient.SqlCommand.ExecuteReader(CommandBehavior behavior)\r\n   at System.Data.Common.DbCommand.System.Data.IDbCommand.ExecuteReader(CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.FillInternal(DataSet dataset, DataTable[] datatables, Int32 startRecord, Int32 maxRecords, String srcTable, IDbCommand command, CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.Fill(DataSet dataSet, Int32 startRecord, Int32 maxRecords, String srcTable, IDbCommand command, CommandBehavior behavior)\r\n   at System.Data.Common.DbDataAdapter.Fill(DataSet dataSet)\r\n   at JobPortal.Data.Helper.SqlHelper.ExecuteDataset(SqlConnection connection, CommandType commandType, String commandText, SqlParameter[] commandParameters) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Helper\\SQLHelper.cs:line 616\r\n   at JobPortal.Data.Repositories.Jobseeker.SearchJobRepository.GetSearchJobList(JobSearchModel searches, Int32 UserId, Int32 quarterStartMonth) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Jobseeker\\SearchJobRepository.cs:line 37\r\n   at JobPortal.Business.Handlers.Jobseeker.SearchJobHandler.SearchJobList(SearchJobViewModel searches, Int32 UserId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Jobseeker\\SearchJobHandler.cs:line 46\r\n   at JobPortal.Web.Areas.Jobseeker.Controllers.JobController.SearchJobList(SearchJobViewModel searches) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Jobseeker\\Controllers\\JobController.cs:line 90","RemoteStackTraceString":null,"RemoteStackIndex":0,"ExceptionMethod":null,"HResult":-2146232060,"Source":"Core .Net SqlClient Data Provider","WatsonBuckets":null,"Errors":null,"ClientConnectionId":"53007648-a63f-4f95-9a0f-28a786763e92"}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'JobController', CAST(N'2020-08-26 13:32:15.370' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (89, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 08:24:35.930' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (90, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 57","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 08:26:35.947' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (91, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 57","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 08:27:27.220' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (92, N'Error', N'Sorry!!! Your account is not activated. Contact your tech deck.', NULL, N'{"Message":"Sorry!!! Your account is not activated. Contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 57","HelpLink":null,"Source":"JobPortal.Web","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 08:44:28.720' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (93, N'Error', N'data not found!', NULL, N'{"Message":"data not found!","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Jobseeker.UserProfileHandler.JobSeekerSkills(Int32 userId) in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Business\\Handlers\\Jobseeker\\UserProfileHandler.cs:line 699\r\n   at JobPortal.Web.Areas.Jobseeker.Controllers.JobSeekerManagementController.GetJobseekerDashboard() in F:\\Sunil Steeprise work\\JobPortalNewSR\\SourceCode\\JobPortal.Web\\Areas\\Jobseeker\\Controllers\\JobSeekerManagementController.cs:line 446","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'JobSeekerManagementController', CAST(N'2020-08-28 08:55:04.510' AS DateTime), 10)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (94, N'Error', N'Data not found', NULL, N'{"Message":"Data not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Admin.SuccessStoryVideoRepository.GetSuccessStoryVid() in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Admin\\SuccessStoryVideoRepository.cs:line 46\r\n   at JobPortal.Business.Handlers.Admin.SuccessStoryVideoHandler.GetSuccessStoryVid() in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Admin\\SuccessStoryVideoHandler.cs:line 29\r\n   at JobPortal.Web.Areas.Admin.Controllers.SuccessStoryVideoController.GetSuccessStoryVideo(String country) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Admin\\Controllers\\SuccessStoryVideoController.cs:line 115","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'SuccessStoryVideoController', CAST(N'2020-08-28 14:55:20.780' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (95, N'Error', N'Data not found', NULL, N'{"Message":"Data not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Admin.SuccessStoryVideoRepository.GetSuccessStoryVid() in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Admin\\SuccessStoryVideoRepository.cs:line 46\r\n   at JobPortal.Business.Handlers.Admin.SuccessStoryVideoHandler.GetSuccessStoryVid() in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Admin\\SuccessStoryVideoHandler.cs:line 29\r\n   at JobPortal.Web.Areas.Admin.Controllers.SuccessStoryVideoController.GetSuccessStoryVideo(String country) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Admin\\Controllers\\SuccessStoryVideoController.cs:line 115","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'SuccessStoryVideoController', CAST(N'2020-08-28 14:55:23.390' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (96, N'Error', N'Data not found', NULL, N'{"Message":"Data not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Admin.SuccessStoryVideoRepository.GetSuccessStoryVid() in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Admin\\SuccessStoryVideoRepository.cs:line 46\r\n   at JobPortal.Business.Handlers.Admin.SuccessStoryVideoHandler.GetSuccessStoryVid() in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Admin\\SuccessStoryVideoHandler.cs:line 29\r\n   at JobPortal.Web.Areas.Admin.Controllers.SuccessStoryVideoController.GetSuccessStoryVideo(String country) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Admin\\Controllers\\SuccessStoryVideoController.cs:line 115","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'SuccessStoryVideoController', CAST(N'2020-08-28 14:55:26.270' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (97, N'Error', N'Messages not found', NULL, N'{"Message":"Messages not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetMessages(DateTime msgsOnDate, Int32 empId) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 411\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetMessages(String date) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 239","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-28 15:04:03.697' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (98, N'Error', N'Messages not found', NULL, N'{"Message":"Messages not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetMessages(DateTime msgsOnDate, Int32 empId) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 411\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetMessages(String date) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 239","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-28 15:04:05.573' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (99, N'Error', N'Job seekers for dashboard found, please contact your tech deck.', NULL, N'{"Message":"Job seekers for dashboard found, please contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Employer.DashboardRepository.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Employer\\DashboardRepository.cs:line 272\r\n   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 260\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekersBasedOnEmployerHiringCriteria(String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 90","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-28 15:04:19.453' AS DateTime), 4)
GO
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (100, N'Error', N'Job seekers for dashboard found, please contact your tech deck.', NULL, N'{"Message":"Job seekers for dashboard found, please contact your tech deck.","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Employer.DashboardRepository.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Employer\\DashboardRepository.cs:line 272\r\n   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobSeekersBasedOnEmployerHiringCriteria(Int32 empId, String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 260\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobSeekersBasedOnEmployerHiringCriteria(String year, String city, String role) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 90","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-08-28 15:04:24.707' AS DateTime), 4)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (101, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in E:\\Steeprise\\JobPortalSR\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in E:\\Steeprise\\JobPortalSR\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in E:\\Steeprise\\JobPortalSR\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 15:14:33.340' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (102, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in E:\\Steeprise\\JobPortalSR\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in E:\\Steeprise\\JobPortalSR\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in E:\\Steeprise\\JobPortalSR\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 15:14:40.390' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (103, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 15:54:35.173' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (104, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 15:58:55.290' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (105, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Auth.AuthRepository.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Auth\\AuthRepository.cs:line 51\r\n   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 44\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Sunil Steeprise work\\JobPortalSRGit\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 52","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-08-28 15:59:10.080' AS DateTime), 0)
SET IDENTITY_INSERT [dbo].[Logging] OFF
SET IDENTITY_INSERT [dbo].[MailType] ON 

INSERT [dbo].[MailType] ([Id], [Type], [IsActive]) VALUES (1, N'NotAllowed', 1)
INSERT [dbo].[MailType] ([Id], [Type], [IsActive]) VALUES (2, N'JobApplicationResponse', 1)
INSERT [dbo].[MailType] ([Id], [Type], [IsActive]) VALUES (3, N'OTP', 1)
INSERT [dbo].[MailType] ([Id], [Type], [IsActive]) VALUES (4, N'UserApproval', 1)
INSERT [dbo].[MailType] ([Id], [Type], [IsActive]) VALUES (5, N'ForgotPassword', 1)
INSERT [dbo].[MailType] ([Id], [Type], [IsActive]) VALUES (6, N'JobApplication', 1)
INSERT [dbo].[MailType] ([Id], [Type], [IsActive]) VALUES (7, N'UserRegistrationActivationLink', 1)
SET IDENTITY_INSERT [dbo].[MailType] OFF
SET IDENTITY_INSERT [dbo].[MaritalStatus] ON 

INSERT [dbo].[MaritalStatus] ([StatusId], [StatusCode], [Status], [IsActive]) VALUES (1, N'single', N'Single', 1)
INSERT [dbo].[MaritalStatus] ([StatusId], [StatusCode], [Status], [IsActive]) VALUES (2, N'married', N'Married', 1)
SET IDENTITY_INSERT [dbo].[MaritalStatus] OFF
SET IDENTITY_INSERT [dbo].[PopularJobSearches] ON 

INSERT [dbo].[PopularJobSearches] ([Id], [FilterName], [FilterValue], [Count], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'Experience', N'-1', 35, N'0', CAST(N'2020-08-07 17:25:21.573' AS DateTime), N'8', CAST(N'2020-08-28 16:10:18.557' AS DateTime))
INSERT [dbo].[PopularJobSearches] ([Id], [FilterName], [FilterValue], [Count], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, N'JobRole', N'1', 7, N'0', CAST(N'2020-08-21 15:50:22.817' AS DateTime), N'2', CAST(N'2020-08-26 13:00:08.407' AS DateTime))
INSERT [dbo].[PopularJobSearches] ([Id], [FilterName], [FilterValue], [Count], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (3, N'JobRole', N'113', 1, N'0', CAST(N'2020-08-24 08:43:25.880' AS DateTime), NULL, NULL)
INSERT [dbo].[PopularJobSearches] ([Id], [FilterName], [FilterValue], [Count], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (4, N'JobRole', N'2', 1, N'8', CAST(N'2020-08-26 11:29:04.750' AS DateTime), NULL, NULL)
INSERT [dbo].[PopularJobSearches] ([Id], [FilterName], [FilterValue], [Count], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (5, N'City', N'DIBL', 1, N'0', CAST(N'2020-08-28 15:39:13.900' AS DateTime), NULL, NULL)
SET IDENTITY_INSERT [dbo].[PopularJobSearches] OFF
SET IDENTITY_INSERT [dbo].[PreferredLocation] ON 

INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (1, 2, N'AHMD', NULL, 1, CAST(N'2020-08-11' AS Date), N'2', NULL, NULL)
INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (2, 2, N'AKOJ', NULL, 2, CAST(N'2020-08-11' AS Date), N'2', NULL, NULL)
INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (3, 2, N'AKOJ', NULL, 3, CAST(N'2020-08-11' AS Date), N'2', NULL, NULL)
INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (4, 11, N'AHMD', NULL, 1, CAST(N'2020-08-28' AS Date), N'11', NULL, NULL)
INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (5, 11, N'AIZG', NULL, 2, CAST(N'2020-08-28' AS Date), N'11', NULL, NULL)
INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (6, 11, N'ALIL', NULL, 3, CAST(N'2020-08-28' AS Date), N'11', NULL, NULL)
SET IDENTITY_INSERT [dbo].[PreferredLocation] OFF
SET IDENTITY_INSERT [dbo].[ProfileViewSummary] ON 

INSERT [dbo].[ProfileViewSummary] ([SummaryId], [ViewerId], [ViewedId], [ViewedOn], [ModifiedViewedOn]) VALUES (1, 4, 2, CAST(N'2020-08-24 13:38:57.487' AS DateTime), CAST(N'2020-08-28 16:07:26.810' AS DateTime))
INSERT [dbo].[ProfileViewSummary] ([SummaryId], [ViewerId], [ViewedId], [ViewedOn], [ModifiedViewedOn]) VALUES (2, 4, 8, CAST(N'2020-08-28 16:07:58.440' AS DateTime), NULL)
INSERT [dbo].[ProfileViewSummary] ([SummaryId], [ViewerId], [ViewedId], [ViewedOn], [ModifiedViewedOn]) VALUES (3, 4, 11, CAST(N'2020-08-28 16:08:11.380' AS DateTime), NULL)
SET IDENTITY_INSERT [dbo].[ProfileViewSummary] OFF
SET IDENTITY_INSERT [dbo].[Roles] ON 

INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (1, N'Admin', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 1)
INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (2, N'Student', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 0)
INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (3, N'Corporate', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 1)
INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (4, N'Staffing Partner', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 1)
INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (5, N'Training Partner', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 0)
INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (6, N'Demand Aggregation', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 0)
SET IDENTITY_INSERT [dbo].[Roles] OFF
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'AN', N'Andaman and  Nicobar Islands', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'AP', N'Andhra Pradesh', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'AR', N'Arunachal Pradesh', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'AS', N'Assam', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'BH', N'Bihar', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'CHG', N'Chhattisgarh', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'DD', N'Daman and Diu', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'DL', N'Delhi', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'DN', N'Dadra and Nagar Haveli', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'GA', N'Goa', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'GJ', N'Gujarat', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'HP', N'Himachal Pradesh', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'HR', N'Haryana', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'JH', N'Jharkhand', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'JK', N'Jammu and Kashmir', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'KL', N'Kerala', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'KT', N'Karnataka', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'LD', N'Lakshadweep', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'ME', N'Meghalaya', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'MH', N'Maharashtra', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'MI', N'Mizoram', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'MN', N'Manipur', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'MP', N'Madhya Pradesh', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'NL', N'Nagaland', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'OR', N'Orissa', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'PB', N'Punjab', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'PY', N'Pondicherry', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'RJ', N'Rajasthan', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'SK', N'Sikkim', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'TE', N'TestState', 0, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'TN', N'Tamil Nadu', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'TR', N'Tripura', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'TS', N'Telangana', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'TSS', N'Test State Of India', 0, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'UK', N'Uttarakhand', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'UP', N'Uttar Pradesh', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'UT', N'Uttaranchal', 1, N'IN')
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'WB', N'West Bengal', 1, N'IN')
SET IDENTITY_INSERT [dbo].[SuccessStoryVideo] ON 

INSERT [dbo].[SuccessStoryVideo] ([Id], [Title], [FileName], [Type], [DisplayOrder], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [Status]) VALUES (1, N'Milestone in life', N'https://www.youtube.com/embed/Bey4XXJAqS8', N'Student', 2, N'Admin', N'Aug 28 2020  2:55PM', N'Admin', N'Aug 28 2020  2:56PM', 1)
SET IDENTITY_INSERT [dbo].[SuccessStoryVideo] OFF
SET IDENTITY_INSERT [dbo].[UserActivity] ON 

INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (1, 3, CAST(N'2020-08-05 13:26:48.813' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (2, 2, CAST(N'2020-08-05 13:29:16.400' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (3, 2, CAST(N'2020-08-05 13:37:54.727' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (4, 3, CAST(N'2020-08-05 14:03:24.623' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (5, 2, CAST(N'2020-08-05 15:20:01.310' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (6, 3, CAST(N'2020-08-05 15:45:45.603' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (7, 3, CAST(N'2020-08-06 15:52:13.710' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (8, 2, CAST(N'2020-08-06 15:54:41.793' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (9, 3, CAST(N'2020-08-07 15:25:19.660' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (10, 2, CAST(N'2020-08-07 15:26:12.173' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (11, 3, CAST(N'2020-08-07 15:35:51.273' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (12, 4, CAST(N'2020-08-07 15:36:51.590' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (13, 4, CAST(N'2020-08-07 15:48:30.367' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (14, 2, CAST(N'2020-08-07 15:48:30.577' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (15, 4, CAST(N'2020-08-07 15:49:58.010' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (16, 2, CAST(N'2020-08-07 15:56:00.457' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (17, 2, CAST(N'2020-08-07 16:00:36.530' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (18, 2, CAST(N'2020-08-07 17:25:50.567' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (19, 2, CAST(N'2020-08-11 14:35:53.337' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (20, 2, CAST(N'2020-08-11 14:36:23.270' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (21, 3, CAST(N'2020-08-11 14:37:26.907' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (22, 3, CAST(N'2020-08-11 14:38:02.020' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (23, 3, CAST(N'2020-08-11 14:41:15.137' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (24, 3, CAST(N'2020-08-11 14:41:45.597' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (25, 3, CAST(N'2020-08-11 14:42:21.990' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (26, 3, CAST(N'2020-08-11 14:43:49.153' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (27, 2, CAST(N'2020-08-11 14:46:45.480' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (28, 4, CAST(N'2020-08-11 14:52:21.210' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (29, 2, CAST(N'2020-08-11 14:52:43.140' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (30, 4, CAST(N'2020-08-11 14:53:28.097' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (31, 4, CAST(N'2020-08-11 15:30:43.280' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (32, 4, CAST(N'2020-08-11 15:52:13.430' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (33, 4, CAST(N'2020-08-14 14:21:53.370' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (34, 4, CAST(N'2020-08-14 14:26:42.440' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (35, 2, CAST(N'2020-08-14 14:26:53.913' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (36, 2, CAST(N'2020-08-14 14:27:03.213' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (37, 2, CAST(N'2020-08-14 14:28:20.703' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (38, 2, CAST(N'2020-08-14 14:30:12.880' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (39, 4, CAST(N'2020-08-14 14:30:33.093' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (40, 2, CAST(N'2020-08-14 14:33:12.920' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (41, 2, CAST(N'2020-08-14 14:34:22.653' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (42, 2, CAST(N'2020-08-14 14:50:42.050' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (43, 4, CAST(N'2020-08-14 15:02:51.083' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (44, 4, CAST(N'2020-08-14 15:05:50.603' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (45, 4, CAST(N'2020-08-14 15:17:50.530' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (46, 2, CAST(N'2020-08-14 15:23:57.910' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (47, 2, CAST(N'2020-08-19 14:46:47.277' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (48, 4, CAST(N'2020-08-19 14:46:57.237' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (49, 3, CAST(N'2020-08-19 14:49:09.910' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (50, 2, CAST(N'2020-08-19 14:55:18.310' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (51, 3, CAST(N'2020-08-20 05:45:20.853' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (52, 5, CAST(N'2020-08-20 05:46:29.440' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (53, 3, CAST(N'2020-08-20 06:05:09.947' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (54, 6, CAST(N'2020-08-20 06:06:17.673' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (55, 3, CAST(N'2020-08-20 06:20:03.853' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (56, 7, CAST(N'2020-08-20 06:21:36.210' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (57, 3, CAST(N'2020-08-20 06:45:27.173' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (58, 2, CAST(N'2020-08-20 06:45:59.507' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (59, 6, CAST(N'2020-08-20 07:00:58.187' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (60, 7, CAST(N'2020-08-20 07:06:52.250' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (61, 5, CAST(N'2020-08-20 07:15:46.190' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (62, 2, CAST(N'2020-08-21 14:51:35.343' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (63, 2, CAST(N'2020-08-21 14:53:03.140' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (64, 4, CAST(N'2020-08-21 14:53:30.363' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (65, 4, CAST(N'2020-08-21 14:59:57.407' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (66, 4, CAST(N'2020-08-21 15:01:52.023' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (67, 4, CAST(N'2020-08-21 15:22:08.497' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (68, 2, CAST(N'2020-08-21 15:22:15.547' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (69, 4, CAST(N'2020-08-21 15:25:58.747' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (70, 4, CAST(N'2020-08-21 15:28:06.560' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (71, 4, CAST(N'2020-08-21 15:49:06.387' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (72, 4, CAST(N'2020-08-24 06:08:30.760' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (73, 4, CAST(N'2020-08-24 07:16:28.360' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (74, 4, CAST(N'2020-08-24 07:20:46.360' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (75, 9, CAST(N'2020-08-24 07:26:19.853' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (76, 4, CAST(N'2020-08-24 08:08:08.297' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (77, 4, CAST(N'2020-08-24 11:17:48.740' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (78, 4, CAST(N'2020-08-24 13:38:27.067' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (79, 8, CAST(N'2020-08-26 11:23:36.563' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (80, 8, CAST(N'2020-08-26 11:26:00.820' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (81, 4, CAST(N'2020-08-26 11:26:31.600' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (82, 8, CAST(N'2020-08-26 11:28:43.390' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (83, 4, CAST(N'2020-08-26 13:33:40.090' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (84, 3, CAST(N'2020-08-28 08:46:47.800' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (85, 3, CAST(N'2020-08-28 08:51:06.323' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (86, 10, CAST(N'2020-08-28 08:54:11.810' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (87, 3, CAST(N'2020-08-28 14:53:31.820' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (88, 11, CAST(N'2020-08-28 15:00:28.237' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (89, 4, CAST(N'2020-08-28 15:03:59.767' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (90, 8, CAST(N'2020-08-28 15:04:36.923' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (91, 4, CAST(N'2020-08-28 15:05:53.167' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (92, 3, CAST(N'2020-08-28 15:12:44.470' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (93, 11, CAST(N'2020-08-28 15:14:26.170' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (94, 11, CAST(N'2020-08-28 15:15:24.700' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (95, 4, CAST(N'2020-08-28 15:22:48.130' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (96, 3, CAST(N'2020-08-28 15:34:06.960' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (97, 4, CAST(N'2020-08-28 15:50:28.663' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (98, 4, CAST(N'2020-08-28 15:51:12.257' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (99, 4, CAST(N'2020-08-28 15:53:18.327' AS DateTime), NULL)
GO
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (100, 3, CAST(N'2020-08-28 15:54:45.283' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (101, 8, CAST(N'2020-08-28 16:08:57.390' AS DateTime), NULL)
SET IDENTITY_INSERT [dbo].[UserActivity] OFF
SET IDENTITY_INSERT [dbo].[UserProfessionalDetails] ON 

INSERT [dbo].[UserProfessionalDetails] ([ID], [UserId], [ExperienceDetails], [EducationalDetails], [Skills], [CurrentSalary], [ExpectedSalary], [DateOfBirth], [Resume], [AboutMe], [ProfileSummary], [Status], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy], [EmploymentStatusId], [JobIndustryAreaId], [TotalExperience], [LinkedinProfile], [IsJobAlert], [JobTitleId]) VALUES (1, 2, N'[{"Id":1,"Designation":"Web Designer","Organization":"HCL","AnnualSalary":null,"WorkingFrom":"Jan, 2019","WorkingTill":"Present","WorkLocation":null,"NoticePeriod":"30","ServingNoticePeriod":false,"Industry":null,"JobProfile":"fdfd","IsCurrentOrganization":true,"Skills":null}]', N'[{"Id":1,"Qualification":"1","Course":"1","OtherCourseName":null,"Specialization":"CS","University":"VITS","CourseType":"1","PassingYear":"2018","Percentage":"89"}]', N'{"SkillSets":"asp.net,ruby,java script"}', N'', N'', N'1998-05-20', N'\Resume\2_test.docx', N'', N'test', N'1', CAST(N'2020-08-07 15:30:15.453' AS DateTime), N'2', CAST(N'2020-08-21 14:52:33.887' AS DateTime), N'2', 5, NULL, N'0', N'', 0, 1)
INSERT [dbo].[UserProfessionalDetails] ([ID], [UserId], [ExperienceDetails], [EducationalDetails], [Skills], [CurrentSalary], [ExpectedSalary], [DateOfBirth], [Resume], [AboutMe], [ProfileSummary], [Status], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy], [EmploymentStatusId], [JobIndustryAreaId], [TotalExperience], [LinkedinProfile], [IsJobAlert], [JobTitleId]) VALUES (2, 8, NULL, NULL, NULL, N'12,000.00', N'1,000,000.00', N'1993-08-18', NULL, N'I am a full stack developer having experience of X years in Y tech stack', NULL, N'1', CAST(N'2020-08-26 11:25:43.090' AS DateTime), N'8', CAST(N'2020-08-28 15:05:40.043' AS DateTime), N'8', 5, 10, N'4', N'https://www.linkedin.com/in/', 0, 5)
INSERT [dbo].[UserProfessionalDetails] ([ID], [UserId], [ExperienceDetails], [EducationalDetails], [Skills], [CurrentSalary], [ExpectedSalary], [DateOfBirth], [Resume], [AboutMe], [ProfileSummary], [Status], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy], [EmploymentStatusId], [JobIndustryAreaId], [TotalExperience], [LinkedinProfile], [IsJobAlert], [JobTitleId]) VALUES (3, 11, N'[{"Id":1,"Designation":"Web Designer","Organization":"HCL","AnnualSalary":null,"WorkingFrom":"Sep, 2018","WorkingTill":"2012","WorkLocation":null,"NoticePeriod":"0","ServingNoticePeriod":false,"Industry":null,"JobProfile":"i am working as software developer and cricketer","IsCurrentOrganization":false,"Skills":null}]', N'[{"Id":1,"Qualification":"1","Course":"1","OtherCourseName":null,"Specialization":"CS","University":"VITS","CourseType":"1","PassingYear":"2015","Percentage":"80"}]', N'{"SkillSets":"php,mvc,cricket"}', N'', N'730.00', N'1988-05-12', NULL, N'i am very hard working in development', N'working as a software developer and cricketer since bachpan', N'1', CAST(N'2020-08-28 15:03:08.760' AS DateTime), N'11', CAST(N'2020-08-28 15:17:59.260' AS DateTime), N'11', 1, 13, N'0', N'https://www.linkedin.com/', 1, 14)
SET IDENTITY_INSERT [dbo].[UserProfessionalDetails] OFF
SET IDENTITY_INSERT [dbo].[UserRoles] ON 

INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (1, 2, 1, CAST(N'2020-08-05 13:08:58.087' AS DateTime), N'1')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (2, 2, 2, CAST(N'2020-08-05 13:17:50.450' AS DateTime), N'2')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (3, 1, 3, CAST(N'2020-08-05 13:17:50.450' AS DateTime), N'3')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (4, 3, 4, CAST(N'2020-08-07 15:35:21.500' AS DateTime), N'4')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (5, 3, 5, CAST(N'2020-08-20 05:43:34.407' AS DateTime), N'5')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (6, 3, 6, CAST(N'2020-08-20 06:04:07.600' AS DateTime), N'6')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (7, 3, 7, CAST(N'2020-08-20 06:19:45.433' AS DateTime), N'7')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (8, 2, 8, CAST(N'2020-08-20 14:29:10.570' AS DateTime), N'8')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (9, 2, 9, CAST(N'2020-08-24 03:53:49.967' AS DateTime), N'9')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (10, 2, 10, CAST(N'2020-08-28 08:25:29.450' AS DateTime), N'10')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (11, 2, 11, CAST(N'2020-08-28 14:59:54.473' AS DateTime), N'11')
SET IDENTITY_INSERT [dbo].[UserRoles] OFF
SET IDENTITY_INSERT [dbo].[Users] ON 

INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (1, N'Mohit', N'Singh', N'1234567890', N'ls2qbimi88@cloud-mail.top', N'Test@123', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 0, CAST(N'2020-08-05 13:08:58.087' AS DateTime), NULL, NULL, NULL, 1, NULL, CAST(N'2020-09-04' AS Date), NULL, NULL, NULL, 1, 0, 0, N'17953132')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (2, N'Aayodha', N'Singh', N'1234567890', N'aayodhatest@icanav.net', N'Test@123', N'', NULL, NULL, N'KHEI', N'GJ', N'IN', N'', N'\ProfilePic\2_gautam.png', 1, 0, CAST(N'2020-08-05 13:17:50.450' AS DateTime), 2, CAST(N'2020-08-21 14:52:33.887' AS DateTime), N'female', 1, NULL, CAST(N'2020-09-04' AS Date), NULL, NULL, NULL, 1, 0, 0, N'16065375')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (3, N'Admin', NULL, NULL, N'admin@yopmail.com', N'Admin@123', NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'\ProfilePic\120_download (1).jpg', 1, 0, CAST(N'2020-08-05 13:23:09.710' AS DateTime), NULL, NULL, NULL, 1, N'Admin', CAST(N'2020-09-04' AS Date), NULL, NULL, NULL, 1, 0, 0, N'12883726')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (4, N'Test7July', NULL, NULL, N'testmailcompany@test.com', N'Admin@123', N'india', NULL, NULL, NULL, NULL, NULL, NULL, N'\ProfilePic\4_mystry.jpg', 1, 0, CAST(N'2020-08-07 15:35:21.483' AS DateTime), 0, CAST(N'2020-08-14 14:29:31.760' AS DateTime), NULL, 1, N'Test7July', CAST(N'2020-09-13' AS Date), NULL, N' ', NULL, 1, 0, 0, N'10361947')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (5, N'Tech First', NULL, NULL, N'techfirst@senduvu.com', N'Test@123', N'', NULL, NULL, NULL, NULL, NULL, NULL, N'\ProfilePic\5_12.jpg', 1, 0, CAST(N'2020-08-20 05:43:34.390' AS DateTime), 5, CAST(N'2020-08-20 07:18:05.533' AS DateTime), NULL, 1, N'Tech First', CAST(N'2020-09-19' AS Date), NULL, N' ', NULL, 1, 0, 0, N'13428859')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (6, N'Property First', NULL, NULL, N'propertyfirst@inbox-me.top', N'Test@123', N'delhi india', NULL, NULL, NULL, NULL, NULL, NULL, N'\ProfilePic\6_SamsungLogo.jpg', 1, 0, CAST(N'2020-08-20 06:04:07.600' AS DateTime), 6, CAST(N'2020-08-20 07:03:15.103' AS DateTime), NULL, 1, N'Property First', CAST(N'2020-09-19' AS Date), NULL, N' ', NULL, 1, 0, 0, N'14772478')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (7, N'Wheel balance ', NULL, NULL, N'wheelblance@senduvu.com', N'Test@123', N'', NULL, NULL, NULL, NULL, NULL, NULL, N'\ProfilePic\7_images (1).png', 1, 0, CAST(N'2020-08-20 06:19:45.420' AS DateTime), 7, CAST(N'2020-08-20 07:08:25.700' AS DateTime), NULL, 1, N'Wheel balance ', CAST(N'2020-09-19' AS Date), NULL, N' ', NULL, 1, 0, 0, N'13880194')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (8, N'Mohit', N'Rana', N'8802680333', N'mohitrana@academail.net', N'Test@123', N'', NULL, NULL, N'RAMH', N'JK', N'IN', N'single', NULL, 1, 0, CAST(N'2020-08-20 14:29:10.570' AS DateTime), 8, CAST(N'2020-08-28 15:05:40.043' AS DateTime), N'female', 1, NULL, CAST(N'2020-09-19' AS Date), NULL, NULL, NULL, 1, 0, 0, N'17062727')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (9, N'rajesh', N'p', N'9811936378', N'rajeshkprajapati@gmail.com', N'123456', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 0, CAST(N'2020-08-24 03:53:49.950' AS DateTime), NULL, NULL, NULL, 1, NULL, CAST(N'2020-09-23' AS Date), NULL, NULL, NULL, 1, 0, 0, N'14830253')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (10, N'Amardeep', N'Kumar', N'9310664532', N'amardeepkmr86@gmail.com', N'amardeep', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 0, CAST(N'2020-08-28 08:25:29.450' AS DateTime), NULL, NULL, NULL, 1, NULL, CAST(N'2020-09-27' AS Date), NULL, NULL, NULL, 1, 0, 0, N'10905082')
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID]) VALUES (11, N'Suresh', N'Raina', N'9087654321', N'rikiye9539@delotti.com', N'Test@123', N'raj nagar extension ghaziabad', NULL, NULL, N'GHAC', N'UP', N'IN', N'single', N'\ProfilePic\11_raina.jpg', 1, 0, CAST(N'2020-08-28 14:59:54.473' AS DateTime), 11, CAST(N'2020-08-28 15:17:59.260' AS DateTime), N'male', 1, NULL, CAST(N'2020-09-27' AS Date), NULL, NULL, NULL, 1, 0, 0, N'16790366')
SET IDENTITY_INSERT [dbo].[Users] OFF
ALTER TABLE [dbo].[Designations] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Modules] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Organizations] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[Organizations] ADD  DEFAULT (getdate()) FOR [CreatedOn]
GO
ALTER TABLE [dbo].[OTPData] ADD  CONSTRAINT [DF_OTPData_CreatedDate]  DEFAULT (getdate()) FOR [CreatedDate]
GO
ALTER TABLE [dbo].[OTPData] ADD  DEFAULT ((0)) FOR [IsUsed]
GO
ALTER TABLE [dbo].[RESULTS] ADD  DEFAULT ((0)) FOR [IsDeleted]
GO
ALTER TABLE [dbo].[SSCJobRole] ADD  DEFAULT ((0)) FOR [IsActive]
GO
ALTER TABLE [dbo].[SuccessSotry] ADD  CONSTRAINT [DF_SuccessSotry_IsApproved]  DEFAULT ((0)) FOR [IsApproved]
GO
ALTER TABLE [dbo].[Cities]  WITH CHECK ADD FOREIGN KEY([StateCode])
REFERENCES [dbo].[States] ([StateCode])
GO
ALTER TABLE [dbo].[Courses]  WITH CHECK ADD FOREIGN KEY([Category])
REFERENCES [dbo].[CourseCategories] ([CategoryId])
GO
ALTER TABLE [dbo].[EmailQueue]  WITH CHECK ADD FOREIGN KEY([FromId])
REFERENCES [dbo].[Users] ([UserId])
GO
ALTER TABLE [dbo].[EmailQueue]  WITH CHECK ADD FOREIGN KEY([MailType])
REFERENCES [dbo].[MailType] ([Id])
GO
ALTER TABLE [dbo].[EmailQueue]  WITH CHECK ADD FOREIGN KEY([ToId])
REFERENCES [dbo].[Users] ([UserId])
GO
ALTER TABLE [dbo].[JobPostDetail]  WITH CHECK ADD  CONSTRAINT [FK__JobPostDe__CityC__5BE2A6F2] FOREIGN KEY([CityCode])
REFERENCES [dbo].[Cities] ([CityCode])
GO
ALTER TABLE [dbo].[JobPostDetail] CHECK CONSTRAINT [FK__JobPostDe__CityC__5BE2A6F2]
GO
ALTER TABLE [dbo].[JobPostDetail]  WITH CHECK ADD  CONSTRAINT [FK__JobPostDe__Count__59FA5E80] FOREIGN KEY([CountryCode])
REFERENCES [dbo].[Countries] ([CountryCode])
GO
ALTER TABLE [dbo].[JobPostDetail] CHECK CONSTRAINT [FK__JobPostDe__Count__59FA5E80]
GO
ALTER TABLE [dbo].[JobPostDetail]  WITH CHECK ADD  CONSTRAINT [FK__JobPostDe__Emplo__5CD6CB2B] FOREIGN KEY([EmploymentStatusId])
REFERENCES [dbo].[EmploymentStatus] ([EmploymentStatusId])
GO
ALTER TABLE [dbo].[JobPostDetail] CHECK CONSTRAINT [FK__JobPostDe__Emplo__5CD6CB2B]
GO
ALTER TABLE [dbo].[JobPostDetail]  WITH CHECK ADD  CONSTRAINT [FK__JobPostDe__Emplo__5EBF139D] FOREIGN KEY([EmploymentTypeId])
REFERENCES [dbo].[EmploymentType] ([EmploymentTypeId])
GO
ALTER TABLE [dbo].[JobPostDetail] CHECK CONSTRAINT [FK__JobPostDe__Emplo__5EBF139D]
GO
ALTER TABLE [dbo].[JobPostDetail]  WITH CHECK ADD  CONSTRAINT [FK__JobPostDe__JobIn__59063A47] FOREIGN KEY([JobIndustryAreaId])
REFERENCES [dbo].[JobIndustryArea] ([JobIndustryAreaId])
GO
ALTER TABLE [dbo].[JobPostDetail] CHECK CONSTRAINT [FK__JobPostDe__JobIn__59063A47]
GO
ALTER TABLE [dbo].[JobPostDetail]  WITH CHECK ADD FOREIGN KEY([JobType])
REFERENCES [dbo].[JobTypes] ([Id])
GO
ALTER TABLE [dbo].[JobPostDetail]  WITH CHECK ADD  CONSTRAINT [FK__JobPostDe__State__5AEE82B9] FOREIGN KEY([StateCode])
REFERENCES [dbo].[States] ([StateCode])
GO
ALTER TABLE [dbo].[JobPostDetail] CHECK CONSTRAINT [FK__JobPostDe__State__5AEE82B9]
GO
ALTER TABLE [dbo].[JobPostDetail]  WITH CHECK ADD  CONSTRAINT [FK_JobPostDetail_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([UserId])
GO
ALTER TABLE [dbo].[JobPostDetail] CHECK CONSTRAINT [FK_JobPostDetail_Users]
GO
ALTER TABLE [dbo].[JobRoleMapping]  WITH CHECK ADD FOREIGN KEY([JobId])
REFERENCES [dbo].[JobPostDetail] ([JobPostId])
GO
ALTER TABLE [dbo].[JobRoleMapping]  WITH CHECK ADD FOREIGN KEY([JobRoleId])
REFERENCES [dbo].[JobTitle] ([JobTitleId])
GO
ALTER TABLE [dbo].[ProfileViewSummary]  WITH CHECK ADD FOREIGN KEY([ViewerId])
REFERENCES [dbo].[Users] ([UserId])
GO
ALTER TABLE [dbo].[ProfileViewSummary]  WITH CHECK ADD FOREIGN KEY([ViewedId])
REFERENCES [dbo].[Users] ([UserId])
GO
ALTER TABLE [dbo].[States]  WITH CHECK ADD FOREIGN KEY([CountryCode])
REFERENCES [dbo].[Countries] ([CountryCode])
GO
ALTER TABLE [dbo].[UserProfessionalDetails]  WITH CHECK ADD  CONSTRAINT [FK_UserProfessionalDetails_EmploymentStatus] FOREIGN KEY([EmploymentStatusId])
REFERENCES [dbo].[EmploymentStatus] ([EmploymentStatusId])
GO
ALTER TABLE [dbo].[UserProfessionalDetails] CHECK CONSTRAINT [FK_UserProfessionalDetails_EmploymentStatus]
GO
ALTER TABLE [dbo].[UserProfessionalDetails]  WITH CHECK ADD  CONSTRAINT [FK_UserProfessionalDetails_JobIndustryArea] FOREIGN KEY([JobIndustryAreaId])
REFERENCES [dbo].[JobIndustryArea] ([JobIndustryAreaId])
GO
ALTER TABLE [dbo].[UserProfessionalDetails] CHECK CONSTRAINT [FK_UserProfessionalDetails_JobIndustryArea]
GO
ALTER TABLE [dbo].[UserProfessionalDetails]  WITH CHECK ADD  CONSTRAINT [FK_UserProfessionalDetails_Users] FOREIGN KEY([UserId])
REFERENCES [dbo].[Users] ([UserId])
GO
ALTER TABLE [dbo].[UserProfessionalDetails] CHECK CONSTRAINT [FK_UserProfessionalDetails_Users]
GO
/****** Object:  StoredProcedure [dbo].[DeleteBulkJob]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[DeleteBulkJob]
(
@JobPostId VARCHAR(1000) =NULL
)
AS
BEGIN

/*	
UPDATE JobPostDetail SET [Status]= 0
	WHERE
		(
		JobPostId IN (SELECT val FROM dbo.f_split(@JobPostId, ','))
		AND
		[IsFromBulkUpload] =1
		)
*/

		Delete from JobRoleMapping 
		WHERE
		(
		JobId IN (SELECT val FROM dbo.f_split(@JobPostId, ','))
		)
		Delete from JobPostDetail 
		WHERE
		(
		JobPostId IN (SELECT val FROM dbo.f_split(@JobPostId, ','))
		AND
		[IsFromBulkUpload] =1
		)
END



GO
/****** Object:  StoredProcedure [dbo].[usp_AddCity]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-------------------------------------------
/*    
-------------------------------------------------------------------------------------------------    
SR   By   Date			Remarks    
1    SR   30/03/2020    	Created - To Add City    
-------------------------------------------------------------------------------------------------    
*/     
CREATE PROC [dbo].[usp_AddCity]
(
	@city VARCHAR(255),
	@citycode VARCHAR(255),
	@statecode VARCHAR(255)
)
AS
BEGIN
	IF NOT EXISTS(SELECT 1 FROM dbo.Cities WHERE CityCode=@citycode)
	BEGIN
		INSERT INTO dbo.Cities
		(
			CityCode,
			Name,
			StateCode,
			IsActive
		)
		VALUES
		(
			@citycode,
			@city,
			@statecode,
			1
		)
	END
END


GO
/****** Object:  StoredProcedure [dbo].[usp_AddDesignation]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_AddDesignation]
(
	@designation VARCHAR(50),
	@abbr VARCHAR(30)
)
AS
BEGIN
	INSERT INTO Designations
	(
		Designation,
		Abbr,
		IsActive
	)
	VALUES
	(
		@designation,
		@abbr,
		1
	)
END









GO
/****** Object:  StoredProcedure [dbo].[usp_AddPreferredlocation]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			12/02/2020			Created - To Add Preferred location
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_AddPreferredlocation]
(
	@locationid VARCHAR(100),
	@locationorder INT,
	@userid INT
)
AS
BEGIN
	IF EXISTS(SELECT Userid FROM [PreferredLocation] WHERE USERId = @userid AND LocationOrder = @locationorder)
	BEGIN
		IF EXISTS(SELECT CityCode FROM Cities WHERE CityCode = @locationid)
		BEGIN
			UPDATE [dbo].[PreferredLocation]
			SET LocationId=@locationid,
				OtherLocation = NULL,
				LocationOrder=@locationorder,
				UpdatedDate = GETDATE(),
				UpdatedBy = @userid
			WHERE Userid=@userid AND LocationOrder = @locationorder 
		END
		ELSE
		BEGIN
			UPDATE [dbo].[PreferredLocation]
			SET OtherLocation=@locationid,
				LocationId = NULL,
				LocationOrder=@locationorder,
				UpdatedDate = GETDATE(),
				UpdatedBy = @userid
			WHERE Userid=@userid AND LocationOrder = @locationorder 
		END
	END
	ELSE
	BEGIN
		IF EXISTS(SELECT CityCode FROM Cities WHERE CityCode = @locationid)
		BEGIN
			INSERT INTO [dbo].[PreferredLocation]
			(
				UserId,
				LocationId,
				LocationOrder,
				CreatedDate,
				CreatedBy
			)
			VALUES
			(
				@userid,
				@locationid,
				@locationorder,
				GETDATE(),
				@userid
			)
		END
		ELSE
		BEGIN
			INSERT INTO [dbo].[PreferredLocation]
			(
				UserId,
				OtherLocation,
				LocationOrder,
				CreatedDate,
				CreatedBy

			)
			VALUES
			(
				@userid,
				@locationid,
				@locationorder,
				GETDATE(),
				@userid
			)
		END
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_AdminDashboardStats]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_AdminDashboardStats]     
(    
@Date Varchar(MAX) = NULL,    
@EndDate Varchar(MAX) = NULL    
)    
    
AS     
BEGIN    
     
 DECLARE @TotalEmployer INT    
 DECLARE @TotalStudent INT    
 DECLARE @TotalStuffingPartner INT    
 DECLARE @TotalTraingPartner INT    
 DECLARE @TotalJobPost INT    
 DECLARE @TotalResumePost INT    
     
    
  SELECT     
  @TotalEmployer = COUNT(1)    
 FROM dbo.Users AS U     
  LEFT JOIN dbo.UserRoles AS UR     
  ON U.UserId = UR.UserId  
  LEFT JOIN dbo.Roles R  
  ON UR.RoleId = R.ID  
 WHERE CAST(U.CreatedOn AS DATE) >= CAST(@Date AS DATE)    
  AND CAST(U.CreatedOn AS DATE) <= CAST(@EndDate AS DATE)   
  AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0  
  AND R.ID = 3
  --AND U.IsActive=1   --- To exclude deleted user 06/12/2020
     
 SELECT     
  @TotalStudent = COUNT(1)    
  FROM dbo.Users AS U     
  LEFT JOIN dbo.UserRoles AS UR     
  ON U.UserId = UR.UserId   
  LEFT JOIN dbo.Roles R  
  ON UR.RoleId = R.ID     
 WHERE CAST(U.CreatedOn AS DATE) >= CAST(@Date AS DATE)    
  AND CAST(U.CreatedOn AS DATE) <= CAST(@EndDate AS DATE)  
  AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0  
 AND R.ID= 2  
 --AND U.IsActive=1    --- To exclude deleted user 06/12/2020
     
 SELECT     
  @TotalStuffingPartner = COUNT(1)    
 FROM dbo.Users AS U     
  LEFT JOIN dbo.UserRoles AS UR     
  ON U.UserId = UR.UserId   
  LEFT JOIN dbo.Roles R  
  ON UR.RoleId = R.ID      
 WHERE CAST(U.CreatedOn AS DATE) >= CAST(@Date AS DATE)    
  AND CAST(U.CreatedOn AS DATE) <= CAST(@EndDate AS DATE)    
  AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0
  AND R.ID = 4   
  --AND U.IsActive=1    --- To exclude deleted user 06/12/2020
     
 SELECT     
  @TotalTraingPartner = COUNT(1)    
 FROM dbo.Users AS U     
  LEFT JOIN dbo.UserRoles AS UR     
  ON U.UserId = UR.UserId   
  LEFT JOIN dbo.Roles R  
  ON UR.RoleId = R.ID       
 WHERE CAST(U.CreatedOn AS DATE) >= CAST(@Date AS DATE)    
  AND CAST(U.CreatedOn AS DATE) <= CAST(@EndDate AS DATE)  
  AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0  
  AND R.ID = 5  
  --AND U.IsActive=1    --- To exclude deleted user 06/12/2020
     
 SELECT     
  @TotalJobPost = COUNT(1)    
 FROM dbo.JobPostDetail AS JP    
  LEFT JOIN dbo.Users U    
  ON JP.CreatedBy = U.UserId    
  LEFT JOIN dbo.UserRoles UR    
  ON U.UserId = UR.UserId    
  LEFT JOIN dbo.Roles R    
  ON UR.RoleId = R.Id    
 WHERE CAST(JP.CreatedDate AS DATE) >= CAST(@Date AS DATE)    
  AND CAST(JP.Createddate AS DATE) <= CAST(@EndDate AS DATE)    
  AND R.ID IN (3,4)  
  AND U.IsActive=1    --- To exclude deleted user 06/12/2020
    
     
 SELECT     
  @TotalResumePost = COUNT(1)    
 FROM dbo.AppliedJobs AJ  
  LEFT JOIN dbo.Users U  
  ON AJ.UserId = U.UserId  
  LEFT JOIN dbo.JobPostDetail JPD  
  ON AJ.JobPostId = JPD.JobPostId     
 WHERE CAST(AJ.CreatedDate AS DATE) >= CAST(@Date AS DATE)    
  AND CAST(AJ.CreatedDate AS DATE) <= CAST(@EndDate AS DATE)  
  AND U.IsActive=1    --- To exclude deleted user 06/12/2020
    
 SELECT    
  @TotalEmployer AS TotalEmployeer,    
  @TotalStudent AS TotalStudent,     
  @TotalJobPost As TotalJobPost,     
  @TotalResumePost AS TotalResumePost,    
  @TotalTraingPartner AS TraningPartner,    
  @TotalStuffingPartner As StuffingPartner      
END 

GO
/****** Object:  StoredProcedure [dbo].[usp_ApprovesuccessStoryReview]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			11/02/2020			Created - Create Proc to approve review by Admin
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_ApprovesuccessStoryReview] 
(
	@Id INT, 
	@ApprovedBy NVARCHAR(50)
 ) 
AS 
  BEGIN 
      UPDATE [dbo].[successsotry] 
      SET    [IsApproved] = 1 
      WHERE  [id] = @Id 
  END 



GO
/****** Object:  StoredProcedure [dbo].[usp_ApproveUser]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_ApproveUser]
	@userid int
AS 
BEGIN
	UPDATE USERS SET IsApproved=1
	WHERE userid=@userid
END







GO
/****** Object:  StoredProcedure [dbo].[usp_CheckDesignationExist]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_CheckDesignationExist] 
(
	@designation VARCHAR(50),
	@abbr VARCHAR(30)
)
AS
BEGIN
	SELECT Designation,Abbr,IsActive FROM Designations WHERE (Designation = @designation or Abbr = @abbr) and IsActive=1
END



GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfCandidateEducationalDetailsExist]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_CheckIfCandidateEducationalDetailsExist] 
(
	@userId INT
)
AS
BEGIN
	SELECT
		EducationalDetails
		FROM [dbo].[UserProfessionalDetails]
	WHERE UserId = @userId AND EducationalDetails <> ''
END





GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfCandidateIdExists]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_CheckIfCandidateIdExists]
(
	@candidateid VARCHAR(50)
	
)
AS
BEGIN
	SELECT
		UserId
	FROM dbo.Users
	WHERE Candidateid = @candidateid
	
END







GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfCandidateResumeExist]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_CheckIfCandidateResumeExist] 
(
	@userId INT
)
AS
BEGIN
	SELECT
		[Resume]
		FROM [dbo].[UserProfessionalDetails]
	WHERE UserId = @userId and [Resume] <> ''
END





GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfEmployerExists]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_CheckIfEmployerExists]
(
	@Company VARCHAR(120),
	@allEmployer BIT
)
AS
BEGIN
	SELECT
		UserId
	FROM dbo.Users
	WHERE CompanyName = @Company
	AND(
		(
			@allEmployer = 1
		)
		OR
		(
		@allEmployer = 0
		AND ISNULL(IsRegisterOnlyForDemandAggregationData,0) = 0
		)
	)
END





GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfJobSaved]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create PROC [dbo].[usp_CheckIfJobSaved]
(
	@userId INT,
	@jobPostId INT
)
AS
BEGIN
	SELECT
		JobPostId
	FROM AppliedJobs
	WHERE UserId = @userId
	AND JobPostId = @jobPostId
END







GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfSkillEmpty]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_CheckIfSkillEmpty] 
(
	@userId INT
)
AS
BEGIN
	SELECT
		Skills
		FROM [dbo].[UserProfessionalDetails]
	WHERE UserId = @userId and Skills <> ''
END





GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfStateCodeExist]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			30/03/2020			Created - Find if state code exist
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_CheckIfStateCodeExist] 
(
	@stateCode VARCHAR(10)
)
AS
BEGIN
	SELECT
		* 
	FROM [dbo].[States]
	WHERE [StateCode] = @stateCode
	
END


GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfTPIdExists]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			01/29/2020			Created - To verify the TPid is exist in table
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_CheckIfTPIdExists]
(
	@tpid VARCHAR(50)
)
AS
BEGIN
	SELECT
		UserId
	FROM dbo.Users
	WHERE Candidateid = @tpid --Storing TPId and CandidateId in same column	
END



GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfUserExistInUserProfessionalDetails]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			10/10/2020			Created - Find if user available in UserProfessionalDetails
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_CheckIfUserExistInUserProfessionalDetails] 
(
	@userId INT
)
AS
BEGIN
	SELECT
		* 
	FROM [dbo].[UserProfessionalDetails]
	WHERE UserId = @userId
	
END





GO
/****** Object:  StoredProcedure [dbo].[usp_CheckIfUserExists]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_CheckIfUserExists]
(
	@Email NVARCHAR(50),
	@Company VARCHAR(120) = NULL
)
AS
BEGIN
	SELECT
		UserId
	FROM dbo.Users
	WHERE Email = @Email
		AND 
		(
			ISNULL(@Company,'') = ''
			OR
			(
				ISNULL(@Company,'') <> ''
				AND CompanyName = @Company
			)
		)
END





GO
/****** Object:  StoredProcedure [dbo].[usp_CreateNewPassword]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_CreateNewPassword]
(
	@Email NVARCHAR(50),
	@Password NVARCHAR(MAX),
	@OldPassword NVARCHAR(MAX)
)
AS
BEGIN
 Update Users
	SET [Password] = @Password,
		UpdatedBy = 0,
		UpdatedOn =GETDATE(),
		PasswordExpiryDate = GETDATE()+30
    WHERE Email = @Email AND
	[Password] = @OldPassword
END





GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteAppliedJob]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_DeleteAppliedJob] 
(
@UserId INT,
@JobPostId INT
)
AS
BEGIN
	UPDATE AppliedJobs
	SET [Status] = 0
	WHERE JobPostId = @JobPostId
	AND UserId = @UserId
END
GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteCandidateByUserid]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_DeleteCandidateByUserid]
(
	@userid int
)
AS
BEGIN
	UPDATE dbo.Users 
	SET IsActive = 0
	WHERE UserId = @userid
END



GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteCity]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*  
-------------------------------------------------------------------------------------------------  
SR   By   Date			Remarks  
1    SR   24/03/2020    Created - To delete City  
-------------------------------------------------------------------------------------------------  
*/
CREATE PROC [dbo].[usp_DeleteCity]
(
	@citycode varchar(100),
	@statecode varchar(100)
)
AS
BEGIN
	UPDATE dbo.[Cities] SET IsActive=0
	WHERE CityCode=@citycode AND StateCode=@statecode
	AND IsActive=1
END



GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteDesignation]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_DeleteDesignation]
(
	@id int
)
AS
BEGIN
	UPDATE Designations SET IsActive=0
		where Designationid =@id
END









GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteFeaturedJob]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			03/02/2020			Created - To Delete featuredjob
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_DeleteFeaturedJob]
(
	@jobpostid int 
)
AS
BEGIN
	UPDATE [dbo].[JobPostDetail]
	SET Featured = 0 
	WHERE JobPostId = @jobpostid
END



GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteITSkill]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			06/08/2020			Update - set status = 0
-------------------------------------------------------------------------------------------------
*/
CREATE PROC[dbo].[usp_DeleteITSkill]
(
@ITSkillId INT,
@UserId INT
)
AS
BEGIN
	UPDATE [dbo].[ITSkills]
		SET 
		[Status] = 0,
		[UpdatedBy] = @UserId,
		[UpdateDate] = GETDATE()
		WHERE Id = @ITSkillId
END


GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteJobIndustryArea]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_DeleteJobIndustryArea]
	@JobIndustryAreaId int,
	@UpdatedBy NVARCHAR(50)
AS 
BEGIN
	UPDATE JobIndustryArea
	SET 
	Status=0,
	[UpdatedBy] = @UpdatedBy,
	[UpdatedDate] = GETDATE()
	WHERE 
	JobIndustryAreaId=@JobIndustryAreaId
END






GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteJobTitle]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_DeleteJobTitle]
	@JobTitleId int,
	@UpdatedBy NVARCHAR(50)
AS 
BEGIN
	UPDATE JobTitle
	SET 
	Status=0,
	[UpdatedBy] = @UpdatedBy,
	[UpdatedDate] = GETDATE()
	WHERE 
	JobTitleId=@JobTitleId
END






GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteState]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_DeleteState] 
(
	@countryCode NVARCHAR(5),
	@stateCode NVARCHAR(50)
	)
AS 
BEGIN
	UPDATE States 
	SET
		IsActive=0
		WHERE
		CountryCode=@countryCode
		AND
		StateCode=@stateCode
END




GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteSuccessStory]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_DeleteSuccessStory]
	@Id int,
	@UpdatedBy NVARCHAR(50)
AS 
BEGIN
	UPDATE [dbo].[SuccessSotry]
	SET 
	Status=0,
	 [UpdatedBy]= @UpdatedBy,
	[UpdatedDate] = GETDATE()
	WHERE 
	Id=@Id
END




GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteSuccessStoryVid]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_DeleteSuccessStoryVid]
	@SSId int,
	@UpdatedBy NVARCHAR(50)
AS 
BEGIN
	UPDATE [dbo].[SuccessStoryVideo]
	SET 
	Status=0,
	[UpdatedBy] = @UpdatedBy,
	[UpdatedDate] = GETDATE()
	WHERE 
	[Id]=@SSId
END





GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteUserById]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_DeleteUserById]
	@userid int
AS 
BEGIN
	--DELETE FROM USERS WHERE userid=@userid
	UPDATE USERS SET IsActive=0 WHERE userid=@userid
END







GO
/****** Object:  StoredProcedure [dbo].[usp_ForgetPassword]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_ForgetPassword]
(
	@Email NVARCHAR(50)
)
AS
BEGIN
	SELECT 
		Email		
	FROM Users 
	WHERE Email = @Email
END







GO
/****** Object:  StoredProcedure [dbo].[usp_GetAdminGraphData]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetAdminGraphData] 
(
	@Year   INT, 
	@Gender VARCHAR(15), 
	@State  VARCHAR(50)
) 
AS 
  BEGIN 
      -- Active Jobs Month Wise 
      SELECT Count(JPD.jobpostid)                 AS TotalJobPost, 
             Month(Cast(JPD.createddate AS DATE)) AS [Month], 
             Year(Cast(JPD.createddate AS DATE))  AS [Year] 
      FROM   dbo.jobpostdetail JPD 
             LEFT JOIN dbo.users U 
                    ON JPD.createdby = U.userid 
             LEFT JOIN dbo.userroles UR 
                    ON U.userid = UR.userid 
             LEFT JOIN dbo.roles R 
                    ON UR.roleid = R.id 
      WHERE  Year(Cast(JPD.createddate AS DATE)) = @Year 
             AND (
					(
					Isnull(@State, '') = ''
					) 
					OR
					( 
					Isnull(@State, '') <> '' 
					AND JPD.statecode = @State 
					) 
				) 
             AND Cast(JPD.positionenddate AS DATE) >= Cast(Getdate() AS DATE) 
             AND R.id IN ( 3, 4 ) 
			 AND U.IsActive=1   --- To exclude deleted user 06/12/2020
      GROUP  BY Month(Cast(JPD.createddate AS DATE)), 
                Year(Cast(JPD.createddate AS DATE)) 

      -- Applied jobs month wise data 
      SELECT Count(AJ.userid)                    AS TotalJobApplied, 
             Month(Cast(AJ.applieddate AS DATE)) AS [Month], 
             Year(Cast(AJ.applieddate AS DATE))  AS [Year] 
      FROM   dbo.appliedjobs AJ 
             LEFT JOIN dbo.jobpostdetail JPD 
                    ON AJ.jobpostid = JPD.jobpostid 
             LEFT JOIN dbo.users U 
                    ON AJ.userid = U.userid 
             LEFT JOIN dbo.userroles UR 
                    ON U.userid = UR.userid 
             LEFT JOIN dbo.roles R 
                    ON UR.roleid = R.id 
      WHERE  Year(Cast(AJ.applieddate AS DATE)) = @Year 
			AND (
					(
					Isnull(@State, '') = '' 
					) 
					OR 
					( 
					Isnull(@State, '') <> '' 
					AND JPD.statecode = @State
					) 
				) 
             AND R.id = 2 
			 AND ( 
					( 
					Isnull(@Gender, 'all') = 'all' 
					) 
					OR 
					(
					Isnull(@Gender, 'all') <> 'all' 
					AND U.gender = @Gender 
					)
				) 
			AND U.IsActive=1   --- To exclude deleted user 06/12/2020
      GROUP  BY Month(Cast(AJ.applieddate AS DATE)), 
                Year(Cast(AJ.applieddate AS DATE)) 

      -- Closed jobs month wise data 
      SELECT Count(JPD.jobpostid)                 AS TotalActiveClosedJobs, 
             Month(Cast(JPD.createddate AS DATE)) AS [Month], 
             Year(Cast(JPD.createddate AS DATE))  AS [Year] 
      FROM   dbo.jobpostdetail JPD 
             LEFT JOIN dbo.users U 
                    ON JPD.createdby = U.userid 
             LEFT JOIN dbo.userroles UR 
                    ON U.userid = UR.userid 
             LEFT JOIN dbo.roles R 
                    ON UR.roleid = R.id 
      WHERE  Year(Cast(JPD.createddate AS DATE)) = @Year 
			AND (
					( 
						Isnull(@State, '') = ''
					) 
					OR
					(
						Isnull(@State, '') <> '' 
						AND JPD.statecode = @State
					) 
				) 
			AND Cast(JPD.positionenddate AS DATE) < Cast(Getdate() AS DATE) 
            AND R.id IN ( 3, 4 ) 
			AND U.IsActive=1   --- To exclude deleted user 06/12/2020
      GROUP  BY Month(Cast(JPD.createddate AS DATE)), 
                Year(Cast(JPD.createddate AS DATE)) 

      -- User Registration month wise data 
      SELECT Count(U.userid)                  AS TotalRegistration, 
             Month(Cast(U.createdon AS DATE)) AS [Month], 
             Year(Cast(U.createdon AS DATE))  AS [Year] 
      FROM   dbo.users U 
             LEFT JOIN dbo.userroles UR 
                    ON U.userid = UR.userid 
             INNER JOIN dbo.roles R 
                     ON UR.roleid = R.id 
      WHERE  Year(Cast(U.createdon AS DATE)) = @Year 
				AND (
						(
						Isnull(@State, '') = '' 
						) 
						OR 
						(
						Isnull(@State, '') <> '' 
						AND U.[state] = @State 
						) 
					) 
				AND (
						(
						Isnull(@Gender, 'all') = 'all' 
						) 
						OR 
						( Isnull(@Gender, 'all') <> 'all' 
						AND U.gender = @Gender
						)
					) 
             AND Isnull(U.isregisteronlyfordemandaggregationdata, 0) = 0 
             AND R.id <> 1 
			 AND U.IsActive=1   --- To exclude deleted user 06/12/2020
      GROUP  BY Month(Cast(U.createdon AS DATE)), 
                Year(Cast(U.createdon AS DATE)) 
  END 

GO
/****** Object:  StoredProcedure [dbo].[usp_GetAllCitiesWithoutState]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*  
-------------------------------------------------------------------------------------------------  
SR   By   Date    Remarks  
1   SR   11/02/2020   Created - To get All the Cities  
-------------------------------------------------------------------------------------------------  
*/  
CREATE PROCEDURE [dbo].[usp_GetAllCitiesWithoutState]  
AS   
BEGIN  
 SELECT   
  CityCode,  
  Name as City,
  StateCode
 FROM [dbo].[Cities] 
 WHERE IsActive = 1 
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetAllJobIndustryArea]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetAllJobIndustryArea]
AS 
BEGIN
	SELECT 
		ROW_NUMBER() Over (Order by JobIndustryAreaId) As SerialNo,
		[JobIndustryAreaId],
		[JobIndustryAreaName]
		FROM [dbo].[JobIndustryArea]
		WHERE Status = 1
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetAllNasscomJobs]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetAllNasscomJobs]
(
	@EmployerId INT = 119
)
AS
BEGIN
	WITH CTE_GetNassComJobs AS
	(
		SELECT 	
			U.CompanyName AS CompanyName,
			U.ProfilePic AS CompanyLogo,
			JP.JobPostid AS JobPostId,
			JT.JobTitleName AS JobTitle,
			CT.Name AS City,
			ES.EmploymentStatusName AS EmploymentStatus
		FROM 
			dbo.JobPostDetail AS JP
			LEFT JOIN dbo.Users AS U
			ON JP.UserId = U.UserID
			LEFT JOIN dbo.JobRoleMapping JRM
			ON JP.JobPostId = JRM.JobId
			LEFT JOIN dbo.JobTitle AS JT
			ON JRM.JobRoleId = JT.JobTitleid
			LEFT JOIN dbo.Cities AS CT
			ON JP.CityCode = CT.CityCode
			LEFT JOIN dbo.EmploymentStatus AS ES
			ON JP.EmploymentStatusId = ES.EmploymentStatusId
		WHERE U.Userid = @EmployerId
	)

	SELECT
		DISTINCT
		CompanyName,
		CompanyLogo,
		JobPostId,
		STUFF(
			(
				SELECT 
					', ' + JobTitle
				FROM CTE_GetNassComJobs CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobTitle,
		City,
		EmploymentStatus
	FROM CTE_GetNassComJobs CTE1
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetAllPlacedCandidate]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-------------------------------------------------------------------------------------
/*  
-------------------------------------------------------------------------------------------------  
SR   By   Date				Remarks  
1    SR   26/03/2020    	Created - To Get All Data of PlacedCandidate
-------------------------------------------------------------------------------------------------  
*/
CREATE PROC [dbo].[usp_GetAllPlacedCandidate]
AS
BEGIN
	SELECT 
			SumofCandidateContactNo,
			CandidateEmail,
			CandidateID,
			CandidateName,
			Castecategory, 
			CertificateDate,
			Certified ,
			EmployerspocEmail ,
			EmployerspocMobile,
			EmployerType ,
			EmployerSpocName ,
			FirstEmploymentCreatedDate ,
			FromDate ,
			FYWise ,
			Gender ,
			Jobrole ,
			AvgofNoofdaysbetweennDOCDOP ,
			AverageofNoOfMonthsofPlacement ,
			OrganisationDistrict ,
			OrganisationState ,
			OrganizationAddress ,
			OrganizationName ,
			PartnerName ,
			PartnerSPOCMobile , 
			PartnerSPOCName ,
			CountofPartnerID ,
			SumofSalleryPerMonth ,
			PartnerSPOCEmail ,
			CountofSCTrainingCentreID ,
			SectorName ,
			SelfEmployedDistrict ,
			SelfEmployedState ,
			TCDistrict ,
			TCSPOCEmail ,
			SumofTCSPOCMobile ,
			TCSPOCName ,
			TCState ,
			ToDate ,
			TrainingCentreName ,
			TrainingType ,
			EducationAttained ,
			CreatedDate ,
			CreatedBy
		FROM dbo.PlacedCandidateDetails 
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetAllScucessStoryVid]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetAllScucessStoryVid]
AS 
BEGIN
	SELECT 
		--ROW_NUMBER() Over (Order by [Id]) As SerialNo,
		[Id],
		[Title],
		[Type],
		[FileName],
		[DisplayOrder]
		FROM [dbo].[SuccessStoryVideo]
		WHERE Status = 1
		ORDER BY [TYPE],[DisplayOrder]
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetAllUsers]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetAllUsers]   
(  
 @userId INT  
)  
AS     
BEGIN    
 SELECT     
  U.[UserId]    
    ,U.[FirstName]    
    ,U.[LastName]    
    ,U.[MobileNo]    
    ,U.[Email]    
    ,U.[Address1]    
    ,U.[City]    
    ,U.[State]    
    ,U.[Country]    
    ,U.[MaritalStatus]    
    ,U.[ProfilePic]    
    ,U.[CreatedBy]    
    ,U.[Gender]    
    ,U.[Password]    
    ,U.[IsApproved]    
	--,dbo.UTC2Indian(U.[CreatedOn]) AS CreatedOn
    ,U.[CreatedOn]    
    ,ISNULL(U.[IsViewedByAdmin],0) AS IsViewed  
    ,UR.[RoleId]    
    ,UR.[UserId]    
    ,R.[Id]    
    ,R.[RoleName]    
  FROM [dbo].[Users] U  
  INNER JOIN dbo.UserRoles UR    
  ON U.[Userid]=UR.[Userid]  
  INNER JOIN dbo.Roles R     
  ON UR.[RoleId]=R.[Id]  
 WHERE U.IsActive=1  
 AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0  
 ORDER BY   
  U.CreatedOn DESC  
   
 -- Update Unviewed Users as viewed  
 IF EXISTS  
 (  
  SELECT  
   1  
  FROM dbo.Users U  
   INNER JOIN dbo.UserRoles UR  
   ON U.UserId = UR.UserId  
   INNER JOIN dbo.Roles R  
   ON UR.RoleId = R.ID  
  WHERE U.UserId = @userId  
   AND R.ID = 1  
 )  
 BEGIN  
  EXEC usp_UpdateUsersAsAdminViewed  
 END  
END  

GO
/****** Object:  StoredProcedure [dbo].[usp_GetAllUsersRegistrations]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetAllUsersRegistrations]
 (
	@registrationType VARCHAR(20), 
	@sDate            DATETIME, 
	@eDate            DATETIME
 ) 
AS 
  BEGIN 
      SELECT U.[userid], 
             U.[firstname], 
             U.[lastname], 
             U.[mobileno], 
             U.[email], 
             TPU.firstname + ' ' + TPU.lastname AS TPName, 
             CT.[name]                          AS City, 
             ST.[name]                          AS State, 
             U.[gender], 
             U.createdon, 
             --dbo.UTC2Indian(U.[CreatedOn]) AS CreatedOn, 
             U.[maritalstatus], 
             R.[rolename],
			 U.[IsActive]
      FROM   [dbo].[users] U 
             LEFT JOIN dbo.userroles UR 
                    ON U.[userid] = UR.[userid] 
             LEFT JOIN dbo.roles R 
                    ON UR.[roleid] = R.[id] 
             LEFT JOIN [dbo].[cities] AS CT 
                    ON U.city = CT.citycode 
             LEFT JOIN [dbo].[states] AS ST 
                    ON U.[state] = ST.statecode 
             LEFT JOIN users TPU 
                    ON TPU.userid = U.createdby 
      WHERE  Cast(U.createdon AS DATE) >= Cast(@sDate AS DATE) 
             AND Cast(U.createdon AS DATE) <= Cast(@eDate AS DATE) 
             AND Isnull(U.isregisteronlyfordemandaggregationdata, 0) = 0 
             AND (
					(
						Isnull(@registrationType, '') = '' 
					) 
					OR
					( 
						Isnull(@registrationType, '') <> '' 
						AND @registrationType = 'Student' 
						AND R.id = 2 
					) 
					OR 
					( 
						Isnull(@registrationType, '') <> '' 
						AND @registrationType = 'Corporate' 
						AND R.id = 3 
					) 
					OR 
					( 
						Isnull(@registrationType, '') <> '' 
								AND @registrationType = 'Staffing Partner' 
								AND R.id = 4 
					) 
					OR 
					( 
						Isnull(@registrationType, '') <> '' 
						AND @registrationType = 'Training Partner' 
						AND R.id = 5 
					 ) 
				)
				--AND U.IsActive=1 --- To exclude deleted user 06/12/2020
      ORDER  BY U.createdon DESC 
  END 

GO
/****** Object:  StoredProcedure [dbo].[usp_GetAppliedJobMonthWise]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR		By		Date			Remarks
1		SR		04/03/2020		Update - Gender wise and year wise job applied with employer details
-------------------------------------------------------------------------------------------------
*/


CREATE PROC [dbo].[usp_GetAppliedJobMonthWise] 
(
	@AppliedJobMonth VARCHAR(MAX) ,
	@Year VARCHAR(MAX),
	@Gender Varchar(MAX)
)
AS
BEGIN
If(@Gender='ALL')
Begin

	BEGIN
	 SELECT DISTINCT
		U.UserId,
		 U.[FirstName]
		,U.[LastName]
		,U.[Email]
		,U.[MobileNo]
		,U.[ContactPerson]
		,City.[Name] AS City
		,States.[Name] AS State
		,Country.Name AS Country
		,JA.[JobIndustryAreaName]
		,CAST(AJ.[CreatedDate] AS [date]) AS AppliedDate
		,ES.[EmploymentStatusName]
		,JPD.JobTitleByEmployer AS JobRole
		,JPD.[CreatedDate] AS JobPostDate
		,JPCity.Name AS JobPostCity
		,JPD.SPOC AS JobPostContactPerson
		,JobPostUsers.CompanyName AS CompanyName
	FROM [dbo].[Users] AS U 
		INNER JOIN [dbo].[AppliedJobs] AS AJ
		ON U.[Userid]=AJ.[Userid]
		LEFT JOIN [dbo].[UserProfessionalDetails] AS JP
		ON JP.[UserId] = AJ.[UserId]
		LEFT JOIN JobIndustryArea AS JA
		ON JP.JobIndustryAreaId = JA.JobIndustryAreaId
		LEFT JOIN Countries AS Country
		ON U.[Country] = Country.CountryCode
		LEFT JOIN States AS States
		ON U.[State] = States.StateCode
		LEFT JOIN Cities AS City
		ON U.City = City.CityCode
		LEFT JOIN EmploymentStatus AS ES
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		Left JOIN 
		 UserRoles AS UR
		 ON
		 UR.UserId = U.UserId
		 LEFT JOIN [dbo].[JobPostDetail] AS JPD
		 ON
		 JPD.JobPostId = AJ.JobPostId
		 LEFT JOIN 
		 Cities AS JPCity
		 ON
		 JPD.CityCode = JPCity.CityCode
		 LEFT JOIN Users AS JobPostUsers
		 ON
		 JobPostUsers.UserId = JPD.UserId
	WHERE
		--TRY_CONVERT(DATE,JP.CreatedDate) = '2019-12-23'
		MONTH(AJ.CreatedDate) = @AppliedJobMonth
		AND
			U.IsActive=1
		AND
		   Year(AJ.CreatedDate) = @Year
		   
	END
	END
	ELSE
	BEGIN ----gender code here--------
	BEGIN
	  SELECT DISTINCT
		U.UserId,
		 U.[FirstName]
		,U.[LastName]
		,U.[Email]
		,U.[MobileNo]
		,U.[ContactPerson]
		,City.[Name] AS City
		,States.[Name] AS State
		,Country.Name AS Country
		,JA.[JobIndustryAreaName]
		,CAST(AJ.[CreatedDate] AS [date]) AS AppliedDate
		,ES.[EmploymentStatusName]
		,JPD.JobTitleByEmployer AS JobRole
		,JPD.[CreatedDate] AS JobPostDate
		,JPCity.Name AS JobPostCity
		,JPD.SPOC AS JobPostContactPerson
		,JobPostUsers.CompanyName AS CompanyName
	FROM [dbo].[Users] AS U 
		INNER JOIN [dbo].[AppliedJobs] AS AJ
		ON U.[Userid]=AJ.[Userid]
		LEFT JOIN [dbo].[UserProfessionalDetails] AS JP
		ON JP.[UserId] = AJ.[UserId]
		LEFT JOIN JobIndustryArea AS JA
		ON JP.JobIndustryAreaId = JA.JobIndustryAreaId
		LEFT JOIN Countries AS Country
		ON U.[Country] = Country.CountryCode
		LEFT JOIN States AS States
		ON U.[State] = States.StateCode
		LEFT JOIN Cities AS City
		ON U.City = City.CityCode
		LEFT JOIN EmploymentStatus AS ES
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		Left JOIN 
		 UserRoles AS UR
		 ON
		 UR.UserId = U.UserId
		 LEFT JOIN [dbo].[JobPostDetail] AS JPD
		 ON
		 JPD.JobPostId = AJ.JobPostId
		 LEFT JOIN 
		 Cities AS JPCity
		 ON
		 JPD.CityCode = JPCity.CityCode
		 LEFT JOIN Users AS JobPostUsers
		 ON
		 JobPostUsers.UserId = JPD.UserId
	WHERE
		--TRY_CONVERT(DATE,JP.CreatedDate) = '2019-12-23'
		MONTH(AJ.CreatedDate) = @AppliedJobMonth
		AND
			U.IsActive=1
		AND
		   Year(AJ.CreatedDate) = @Year
		AND
		U.Gender = @Gender
	END
	END
END








GO
/****** Object:  StoredProcedure [dbo].[usp_GetAppliedJobs]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR  		By			Date				Remarks
1			SR			14/01/2020			Created - To get all applied jobs of user
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetAppliedJobs]
(
	@userid int
)
AS
BEGIN
  SELECT
    JobPostId
  FROM [dbo].[AppliedJobs]
  WHERE UserId = @userid
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetAppliedJobsInDateRange]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetAppliedJobsInDateRange]
(
	@StartDate varchar(max) = NULL,
	@EndDate varchar(max) = NULL
)
AS
BEGIN
	SELECT
		U.[Userid],
		U.FirstName,
		U.LastName,
		U.[Email],
		U.[MobileNo],
		JPD.JobTitleByEmployer,
		JPD.CTC,
		JT.[Type] AS JobTypeDesc,
		U2.CompanyName,
		CT.Name AS City,
		S.Name AS [State],
		AJ.AppliedDate
	FROM dbo.AppliedJobs AJ
		INNER JOIN dbo.JobPostDetail JPD
		ON AJ.JobPostId = JPD.JobPostId
		LEFT JOIN dbo.Users U
		ON AJ.UserId = U.UserId
		LEFT JOIN dbo.JobTypes JT
		ON JPD.JobType = JT.Id
		LEFT JOIN dbo.Users U2
		ON JPD.UserId = U2.UserId
		LEFT JOIN dbo.States S
		ON JPD.StateCode = S.StateCode
		LEFT JOIN dbo.Cities CT
		ON JPD.CityCode = CT.CityCode

		LEFT JOIN dbo.Users U3
		ON JPD.CreatedBy = U3.UserId
		LEFT JOIN dbo.UserRoles UR
		ON UR.UserId = U3.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.ID
	WHERE CAST(AJ.AppliedDate AS DATE) >= CAST(@StartDate AS DATE)
		AND CAST(AJ.AppliedDate AS DATE) <= CAST(@EndDate AS DATE)
		AND R.ID IN (3,4)
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020 
	ORDER BY 
		AJ.AppliedDate DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetAverageResponseTime]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetAverageResponseTime]
(
	@EmpId INT
)
AS
BEGIN
	SELECT 
		ISNULL(SUM(DATEDIFF(HOUR,EQ.CreatedOn,EQ.RepliedOn)),0) 
			/
		CASE WHEN ISNULL(COUNT(EQ.Id),0) = 0 THEN 1 ELSE ISNULL(COUNT(EQ.Id),0) END
		AS RespondTime
	FROM dbo.EmailQueue EQ
		INNER JOIN dbo.Users U
		ON EQ.ToId = U.UserId
		INNER JOIN dbo.UserRoles UR
		ON U.UserId = UR.UserId
		INNER JOIN dbo.Roles R
		ON UR.RoleId = R.ID
		INNER JOIN dbo.MailType MT
		ON EQ.MailType = MT.Id
	WHERE U.UserId= @EmpId
		AND U.IsActive = 1
		AND R.Id = 3
		AND EQ.IsReplied = 1
		AND EQ.RepliedOn IS NOT NULL
		AND MT.Id = 6
		AND MT.IsActive = 1
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetCandidateDetailByUserid]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetCandidateDetailByUserid]
(
	@userid int
)
AS
BEGIN
	SELECT Candidateid,
		   FirstName,
		   LastName,
		   Email,
		   Password		
	FROM dbo.Users 
	WHERE UserId = @userid
END



GO
/****** Object:  StoredProcedure [dbo].[usp_getCategory]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_getCategory]  
AS  
 BEGIN  
 SELECT TOP 5 [JobIndustryAreaId]  
    ,[JobIndustryAreaName]  
     FROM [dbo].[JobIndustryArea]  
END  



GO
/****** Object:  StoredProcedure [dbo].[usp_GetCategoryJobVacancies]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 /*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			20/08/2020			Created - Getting all category jobs that have jobs
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetCategoryJobVacancies]
AS 
BEGIN
	SELECT
	JA.JobIndustryAreaId AS JobIndustryAreaId,
	JA.JobIndustryAreaName AS JobIndustry,
	COUNT(JPD.JobPostId) AS [COUNT]
FROM dbo.JobIndustryArea JA
	LEFT JOIN dbo.JobPostDetail JPD
	LEFT JOIN dbo.Users U2
		ON JPD.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id
	ON JA.JobIndustryAreaId = JPD.JobIndustryAreaId
	LEFT JOIN dbo.PopularJobSearches PJS
	ON PJS.FilterName = 'JobCategory'
		AND PJS.FilterValue = JA.JobIndustryAreaId
		Where JPD.JobPostId !='0'
		AND ISNULL(R.ID,0) !=1
		AND U2.IsActive=1   --- To exclude deleted user 06/12/2020
	GROUP BY
		JA.JobIndustryAreaId,
		JA.JobIndustryAreaName,
		PJS.Count
	ORDER BY
		PJS.Count DESC

END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetCities]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetCities]
(
	@stateCode NVARCHAR(5) = NULL
)
AS 
BEGIN
	IF(ISNULL(@stateCode,'') <> '')
	BEGIN
		SELECT
			CityCode,
			Name as City
		FROM [dbo].[Cities]
		WHERE IsActive=1
			AND StateCode=@stateCode
	END
	ELSE
	BEGIN
		SELECT
			CityCode,
			Name as City
		FROM [dbo].[Cities]
		WHERE IsActive=1
	END 
END








GO
/****** Object:  StoredProcedure [dbo].[usp_GetCitiesListWithFirstChar]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetCitiesListWithFirstChar]
(
	@cityFirstChar VARCHAR(50)
)
AS 
BEGIN
	SELECT  Name AS City,CityCode FROM Cities WHERE Name LIKE  @cityFirstChar +'%'
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetCitiesWithJobPostUserId]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetCitiesWithJobPostUserId]
AS 
BEGIN
	SELECT 
		CT.CityCode AS CityCode,
		CT.Name AS City,
		COUNT(JP.JobPostId)As CountValue
	FROM dbo.Cities AS CT
		LEFT JOIN [dbo].[JobPostDetail] AS JP
		ON CT.CityCode = JP.CityCode
		AND CAST(JP.PositionEndDate AS DATE) >= CAST(GETDATE() AS DATE)
		LEFT JOIN dbo.Users U
		ON JP.CreatedBy = U.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.ID
		AND R.ID IN (3,4)
	WHERE CT.IsActive = 1
	GROUP BY
		CT.CityCode,
		CT.Name
	ORDER BY
		CountValue DESC
		

	--SELECT 
	--	COUNT(UserId)As CountValue,
	--	CT.CityCode AS CityCode,
	--	CT.Name AS City
	--FROM [dbo].[JobPostDetail] AS JP
	--	INNER JOIN Cities AS CT
	--	ON CT.CityCode = JP.CityCode
	--GROUP BY
	--	CT.CityCode,CT.Name
	--HAVING
	--	COUNT(JP.UserId) !='0' ;
END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetCitiesWithJobSeekerInfo]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetCitiesWithJobSeekerInfo]
AS 
BEGIN
	SELECT
		CT.CityCode,
		CT.NAME AS City,
		COUNT(U.UserId) As CountValue
	FROM dbo.Cities CT
		LEFT JOIN dbo.Users U
		ON CT.CityCode = U.City
		AND U.IsActive = 1
		LEFT JOIN dbo.UserProfessionalDetails UPD
		ON U.UserId = UPD.UserId
		AND UPD.UserId IS NOT NULL
	WHERE CT.IsActive = 1
	GROUP BY
		CT.CityCode,
		CT.Name
	ORDER BY
		CountValue DESC
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetCitiesWithoutState]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetCitiesWithoutState]
AS 
BEGIN

	SELECT 
		COUNT(UserId) As CountValue,
		CityCode,
		Name as City
	FROM [dbo].[Cities] AS C
	Left Join Users AS US on US.City = C.CityCode
	Group by C.Name,
	C.CityCode,C.Name,US.IsActive
	HAVING US.ISActive = 'true'
	ORDER BY CityCode DESC	
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetCityByCityCode]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetCityByCityCode]
(
	@cityCode NVARCHAR(15)
)
AS
BEGIN
	SELECT 
		Name
	FROM  [dbo].[Cities] 
	WHERE CityCode = @cityCode
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetCityJobVacancies]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			20/08/2020			Created -Getting city list that have jobs
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetCityJobVacancies]
AS 
BEGIN
	SELECT
	C.CityCode,
	C.Name AS City,
	COUNT(JPD.JobPostId) AS [COUNT]
FROM dbo.Cities C
	LEFT JOIN dbo.JobPostDetail JPD
	INNER JOIN dbo.Users AS U
	ON
	 JPD.UserId =U.UserId
	ON C.CityCode = JPD.CityCode

	LEFT JOIN dbo.Users U2
		ON JPD.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

	LEFT JOIN dbo.PopularJobSearches PJS
	ON PJS.FilterName = 'City'
		AND PJS.FilterValue = C.CityCode
		Where JPD.JobPostId !='0'
		AND ISNULL(R.ID,0) !=1
		AND U.IsActive =1 
	GROUP BY
		C.CityCode,
		C.Name,
		PJS.Count
	ORDER BY
		PJS.Count DESC
END


-------3--------------------------

GO
/****** Object:  StoredProcedure [dbo].[usp_GetCompanyJobs]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetCompanyJobs]
AS
BEGIN
SELECT
	U2.CompanyName,
	COUNT(JPD.UserId) AS [COUNT],
	U2.UserId
FROM dbo.JobPostDetail JPD
	LEFT JOIN dbo.Users U2
		ON JPD.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id
	
	Where JPD.JobPostId !='0'
		AND ISNULL(R.ID,0) !=1
		AND U2.IsActive=1
		AND JPD.[Status]=1
	GROUP BY
		JPD.UserId,
		U2.CompanyName,
		U2.UserId
	ORDER BY
		U2.CompanyName ASC
END


----------------4-----------------------

GO
/****** Object:  StoredProcedure [dbo].[usp_GetCompanyNamehaveJobPost]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetCompanyNamehaveJobPost]
AS
BEGIN
	SELECT
	U.[CompanyName],
	U.UserId,
	COUNT(JP.JobPostId)As CountValue
	FROM [dbo].[Users] AS U
	LEFT JOIN [dbo].[JobPostDetail] AS JP
	ON JP.CreatedBy = U.UserId
	LEFT JOIN dbo.UserRoles UR
	ON U.UserId = UR.UserId
	LEFT JOIN dbo.Roles R
	ON UR.RoleId = R.ID
	WHERE U.IsActive = 1
	AND CAST(JP.PositionEndDate AS DATE) >= CAST(GETDATE() AS DATE)
	AND R.ID IN (3,4)

	GROUP BY
	U.[CompanyName],
	U.UserId
	ORDER BY
	CountValue DESC
END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetCountries]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetCountries]
AS 
BEGIN
	SELECT 
		CountryCode,
		Name As Country
	FROM [dbo].[Countries]
	WHERE IsActive=1
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetCourseCategories]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetCourseCategories]
AS
BEGIN
	SELECT
		CategoryId,
		Name
	FROM dbo.CourseCategories
	WHERE IsActive = 1
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetCourseNameBycourseId]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			24/02/2020			Created - To get Course name by course id
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetCourseNameBycourseId]
(
	@courseid int
)
AS
BEGIN
	SELECT Name AS CourseName FROM  [dbo].[Courses] 
	WHERE courseid=@courseid
END




GO
/****** Object:  StoredProcedure [dbo].[usp_GetCourses]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetCourses]
(
	@CategoryId INT
)
AS
BEGIN
	SELECT
		CourseId,
		Name
	FROM dbo.Courses
	WHERE IsActive = 1
		AND Category = @CategoryId
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetCoursesNamebyCourseCategory]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			01/08/2020			Created 	
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetCoursesNamebyCourseCategory]
(
	@Category varchar(max)
)
AS
BEGIN
	SELECT C.Name,C.CourseId
	FROM CourseCategories CC
	INNER JOIN Courses C on C.category=CC.categoryID
	Where CC.IsActive=1 AND C.IsActive=1
	AND CC.Name=@Category
END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetCourseTypeMaster]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetCourseTypeMaster]
AS
BEGIN
	SELECT
		CourseTypeId,
		Type
	FROM dbo.CourseType
	WHERE IsActive = 1
END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDataOnEmployer]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetDemandAggregationDashboardDataOnEmployer]
(
	@employers VARCHAR(MAX),
	@year INT,
	@userRole INT,
	@jobRoles VARCHAR(MAX),
	@jobStates VARCHAR(MAX)
)
AS
BEGIN

	SELECT 
		CompanyName INTO
		#TempCompanies
	FROM dbo.Users
	WHERE ( 
			(
				ISNULL(@employers,'') = ''	
			)
			OR 
			(
				ISNULL(@employers,'') <> ''
				AND UserId IN (SELECT val FROM F_SPLIT(@employers,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND ISNULL(CompanyName, '') <> ''
		AND IsActive=1  --- To exclude deleted user 06/12/2020 

	SELECT
		--U.UserId,
		--U.FirstName,
		--U.LastName,
		U.CompanyName,
		JPD.FinancialYear AS PostedYear,
		SUM(JPD.Quarter1) AS Q1,
		SUM(JPD.Quarter2) AS Q2,
		SUM(JPD.Quarter3) AS Q3,
		SUM(JPD.Quarter4) AS Q4
	FROM dbo.JobPostDetail JPD

		LEFT JOIN dbo.Users U2
		ON JPD.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR2
		ON U2.UserId = UR2.UserId
		LEFT JOIN dbo.Roles R2
		ON UR2.RoleId = R2.Id
		
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JPD.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle JT
		ON JRM.JobRoleId = JT.JobTitleId

		LEFT JOIN dbo.States S
		ON JPD.StateCode = S.StateCode

		INNER JOIN dbo.Users U
		ON JPD.UserId = U.UserId
		INNER JOIN dbo.UserRoles UR
		ON UR.UserId = U.UserId
		INNER JOIN dbo.Roles R
		ON UR.RoleId = R.ID

	WHERE (
			@userRole = 0
			OR
			(
				@userRole = 1
				AND R2.Id = @userRole
			)
			OR
			(
				@userRole > 2
				AND @userRole < 5
				AND R2.Id > 2
				AND R2.Id < 5
			)
		)
		AND JPD.UserId IN
						(
							SELECT
								UserId
							FROM dbo.Users
							WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
						)
		AND JPD.FinancialYear = @year
		AND (
				(
				ISNULL(@jobRoles,'') = ''
				)
				OR
				(
					ISNULL(@jobRoles,'') <> ''
					AND
					JT.JobTitleId IN (SELECT val FROM dbo.f_split(@jobRoles, ','))
				)
			)
		AND (
				(
				ISNULL(@jobStates,'') = ''
				)
				OR
				(
					ISNULL(@jobStates,'') <> ''
					AND
					S.StateCode IN (SELECT val FROM dbo.f_split(@jobStates, ','))
				)
			)
	GROUP BY 
		U.CompanyName,
		JPD.FinancialYear
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDataOnJobRole]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetDemandAggregationDashboardDataOnJobRole] 
(
	@jobRoles VARCHAR(MAX),
	@year INT,
	@userRole INT,
	@employers VARCHAR(MAX),
	@jobStates VARCHAR(MAX)
)
AS
BEGIN

	SELECT 
		CompanyName INTO
		#TempCompanies
	FROM dbo.Users
	WHERE ( 
			(
				ISNULL(@employers,'') = ''	
			)
			OR 
			(
				ISNULL(@employers,'') <> ''
				AND UserId IN (SELECT val FROM F_SPLIT(@employers,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND ISNULL(CompanyName, '') <> ''
		AND IsActive=1  --- To exclude deleted user 06/12/2020 

	SELECT
		JT.JobTitleId,
		JT.JobTitleName,
		JPD.FinancialYear AS PostedYear,
		SUM(JPD.Quarter1) AS Q1,
		SUM(JPD.Quarter2) AS Q2,
		SUM(JPD.Quarter3) AS Q3,
		SUM(JPD.Quarter4) AS Q4
	FROM dbo.JobPostDetail JPD
		INNER JOIN dbo.JobRoleMapping JRM
		ON JPD.JobPostId = JRM.JobId
		INNER JOIN dbo.JobTitle JT
		ON JRM.JobRoleId = JT.JobTitleId

		LEFT JOIN dbo.Users U
		ON JPD.CreatedBy = U.UserId
		Left JOIN dbo.UserRoles UR
		ON U.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

		LEFT JOIN dbo.States S
		ON JPD.StateCode = S.StateCode

		LEFT JOIN dbo.Users U2
		ON JPD.UserId = U2.UserId

	WHERE (
			(
				ISNULL(@jobRoles,'') = ''
			)
			OR 
			(
				ISNULL(@jobRoles,'') <> ''
				AND JT.JobTitleId IN (SELECT val FROM F_SPLIT(@jobRoles,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND JPD.FinancialYear = @year
		AND
			(
				@userRole = 0
				OR
				(
					@userRole = 1
					AND R.Id = @userRole
				)
				OR
				(
					@userRole > 2
					AND @userRole < 5
					AND R.Id > 2
					AND R.Id < 5
				)
			)
		AND JPD.UserId IN
						(
							SELECT
								UserId
							FROM dbo.Users
							WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
						)
		AND (
				(
				ISNULL(@jobStates,'') = ''
				)
				OR
				(
					ISNULL(@jobStates,'') <> ''
					AND
					S.StateCode IN (SELECT val FROM dbo.f_split(@jobStates, ','))
				)
			)
	GROUP BY 
		JT.JobTitleId,
		JT.JobTitleName,
		JPD.FinancialYear
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDataOnQuarter]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetDemandAggregationDashboardDataOnQuarter] 
(
	@Year INT,
	@userRole INT,
	@states VARCHAR(MAX),
	@employers VARCHAR(MAX),
	@jobRoles VARCHAR(MAX)
)
AS
BEGIN

	SELECT 
		CompanyName INTO
		#TempCompanies
	FROM dbo.Users
	WHERE ( 
			(
				ISNULL(@employers,'') = ''	
			)
			OR 
			(
				ISNULL(@employers,'') <> ''
				AND UserId IN (SELECT val FROM F_SPLIT(@employers,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND ISNULL(CompanyName, '') <> ''
		AND IsActive=1  --- To exclude deleted user 06/12/2020 

	SELECT
		--YEAR(CreatedDate) AS PostedYear,
		JPD.FinancialYear AS PostedYear,  
		SUM(JPD.Quarter1) AS Q1,
		SUM(JPD.Quarter2) AS Q2,
		SUM(JPD.Quarter3) AS Q3,
		SUM(JPD.Quarter4) AS Q4
	
	FROM dbo.JobPostDetail JPD
		LEFT JOIN dbo.Users U
		ON JPD.CreatedBy = U.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

		LEFT JOIN dbo.JobRoleMapping JRM
		ON JPD.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle JT
		ON JRM.JobRoleId = JT.JobTitleId

	WHERE JPD.FinancialYear = @Year
	
		AND
			(
				@userRole = 0
				OR
				(
					@userRole = 1
					AND R.Id = @userRole
				)
				OR
				(
					@userRole > 2
					AND @userRole < 5
					AND R.Id > 2
					AND R.Id < 5
				)
			)
		AND JPD.UserId IN
			(
				SELECT
					UserId
				FROM dbo.Users
				WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
			)
		AND (
				(
				ISNULL(@jobRoles,'') = ''
				)
				OR
				(
					ISNULL(@jobRoles,'') <> ''
					AND
					JT.JobTitleId IN (SELECT val FROM dbo.f_split(@jobRoles, ','))
				)
			)
		AND 
		(
			(
				ISNULL(@states ,'') = ''
			)
			OR 
			(
				ISNULL(@states ,'') <> ''
				AND JPD.StateCode IN (SELECT val FROM F_SPLIT(@states,',') WHERE ISNULL(val,'') <> '')
			)
		)
	
	GROUP BY 
		FinancialYear
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDataOnState]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetDemandAggregationDashboardDataOnState]
(
	@states VARCHAR(MAX),
	@year INT,
	@userRole INT,
	@employers VARCHAR(MAX),
	@jobRoles VARCHAR(MAX)
)
AS
BEGIN

	SELECT 
		CompanyName INTO
		#TempCompanies
	FROM dbo.Users
	WHERE ( 
			(
				ISNULL(@employers,'') = ''	
			)
			OR 
			(
				ISNULL(@employers,'') <> ''
				AND UserId IN (SELECT val FROM F_SPLIT(@employers,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND ISNULL(CompanyName, '') <> ''
		AND IsActive=1  --- To exclude deleted user 06/12/2020 

	SELECT
		S.StateCode,
		S.Name AS StateName,
		JPD.FinancialYear AS PostedYear,
		SUM(JPD.Quarter1) AS Q1,
		SUM(JPD.Quarter2) AS Q2,
		SUM(JPD.Quarter3) AS Q3,
		SUM(JPD.Quarter4) AS Q4
	FROM dbo.JobPostDetail JPD
		INNER JOIN dbo.States S
		ON JPD.StateCode = S.StateCode

		LEFT JOIN dbo.Users U
		ON JPD.CreatedBy = U.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

		LEFT JOIN dbo.Users U2
		ON JPD.UserId = U2.UserId

		LEFT JOIN dbo.JobRoleMapping JRM
		ON JPD.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle JT
		ON JRM.JobRoleId = JT.JobTitleId

	WHERE (
			(
				ISNULL(@states ,'') = ''
			)
			OR 
			(
				ISNULL(@states ,'') <> ''
				AND JPD.StateCode IN (SELECT val FROM F_SPLIT(@states,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND JPD.FinancialYear = @year
		AND
			(
				@userRole = 0
				OR
				(
					@userRole = 1
					AND R.Id = @userRole
				)
				OR
				(
					@userRole > 2
					AND @userRole < 5
					AND R.Id > 2
					AND R.Id < 5
				)
			)
		AND JPD.UserId IN
			(
				SELECT
					UserId
				FROM dbo.Users
				WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
			)
		AND (
				(
				ISNULL(@jobRoles,'') = ''
				)
				OR
				(
					ISNULL(@jobRoles,'') <> ''
					AND
					JT.JobTitleId IN (SELECT val FROM dbo.f_split(@jobRoles, ','))
				)
			)

	GROUP BY 
		S.StateCode,
		S.Name,
		JPD.FinancialYear
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDetails]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetDemandAggregationDashboardDetails]
(
	@year INT,
	@userRole INT,
	@states VARCHAR(MAX),
	@employers VARCHAR(MAX),
	@jobRoles VARCHAR(MAX),
	@onBasis VARCHAR(50),
	@value VARCHAR(100)
)
AS
BEGIN

	SELECT 
		CompanyName INTO
		#TempCompanies
	FROM dbo.Users
	WHERE ( 
			(
				ISNULL(@employers,'') = ''	
			)
			OR 
			(
				ISNULL(@employers,'') <> ''
				AND UserId IN (SELECT val FROM F_SPLIT(@employers,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND ISNULL(CompanyName, '') <> ''
		AND IsActive=1  --- To exclude deleted user 06/12/2020 

	IF(@onBasis = 'DemandByJobRoles')
	BEGIN
		SELECT
			JPD.JobPostId,
			C.Name AS Country,
			S.Name AS [State],
			CT.Name AS City,
			JT.JobTitleName,
			U.FirstName AS CreatedByFirstName,
			U.LastName AS CreatedByLastName,
			UEMP.CompanyName,
			JPD.CreatedDate,
			JPD.FinancialYear,
			JPD.Quarter1,
			JPD.Quarter2,
			JPD.Quarter3,
			JPD.Quarter4
		FROM dbo.JobPostDetail JPD
			LEFT JOIN dbo.Countries C
			ON JPD.CountryCode = C.CountryCode
			LEFT JOIN dbo.States S
			ON JPD.StateCode = S.StateCode
			LEFT JOIN dbo.Cities CT
			ON JPD.CityCode = CT.CityCode
			LEFT JOIN dbo.Users U
			ON JPD.CreatedBy = U.UserId

			LEFT JOIN dbo.UserRoles UR
			ON U.UserId = UR.UserId
			LEFT JOIN dbo.Roles R
			ON UR.RoleId = R.Id

			LEFT JOIN dbo.Users UEMP
			ON JPD.UserId = UEMP.UserId
			LEFT JOIN dbo.JobRoleMapping JRM
			ON JPD.JobPostId = JRM.JobId
			INNER JOIN dbo.JobTitle JT
			ON JRM.JobRoleId = JT.JobTitleId
		WHERE JT.JobTitleName = @value
			AND JPD.FinancialYear = @year
			AND
				(
					@userRole = 0
					OR
					(
						@userRole = 1
						AND R.Id = @userRole
					)
					OR
					(
						@userRole > 2
						AND @userRole < 5
						AND R.Id > 2
						AND R.Id < 5
					)
				)
			AND 
			(
				(
				ISNULL(@jobRoles,'') = ''
				)
				OR
				(
					ISNULL(@jobRoles,'') <> ''
					AND
					JT.JobTitleId IN (SELECT val FROM dbo.f_split(@jobRoles, ','))
				)
			)
		AND 
		(
			(
				ISNULL(@states ,'') = ''
			)
			OR 
			(
				ISNULL(@states ,'') <> ''
				AND S.StateCode IN (SELECT val FROM F_SPLIT(@states,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND JPD.UserId IN
			(
				SELECT
					UserId
				FROM dbo.Users
				WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
			)

	ORDER BY
		JPD.CreatedDate DESC
		
	END

	ELSE IF(@onBasis = 'DemandByStates')
	BEGIN
		WITH CTE_DemandOnStates AS
		(
		SELECT
			JPD.JobPostId,
			C.Name AS Country,
			S.Name AS [State],
			CT.Name AS City,
			JT.JobTitleName,
			U.FirstName AS CreatedByFirstName,
			U.LastName AS CreatedByLastName,
			UEMP.CompanyName,
			JPD.CreatedDate,
			JPD.FinancialYear,
			JPD.Quarter1,
			JPD.Quarter2,
			JPD.Quarter3,
			JPD.Quarter4
		FROM dbo.JobPostDetail JPD
			LEFT JOIN dbo.Countries C
			ON JPD.CountryCode = C.CountryCode
			LEFT JOIN dbo.Cities CT
			ON JPD.CityCode = CT.CityCode
			LEFT JOIN dbo.Users U
			ON JPD.CreatedBy = U.UserId

			LEFT JOIN dbo.UserRoles UR
			ON U.UserId = UR.UserId
			LEFT JOIN dbo.Roles R
			ON UR.RoleId = R.Id

			LEFT JOIN dbo.Users UEMP
			ON JPD.UserId = UEMP.UserId
			LEFT JOIN dbo.JobRoleMapping JRM
			ON JPD.JobPostId = JRM.JobId
			LEFT JOIN dbo.JobTitle JT
			ON JRM.JobRoleId = JT.JobTitleId
			INNER JOIN dbo.States S
			ON JPD.StateCode = S.StateCode
		WHERE S.Name = @value
			AND JPD.FinancialYear = @year	
			AND
				(
					@userRole = 0
					OR
					(
						@userRole = 1
						AND R.Id = @userRole
					)
					OR
					(
						@userRole > 2
						AND @userRole < 5
						AND R.Id > 2
						AND R.Id < 5
					)
				)
			AND 
			(
				(
				ISNULL(@jobRoles,'') = ''
				)
				OR
				(
					ISNULL(@jobRoles,'') <> ''
					AND
					JT.JobTitleId IN (SELECT val FROM dbo.f_split(@jobRoles, ','))
				)
			)
		AND 
		(
			(
				ISNULL(@states ,'') = ''
			)
			OR 
			(
				ISNULL(@states ,'') <> ''
				AND S.StateCode IN (SELECT val FROM F_SPLIT(@states,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND JPD.UserId IN
			(
				SELECT
					UserId
				FROM dbo.Users
				WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
			)				
		)
		SELECT
			DISTINCT
			JobPostId,
			Country,
			[State],
			City,
			STUFF(
			(
				SELECT
					DISTINCT 
					', ' + JobTitleName
				FROM CTE_DemandOnStates CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobTitleName,
			CreatedByFirstName,
			CreatedByLastName,
			CompanyName,
			CreatedDate,
			FinancialYear,
			Quarter1,
			Quarter2,
			Quarter3,
			Quarter4
		FROM CTE_DemandOnStates CTE1
		ORDER BY
			CreatedDate DESC
	END

	ELSE IF(@onBasis = 'DemandByEmployers')
	BEGIN
		;WITH CTE_DemandByEmployers AS
		(	
		SELECT
			JPD.JobPostId,
			C.Name AS Country,
			S.Name AS [State],
			CT.Name AS City,
			JT.JobTitleName,
			U.FirstName AS CreatedByFirstName,
			U.LastName AS CreatedByLastName,
			UEMP.CompanyName,
			JPD.CreatedDate,
			JPD.FinancialYear,
			JPD.Quarter1,
			JPD.Quarter2,
			JPD.Quarter3,
			JPD.Quarter4
		FROM dbo.JobPostDetail JPD
			LEFT JOIN dbo.Countries C
			ON JPD.CountryCode = C.CountryCode
			LEFT JOIN dbo.Cities CT
			ON JPD.CityCode = CT.CityCode
			LEFT JOIN dbo.Users U
			ON JPD.CreatedBy = U.UserId

			LEFT JOIN dbo.UserRoles UR
			ON U.UserId = UR.UserId
			LEFT JOIN dbo.Roles R
			ON UR.RoleId = R.Id

			LEFT JOIN dbo.JobRoleMapping JRM
			ON JPD.JobPostId = JRM.JobId
			LEFT JOIN dbo.JobTitle JT
			ON JRM.JobRoleId = JT.JobTitleId
			LEFT JOIN dbo.States S
			ON JPD.StateCode = S.StateCode
			INNER JOIN dbo.Users UEMP
			ON JPD.UserId = UEMP.UserId
		WHERE UEMP.CompanyName = @value
			AND JPD.FinancialYear = @year
			AND
				(
					@userRole = 0
					OR
					(
						@userRole = 1
						AND R.Id = @userRole
					)
					OR
					(
						@userRole > 2
						AND @userRole < 5
						AND R.Id > 2
						AND R.Id < 5
					)
				)
			AND 
			(
				(
				ISNULL(@jobRoles,'') = ''
				)
				OR
				(
					ISNULL(@jobRoles,'') <> ''
					AND
					JT.JobTitleId IN (SELECT val FROM dbo.f_split(@jobRoles, ','))
				)
			)
		AND 
		(
			(
				ISNULL(@states ,'') = ''
			)
			OR 
			(
				ISNULL(@states ,'') <> ''
				AND S.StateCode IN (SELECT val FROM F_SPLIT(@states,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND JPD.UserId IN
			(
				SELECT
					UserId
				FROM dbo.Users
				WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
			)
			)
			SELECT
				DISTINCT
				JobPostId,
				Country,
				[State],
				City,
				STUFF(
					(
						SELECT
							DISTINCT 
							', ' + JobTitleName
						FROM CTE_DemandByEmployers CTE2
						WHERE CTE1.JobPostId = CTE2.JobPostId
						FOR XML PATH('')),1,2,''
					) AS JobTitleName,
				CreatedByFirstName,
				CreatedByLastName,
				CompanyName,
				CreatedDate,
				FinancialYear,
				Quarter1,
				Quarter2,
				Quarter3,
				Quarter4
			FROM CTE_DemandByEmployers CTE1
			ORDER BY
				CreatedDate DESC
	END

	ELSE IF(@onBasis = 'DemandByQuarter')
	BEGIN
		WITH CTE_DemandByQuarter AS
		(
			SELECT
				JPD.JobPostId,
				C.Name AS Country,
				S.Name AS [State],
				CT.Name AS City,
				JT.JobTitleName,
				U.FirstName AS CreatedByFirstName,
				U.LastName AS CreatedByLastName,
				UEMP.CompanyName,
				JPD.CreatedDate,
				JPD.FinancialYear,
				JPD.Quarter1,
				JPD.Quarter2,
				JPD.Quarter3,
				JPD.Quarter4
			FROM dbo.JobPostDetail JPD
				LEFT JOIN dbo.Countries C
				ON JPD.CountryCode = C.CountryCode
				LEFT JOIN dbo.States S
				ON JPD.StateCode = S.StateCode
				LEFT JOIN dbo.Cities CT
				ON JPD.CityCode = CT.CityCode
				LEFT JOIN dbo.Users U
				ON JPD.CreatedBy = U.UserId

				LEFT JOIN dbo.UserRoles UR
				ON U.UserId = UR.UserId
				LEFT JOIN dbo.Roles R
				ON UR.RoleId = R.Id

				LEFT JOIN dbo.Users UEMP
				ON JPD.UserId = UEMP.UserId
				LEFT JOIN dbo.JobRoleMapping JRM
				ON JPD.JobPostId = JRM.JobId
				LEFT JOIN dbo.JobTitle JT
				ON JRM.JobRoleId = JT.JobTitleId
			WHERE 0 < CASE
					WHEN @value = 'Q1' THEN JPD.Quarter1
					WHEN @value = 'Q2' THEN JPD.Quarter2
					WHEN @value = 'Q3' THEN JPD.Quarter3
					WHEN @value = 'Q4' THEN JPD.Quarter4
					ELSE 1
					END
				AND JPD.FinancialYear = @year
				AND
					(
						@userRole = 0
						OR
						(
							@userRole = 1
							AND R.Id = @userRole
						)
						OR
						(
							@userRole > 2
							AND @userRole < 5
							AND R.Id > 2
							AND R.Id < 5
						)
					)
			AND 
			(
				(
				ISNULL(@jobRoles,'') = ''
				)
				OR
				(
					ISNULL(@jobRoles,'') <> ''
					AND
					JT.JobTitleId IN (SELECT val FROM dbo.f_split(@jobRoles, ','))
				)
			)
		AND 
		(
			(
				ISNULL(@states ,'') = ''
			)
			OR 
			(
				ISNULL(@states ,'') <> ''
				AND S.StateCode IN (SELECT val FROM F_SPLIT(@states,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND JPD.UserId IN
			(
				SELECT
					UserId
				FROM dbo.Users
				WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
			)
		)
		SELECT
			DISTINCT
			JobPostId,
			Country,
			[State],
			City,
			STUFF(
				(
					SELECT
						DISTINCT
						', ' + JobTitleName
					FROM CTE_DemandByQuarter CTE2
					WHERE CTE1.JobPostId = CTE2.JobPostId
					FOR XML PATH('')),1,2,''
				) AS JobTitleName,
			CreatedByFirstName,
			CreatedByLastName,
			CompanyName,
			CreatedDate,
			FinancialYear,
			Quarter1,
			Quarter2,
			Quarter3,
			Quarter4
		FROM CTE_DemandByQuarter CTE1
		ORDER BY
			CreatedDate DESC
	END
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDataToExport]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetDemandAggregationDataToExport]
(  
	@year INT,
	@userRole INT,
	@states VARCHAR(MAX),
	@employers VARCHAR(MAX),
	@jobRoles VARCHAR(MAX) 
)  
AS  
BEGIN  

	SELECT 
		CompanyName INTO
		#TempCompanies
	FROM dbo.Users
	WHERE ( 
			(
				ISNULL(@employers,'') = ''	
			)
			OR 
			(
				ISNULL(@employers,'') <> ''
				AND UserId IN (SELECT val FROM F_SPLIT(@employers,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND ISNULL(CompanyName, '') <> ''

	SELECT
		U2.CompanyName AS CorporateName,  
		S.Name AS [State],  
		CT.Name AS City,  
		JPD.JobTitleByEmployer AS JobTitle,  
		JR.JobTitleName AS JobRole,  
		JPD.SKills,  
		JPD.HiringCriteria,  
		JPD.MinExperience,  
		JPD.MaxExperience,  
		JT.[Type] AS JobType,  
		JPD.JobDetails,  
		JPD.SPOC,  
		JPD.SPOCEmail,  
		JPD.SPOCContact,  
		JPD.CTC,  
		JPD.FinancialYear,  
		JPD.Quarter1 AS Q1,  
		JPD.Quarter2 AS Q2,  
		JPD.Quarter3 AS Q3,  
		JPD.Quarter4 AS Q4,  
		(JPD.Quarter1 + JPD.Quarter2 + JPD.Quarter3 + JPD.Quarter4) AS Total,  
		(ISNULL(U1.FirstName,'') + ' ' + ISNULL(U1.LastName,'')) AS PostedBy  
	FROM dbo.JobPostDetail JPD  
		LEFT JOIN dbo.JobIndustryArea JIA  
		ON JPD.JobIndustryAreaId = JIA.JobIndustryAreaId  
		LEFT JOIN dbo.Countries C  
		ON JPD.CountryCode = C.CountryCode
 
		LEFT JOIN dbo.States S  
		ON JPD.StateCode = S.StateCode  
		LEFT JOIN dbo.Cities CT  
		ON JPD.CityCode = CT.CityCode  
		LEFT JOIN dbo.EmploymentType ET  
		ON JPD.EmploymentTypeId = ET.EmploymentTypeId  
		LEFT JOIN dbo.Users U1  
		ON JPD.CreatedBy = U1.UserId  
		Left JOIN dbo.UserRoles UR  
		ON U1.UserId = UR.UserId  
		LEFT JOIN dbo.Roles R  
		ON UR.RoleId = R.Id  
		LEFT JOIN dbo.JobTypes JT  
		ON JPD.JobType = JT.Id  
		LEFT JOIN dbo.Users U2  
		ON JPD.UserId = U2.UserId  
		LEFT JOIN dbo.JobRoleMapping JRM  
		ON JPD.JobPostId = JRM.JobId  
		LEFT JOIN dbo.JobTitle JR  
		ON JRM.JobRoleId = JR.JobTitleId  
	WHERE JPD.FinancialYear = @year  
		AND  
		(  
			@userRole = 0  
			OR  
			(  
				@userRole = 1  
				AND R.Id = @userRole  
			)  
			OR  
			(  
				@userRole > 2  
				AND @userRole < 5  
				AND R.Id > 2  
				AND R.Id < 5  
			)  
		) 
		AND 
			(
				(
				ISNULL(@jobRoles,'') = ''
				)
				OR
				(
					ISNULL(@jobRoles,'') <> ''
					AND
					JR.JobTitleId IN (SELECT val FROM dbo.f_split(@jobRoles, ','))
				)
			)
		AND 
		(
			(
				ISNULL(@states ,'') = ''
			)
			OR 
			(
				ISNULL(@states ,'') <> ''
				AND S.StateCode IN (SELECT val FROM F_SPLIT(@states,',') WHERE ISNULL(val,'') <> '')
			)
		)
		AND JPD.UserId IN
			(
				SELECT
					UserId
				FROM dbo.Users
				WHERE CompanyName IN (SELECT CompanyName FROM #TempCompanies)
			) 
  
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetDesignationList]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetDesignationList]
AS
BEGIN
	SELECT
		Designationid,
		Designation,
		Abbr
	FROM Designations where IsActive = 1

END







GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerDashboardSummary]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetEmployerDashboardSummary]
(
	@EmpId INT
)
AS
BEGIN
	EXEC usp_GetTotalProfileViewed @EmpId
	EXEC usp_GetTotalApplicationsForAllJobs @EmpId
	EXEC usp_GetMessagesCount @ToId = @EmpId
	EXEC usp_GetAverageResponseTime @EmpId = @EmpId
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerDetailFromJobId]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetEmployerDetailFromJobId]
(
	@jobId INT
)
AS
BEGIN
	SELECT
		U.UserId,
		U.FirstName,
		U.LastName,
		U.Email,
		U.CompanyName,
		JPD.JobTitleByEmployer,
		JT.JobTitleName,
		JPD.JobDetails,
		U.MobileNo,
		JPD.CreatedDate
	FROM dbo.Users U
		INNER JOIN dbo.UserRoles UR
		ON U.UserId = UR.UserId
		INNER JOIN dbo.Roles R
		ON UR.RoleId = R.Id
		INNER JOIN dbo.JobPostDetail JPD
		ON U.UserId = JPD.UserId
		INNER JOIN dbo.JobRoleMapping JRM
		ON JPD.JobPostId = JRM.JobId
		INNER JOIN dbo.JobTitle JT
		ON JRM.JobRoleId = JT.JobTitleId
	WHERE JPD.JobPostId = @jobId
		AND U.IsActive = 1
		AND R.ID = 3
END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerDetails]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetEmployerDetails]
(
	@EmpId INT
)
AS
BEGIN
	WITH CTE_EmployerDetail
	(
			UserId,
			FirstName,
			Lastname,
			MobileNo,
			Email,
			Address1,
			Address2,
			Address3,
			City,
			[State],
			Country,
			MaritalStatus,
			ProfilePic,
			ActiveFrom,
			Gender,
			CompanyName,
			HiringCriteria
	)
	AS
	(
		SELECT
			U.UserId,
			U.FirstName,
			U.Lastname,
			U.MobileNo,
			U.Email,
			U.Address1,
			U.Address2,
			U.Address3,
			C.Name AS City,
			S.Name AS [State],
			CN.Name AS Country,
			MS.Status AS MaritalStatus,
			U.ProfilePic,
			U.CreatedOn AS ActiveFrom,
			G.Gender,
			U.CompanyName,
			JPD.HiringCriteria
		FROM dbo.Users U
			LEFT JOIN dbo.Cities C
			ON U.City = C.CityCode
			LEFT JOIN dbo.States S
			ON U.State = S.StateCode
			LEFT JOIN dbo.Countries CN
			ON U.Country = CN.CountryCode
			LEFT JOIN dbo.MaritalStatus MS
			ON U.MaritalStatus = MS.StatusCode
			LEFT JOIN dbo.Gender G
			ON U.Gender = G.GenderCode
			LEFT JOIN dbo.JobPostDetail JPD
			ON U.UserId = JPD.UserId
		WHERE U.UserId = @EmpId
	)
		SELECT
			CTE2.UserId,
			CTE2.FirstName,
			CTE2.Lastname,
			CTE2.MobileNo,
			CTE2.Email,
			CTE2.Address1,
			CTE2.Address2,
			CTE2.Address3,
			CTE2.City,
			CTE2.[State],
			CTE2.Country,
			CTE2.MaritalStatus,
			CTE2.ProfilePic,
			CTE2.ActiveFrom,
			CTE2.Gender,
			CTE2.CompanyName,
			STUFF
				((
					SELECT DISTINCT ', ' + CAST(CTE1.HiringCriteria AS VARCHAR(MAX))
					FROM CTE_EmployerDetail CTE1
					WHERE CTE1.UserId = CTE2.UserId
					FOR XML PATH('')
				),1,1,'') AS HiringFor
		FROM CTE_EmployerDetail CTE2
		GROUP BY
			CTE2.UserId,
			CTE2.FirstName,
			CTE2.Lastname,
			CTE2.MobileNo,
			CTE2.Email,
			CTE2.Address1,
			CTE2.Address2,
			CTE2.Address3,
			CTE2.City,
			CTE2.[State],
			CTE2.Country,
			CTE2.MaritalStatus,
			CTE2.ProfilePic,
			CTE2.ActiveFrom,
			CTE2.Gender,
			CTE2.CompanyName
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerFollowingByJobseeker]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			12/08/2020			CREATED - Getting data of employer following by job seeker
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetEmployerFollowingByJobseeker]
  (
	@UserId Int
  )
  AS
  BEGIN
	  SELECT 
	  EMF.CreatedDate,
	  U.CompanyName,
	  EMF.EmployerID
	 FROM [dbo].[EmployerFollower] AS EMF
	  INNER JOIN
	  Users AS U
	  ON EMF.[EmployerID] = U.UserId
	  WHERE EMF.[JobSeekerID] = 1586
	  AND EMF.IsActive=1
  END

  ----------------6---------------------


GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerJobDetail]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--sp_helptext usp_GetEmployerJobDetail

CREATE PROC [dbo].[usp_GetEmployerJobDetail]
(
	@JobId INT
)
AS
BEGIN
	WITH CTE_JobDetails AS
	(
		SELECT
			JPD.JobPostId,
			U.CompanyName,
			JT.JobTitleId AS JobRoleId,
			JT.JobTitleName AS JobRole,
			C.CountryCode,
			C.Name AS Country,
			S.StateCode,
			S.Name AS [State],
			CT.CityCode,
			CT.Name AS City,
			JPD.SPOC,
			JPD.SPOCEmail,
			JPD.SPOCContact,
			JPD.MonthlySalary,
			JPD.NoPosition,
			JPD.PositionStartDate AS PostingDate,
			JPD.PositionEndDate AS ExpiryDate,
			JPD.CTC,
			JPD.HiringCriteria,
			JTT.Id AS JobType,
			JTT.[Type] AS JobTypeSummary,
			JPD.JobDetails,
			JPD.Quarter1,
			JPD.Quarter2,
			JPD.Quarter3,
			JPD.Quarter4,
			JPD.CreatedDate,
			JPD.Featured,
			JPD.FeaturedJobDisplayOrder,
			JPD.JobTitleByEmployer,			
			JPD.FinancialYear	
	FROM dbo.JobPostDetail JPD
			LEFT JOIN dbo.Users U
			ON JPD.UserId = U.UserId
			LEFT JOIN dbo.JobRoleMapping JRM
			ON JPD.JobPostId = JRM.JobId
			LEFT JOIN dbo.JobTitle JT
			ON JRM.JobRoleId = JT.JobTitleId
			LEFT JOIN dbo.Countries C
			ON JPD.CountryCode = C.CountryCode
			LEFT JOIN dbo.States S
			ON JPD.StateCode = S.StateCode
			LEFT JOIN dbo.Cities CT
			ON JPD.CityCode = CT.CityCode
			LEFT JOIN dbo.JobTypes JTT
			ON JPD.JobType = JTT.Id
		WHERE JPD.JobPostId = @JobId
	)

	SELECT DISTINCT
		JobPostId,
		CompanyName,
		STUFF(
			(
				SELECT 
					', ' + CAST(JobRoleId AS VARCHAR(100))
				FROM CTE_JobDetails CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobRoleId,
		STUFF(
			(
				SELECT ', ' + JobRole
				FROM CTE_JobDetails CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobRole,
		CountryCode,
		Country,
		StateCode,
		[State],
		CityCode,
		City,
		SPOC,
		SPOCEmail,
		SPOCContact,
		MonthlySalary,
		NoPosition,
		CTC,
		PostingDate,
		ExpiryDate,
		HiringCriteria,
		JobType,
		JobTypeSummary,
		JobDetails,
		Quarter1,
		Quarter2,
		Quarter3,
		Quarter4,
		CreatedDate,
		Featured,
		FeaturedJobDisplayOrder,
		JobTitleByEmployer,
		FinancialYear
	FROM CTE_JobDetails CTE1
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerJobDetails]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetEmployerJobDetails]  
(  
 @EmpId INT = 0,  
 @JobId INT = 0,  
 @year INT  
)  
AS  
BEGIN  
 SELECT  
  JPD.JobPostId,  
  C.Name AS Country,  
  S.Name AS [State],  
  CT.Name AS City,  
  JPD.HiringCriteria,  
  JTT.Id AS JobType,  
  JTT.[Type] AS JobTypeSummary,  
  JPD.JobDetails,  
  JPD.CTC,  
  JPD.Featured,  
  JPD.FeaturedJobDisplayOrder,  
  JPD.CreatedDate AS PostedOn,  
-- dbo.UTC2Indian(JPD.CreatedDate) AS PostedOn,
  JPD.Quarter1,  
  JPD.Quarter2,  
  JPD.Quarter3,  
  JPD.Quarter4,  
  JPD.JobTitleByEmployer,  
  COUNT(AJ.UserId) AS TotalApplications    
 FROM dbo.JobPostDetail JPD  
  LEFT JOIN dbo.Countries C  
  ON JPD.CountryCode = C.CountryCode  
  LEFT JOIN dbo.States S  
  ON JPD.StateCode = S.StateCode  
  LEFT JOIN dbo.Cities CT  
  ON JPD.CityCode = CT.CityCode  
  LEFT JOIN dbo.JobRoleMapping JRM  
  ON JPD.JobPostId = JRM.JobId  
  LEFT JOIN dbo.JobTitle JT  
  ON JRM.JobRoleId = JT.JobTitleId  
  LEFT JOIN dbo.AppliedJobs AJ  
  ON JPD.JobPostId = AJ.JobPostId  
  LEFT JOIN dbo.JobTypes JTT  
  ON JPD.JobType = JTT.Id  

  LEFT JOIN dbo.Users U
  ON JPD.CreatedBy = U.UserId
  LEFT JOIN dbo.UserRoles UR
  ON U.UserId = UR.UserId
  LEFT JOIN dbo.Roles R
  ON UR.RoleId = R.ID

 WHERE JPD.FinancialYear = @year  -- AND ISNULL(JPD.CreatedBy,'')<>1
  AND (  
    (  
     ISNULL(@EmpId,0) = 0
	 AND 	R.ID IN (3,4)
	  
    )  
    OR  
    (  
     ISNULL(@EmpId,0) <> 0
	 AND R.ID IN (3,4)
     AND JPD.UserId = @EmpId      
    )  
  )  
  AND (  
    (  
     ISNULL(@JobId,0) = 0  
    )  
    OR  
    (  
     ISNULL(@JobId,0) <> 0  
     AND JPD.JobPostId = @JobId      
    )  
   ) 
 AND U.IsActive =1  --- To exclude deleted user 06/12/2020 
 GROUP BY  
  JPD.JobPostId,  
  C.Name,  
  S.Name,  
  CT.Name,  
  JPD.HiringCriteria,  
  JTT.Id,  
  JTT.[Type],  
  JPD.JobDetails,  
  JPD.CTC,  
  JPD.CreatedDate,  
  JPD.Quarter1,  
  JPD.Quarter2,  
  JPD.Quarter3,  
  JPD.Quarter4,  
  JPD.JobTitleByEmployer,  
  JPD.Featured,  
  FeaturedJobDisplayOrder  
Order By JPD.CreatedDate DESC
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployers]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetEmployers]   
(  
 @EmpId INT = NULL,  
 @IsAll BIT  = 0
)  
AS  
BEGIN  
 SELECT  
  U.Userid,  
  U.FirstName,  
  U.LastName,  
  U.CompanyName,   
  C.Name AS City,  
  U.Gender,  
  U.MaritalStatus,  
  U.ContactPerson,  
  U.Email,    
  U.[Address1],  
  U.ProfilePic,  
  U.MobileNo,  
  U.ProfilePic AS CompanyLogo     
 FROM dbo.Users U  
  LEFT JOIN dbo.Cities C  
  ON U.City = C.CityCode  
  INNER JOIN UserRoles UR  
  ON U.Userid = UR.Userid  
  INNER JOIN Roles R   
  ON UR.RoleId = R.ID  
 WHERE R.ID = 3  
  AND U.IsActive=1  
  AND(  
   (  
    @IsAll = 1  
   )  
   OR  
   (  
    @IsAll = 0  
    AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0  
   )  
  )  
  AND (  
    ISNULL(@EmpId,'') = ''  
   )  
  OR  
   (  
    ISNULL(@EmpId,'') <> ''  
    AND U.UserId = @EmpId  
   )    
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmploymentStatus]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetEmploymentStatus]
AS 
BEGIN
	SELECT 
		EmploymentStatusId,
		EmploymentStatusName
	FROM [dbo].[EmploymentStatus]
	WHERE [Status]=1
END







GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmploymentType]    Script Date: 8/28/2020 10:24:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetEmploymentType]
AS 
BEGIN
	SELECT 
		EmploymentTypeId,
		EmploymentTypeName
	FROM [dbo].[EmploymentType]
	WHERE [Status]=1
END







GO
/****** Object:  StoredProcedure [dbo].[usp_GetFeaturedJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			16/01/2020			Created - Getting Featured Jobs
2			SK			14/02/2020          Add Top 4 Freatured 
3           sk          19/03/2020		    Only Employer Featured Jobs
4           sk          10/08/2020		    JobDetails and CTC added         
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetFeaturedJobs]
AS
BEGIN
WITH CTE_GetFeeaturedJobs AS
	(
	SELECT  TOP 4    
		JP.JobPostId,
		JP.JobTitleByEmployer,
		JP.FeaturedJobDisplayOrder,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.[CompanyName] AS CompanyName,
		JP.JobDetails AS JobDetails,
		JP.CTC AS CTC,
		DATEDIFF(DAY, JP.UpdatedDate, GETDATE()) AS NumberOfDays
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId

		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

	WHERE JP.Featured = 1 AND JP.FeaturedJobDisplayOrder<=20 AND ISNULL(R.ID,0) !=1
	AND U.IsActive=1   --- To exclude deleted user 06/12/2020
	)
	SELECT
		DISTINCT
		JobPostId,
		STUFF(
		(
			SELECT 
				', ' + JobTitle
			FROM CTE_GetFeeaturedJobs CTE2
			WHERE CTE1.JobPostId = CTE2.JobPostId
			FOR XML PATH('')),1,2,''
		) AS JobTitle,
		JobTitleByEmployer,
		EmploymentStatus,
		City,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		FeaturedJobDisplayOrder,
		JobDetails,
		CTC,
		NumberOfDays
	FROM CTE_GetFeeaturedJobs CTE1
END


---------------3-------------------


GO
/****** Object:  StoredProcedure [dbo].[usp_GetGenderMaster]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetGenderMaster]
(
	@IsAll BIT = 0
)
AS
BEGIN
	IF(@IsAll = 0)
	BEGIN
		SELECT
			GenderId,
			GenderCode,
			Gender
		FROM dbo.Gender
		WHERE IsActive = 1
		AND GenderCode <> 'all'
	END
	ELSE
	BEGIN
		SELECT
			GenderId,
			GenderCode,
			Gender
		FROM dbo.Gender
		WHERE IsActive = 1
	END
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetIdForValue]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROC [dbo].[usp_GetIdForValue]
(
	@value VARCHAR (MAX),
	@valueFor VARCHAR(MAX)
)
AS
BEGIN
	IF(@valueFor = 'JobIndustryAreaId')
	BEGIN
		SELECT 
			JobIndustryAreaId AS ID 
		FROM dbo.JobIndustryArea 
		WHERE JobIndustryAreaName = @value;
	END
	ELSE IF(@valueFor = 'CountryCode')
	BEGIN
		SELECT 
			CountryCode AS ID
		FROM dbo.Countries 
		WHERE Name = @value;
	END
	ELSE IF(@valueFor = 'StateCode')
	BEGIN
		SELECT 
			StateCode AS ID 
		FROM dbo.States 
		WHERE Name = @value;		
	END
	ELSE IF(@valueFor = 'CityCode')
	BEGIN
		SELECT 
			CityCode AS ID 
		FROM dbo.Cities 
		WHERE Name = @value;
	END
		ELSE IF(@valueFor = 'EmploymentStatusId')
	BEGIN
		SELECT 
			EmploymentStatusId AS ID 
		FROM dbo.EmploymentStatus 
		WHERE EmploymentStatusName = @value;
	END
	ELSE IF(@valueFor = 'JobTitleId')
	BEGIN
		IF EXISTS(SELECT JobTitleId AS ID FROM dbo.JobTitle WHERE JobTitleName = @value)
		BEGIN
			SELECT JobTitleId AS ID FROM dbo.JobTitle WHERE JobTitleName = @value			
		END
		ELSE
		BEGIN			
			INSERT INTO dbo.JobTitle
			(
				JobTitleName,
				[Status],
				CreatedBy,
				CreatedDate
			)
			VALUES
			(
				@value,
				1,
				'BulkJobPost',
				GETDATE()
			)			
			SELECT JobTitleId AS ID FROM dbo.JobTitle WHERE JobTitleName=@value
		END	
	END
	ELSE IF(@valueFor = 'EmploymentTypeId')
	BEGIN
		SELECT 
			EmploymentTypeId AS ID 
		FROM dbo.EmploymentType 
		WHERE EmploymentTypeName = @value;
	END
	ELSE IF(@valueFor = 'CompanyName')
	BEGIN
		SELECT 
			UserId AS ID 
		FROM dbo.Users 
		WHERE CompanyName = @value;
	END
	ELSE IF(@valueFor = 'JobType')
	BEGIN
		SELECT 
			Id
		FROM dbo.JobTypes 
		WHERE [Type] = @value;
	END
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetIndustryArea]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetIndustryArea]  
AS   
BEGIN  
 SELECT   
  JobIndustryAreaId,  
  JobIndustryAreaName  
 FROM [dbo].[JobIndustryArea]  
 WHERE [Status]=1  Order by JobIndustryAreaName asc
END  
  
  
  
  



GO
/****** Object:  StoredProcedure [dbo].[usp_GetJoBDetail]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJoBDetail] 
(  
 @jobid int  
)  
AS  
BEGIN  
 WITH CTE_GetJobDetails AS  
 (  
  SELECT JOB.[JobPostId]  
   ,JOB.[JobIndustryAreaId]  
   ,JOB.[CountryCode]  
   ,JOB.[StateCode]  
   ,JOB.[CityCode]  
   ,JOB.[EmploymentStatusId]  
   ,JT.[JobTitleId]  
   ,JOB.[EmploymentTypeId]  
   ,JOB.[MonthlySalary]  
   ,JOB.[NoPosition]  
   ,JOB.[Nationality]  
   ,CAST(CAST(JOB.[PositionStartDate] AS DATE) AS VARCHAR(50)) AS PositionStartDate
   ,CAST(CAST(JOB.[PositionEndDate] AS DATE) AS VARCHAR(50)) AS PositionEndDate
   ,JOB.[HiringCriteria]  
   ,JOB.[Status]  
   ,JOB.[CTC]
   ,JOB.[Quarter1]
   ,JOB.[Quarter2]
   ,JOB.[Quarter3]
   ,JOB.[Quarter4]
   ,JOB.[CreatedBy]  
   ,JOB.[CreatedDate]  
   ,JOB.[UpdatedBy]  
   ,JOB.[UpdatedDate]  
   ,JTT.Id AS JobType  
   ,JTT.Type AS JobTypeSummary  
   ,JOB.[Gender]  
   ,JOB.[JobDetails]  
   ,Country.[Name] AS Country  
   ,States.[Name] AS StateName  
   ,Cities.[Name] AS City  
   ,JobIndustryArea.[JobIndustryAreaName]  
   ,EmploymentStatus.[EmploymentStatusName]  
   ,'' AS EmploymentTypeName --EmploymentType.[EmploymentTypeName]  
   ,JT.[JobTitleName]  
   ,Users.[ProfilePic] AS CompanyLogo  
   ,Users.[CompanyName] AS CompanyName  
   ,JOB.JobTitleByEmployer  
  FROM JobPostDetail AS JOB   
   INNER JOIN Users ON JOB.[Userid] = Users.[UserId]  
   LEFT JOIN dbo.JobRoleMapping JRM  
   ON JOB.JobPostId = JRM.JobId  
   LEFT JOIN JobTitle JT   
   ON JRM.JobRoleId = JT.JobTitleId  
   LEFT JOIN dbo.JobTypes JTT  
   ON JOB.JobType = JTT.Id  
   LEFT JOIN Countries AS Country ON JOB.[CountryCode] = Country.[CountryCode]  
   LEFT JOIN States ON JOB.[StateCode] = States.[StateCode]  
   LEFT JOIN Cities ON JOB.[CityCode] = Cities.[CityCode]  
   LEFT JOIN JobIndustryArea ON JOB.[JobIndustryAreaId] = JobIndustryArea.[JobIndustryAreaId]  
   LEFT JOIN EmploymentStatus ON JOB.[EmploymentStatusId] = EmploymentStatus.[EmploymentStatusId]  
  WHERE JobPostId = @jobid   
 )  
  
 SELECT  
  DISTINCT   
   JobPostId,  
   JobIndustryAreaId,  
   CountryCode,  
   StateCode,  
   CityCode,  
   CTC,  
   Quarter1,
   Quarter2,
   Quarter3,
   Quarter4,
   EmploymentStatusId,  
   STUFF(  
   (  
    SELECT   
     ', ' + CAST(JobTitleId AS VARCHAR(100))  
    FROM CTE_GetJobDetails CTE2  
    WHERE CTE1.JobPostId = CTE2.JobPostId  
    FOR XML PATH('')),1,2,''  
   ) AS JobTitleId,  
   EmploymentTypeId,  
   MonthlySalary,  
   NoPosition,  
   Nationality,  
   PositionStartDate,  
   PositionEndDate,  
   HiringCriteria,  
   [Status],  
   CreatedBy,  
   CreatedDate,  
   UpdatedBy,  
   UpdatedDate,  
   JobType,  
   JobTypeSummary,  
   Gender,  
   JobDetails,  
   Country,  
   StateName,  
   City,  
   JobIndustryAreaName,  
   EmploymentStatusName,  
   EmploymentTypeName,  
   STUFF(  
   (  
    SELECT   
     ', ' + JobTitleName  
    FROM CTE_GetJobDetails CTE2  
    WHERE CTE1.JobPostId = CTE2.JobPostId  
    FOR XML PATH('')),1,2,''  
   ) AS JobTitleName,  
   CompanyLogo,  
   CompanyName,  
   JobTitleByEmployer  
 FROM CTE_GetJobDetails CTE1  
END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobIndustryAreaWithPostData]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[usp_GetJobIndustryAreaWithPostData]
AS
BEGIN
SELECT
JA.JobIndustryAreaId,
JA.JobIndustryAreaName,
COUNT(JP.JobPostId) As CountValue
FROM dbo.JobIndustryArea AS JA
LEFT JOIN [dbo].[JobPostDetail] AS JP
ON JA.JobIndustryAreaId = JP.JobIndustryAreaId
LEFT JOIN dbo.Users U
ON JP.CreatedBy = U.UserId
LEFT JOIN dbo.UserRoles UR
ON U.UserId = UR.UserId
LEFT JOIN dbo.Roles R
ON UR.RoleId = R.ID
WHERE JA.Status = 1
AND CAST(JP.PositionEndDate AS DATE) >= CAST(GETDATE() AS DATE)
AND R.ID IN (3,4)
GROUP BY
JA.JobIndustryAreaId,
JA.JobIndustryAreaName
ORDER BY
CountValue DESC

--SELECT
--COUNT(JP.JobIndustryAreaId) As CountValue,
--JP.JobIndustryAreaId,
--JA.JobIndustryAreaName
--FROM [dbo].[JobPostDetail] AS JP
--INNER JOIN JobIndustryArea AS JA ON
--JP.JobIndustryAreaId = JA.JobIndustryAreaId
--GROUP BY JP.JobIndustryAreaId, JA.JobIndustryAreaName,JA.[Status]
--HAVING JA.[Status]!=0
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobIndustryAreaWithStudentData]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobIndustryAreaWithStudentData]   
AS  
BEGIN  
	SELECT
		JA.JobIndustryAreaId,
		JA.JobIndustryAreaName,
		COUNT(U.UserId) AS CountValue
	FROM dbo.JobIndustryArea JA
		LEFT JOIN dbo.UserProfessionalDetails UPD
		ON JA.JobIndustryAreaId = UPD.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON UPD.UserId = U.UserId
		 AND U.IsActive = 1
	WHERE JA.Status = 1
	GROUP BY
		JA.JobIndustryAreaId,
		JA.JobIndustryAreaName
	ORDER BY
		CountValue DESC
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobListByCategory]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetJobListByCategory] 
(
	@Id int
)
AS
BEGIN
	WITH CTE_JobsOnIndustryArea AS
	(
	SELECT  
		JP.JobPostId,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.[CompanyName] AS CompanyName,
		JP.CTC,
		DATEDIFF(DAY, JP.CreatedDate, GETDATE()) AS NumberOfDays
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JRM.JobId = JP.JobPostId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId

		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

		INNER JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
	WHERE JA.JobIndustryAreaId = @Id 
		AND JP.[Status] = 1
		AND ISNULL(JP.SPOCEmail,'') <> ''
		AND R.Id != 1
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020
	)
	SELECT
		DISTINCT
		JobPostId,
		STUFF(
			(
				SELECT 
					', ' + JobTitle
				FROM CTE_JobsOnIndustryArea CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobTitle,
		EmploymentStatus,
		City,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		CTC,
		NumberOfDays
	FROM CTE_JobsOnIndustryArea CTE1
END


---------------6---------------------------

GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobListByCity]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetJobListByCity] 
(
@CityCode Varchar(MAX)
)
AS
BEGIN
	WITH CTE_JobsByCity AS
	(
	SELECT  
		JP.JobPostId,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.[CompanyName] AS CompanyName,
		JP.CTC,
		DATEDIFF(DAY, JP.CreatedDate, GETDATE()) AS NumberOfDays
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId

		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

		INNER JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
	WHERE C.CityCode = @CityCode 
		AND JP.[Status] = 1
		AND ISNULL(JP.SPOCEmail,'') <> ''
		AND R.Id != 1
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020
	)
	SELECT
		DISTINCT
		JobPostId,
		STUFF(
			(
				SELECT 
					', ' + JobTitle
				FROM CTE_JobsByCity CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobTitle,
		EmploymentStatus,
		City,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		CTC,
		NumberOfDays
	FROM CTE_JobsByCity CTE1
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobListByCompany]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetJobListByCompany]
(
@UserId INT
)
AS
BEGIN
	WITH CTE_JobsByCity AS
	(
	SELECT  
		JP.JobPostId,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.[CompanyName] AS CompanyName,
		JP.CTC
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId

		INNER JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
	WHERE U2.UserId = @UserId 
		AND JP.[Status] = 1
		AND ISNULL(JP.SPOCEmail,'') <> ''
		AND R.Id != 1
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020
	)
	SELECT
		DISTINCT
		JobPostId,
		STUFF(
			(
				SELECT 
					', ' + JobTitle
				FROM CTE_JobsByCity CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobTitle,
		EmploymentStatus,
		City,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		CTC
	FROM CTE_JobsByCity CTE1
END


--------------------5--------------------------

GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobListWithFirstChar]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetJobListWithFirstChar]
(
	@jobFirstChar VARCHAR(50)
)
AS 
BEGIN
	SELECT
		JobTitleName,
		JobTitleId 
	FROM dbo.JobTitle 
	WHERE JobTitleName LIKE  @jobFirstChar +'%'
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobPostMonthlyStateWise]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobPostMonthlyStateWise]
(
	@Month VARCHAR(MAX),
	@Year VARCHAR(MAX),
	@State VARCHAR(MAX)
)
AS
BEGIN
	IF(@State = 'All')
	BEGIN
		WITH CTE_GetJobsOnAllState AS
		(
		SELECT
			JP.JobPostId 
			,U.[Userid]
			,U.[Email]
			,U.[MobileNo]
			,U.[ContactPerson]
			,City.[Name] AS City
			,States.[Name] AS [State]
			,Country.Name AS Country
			,JT.JobTitleName
			,JA.[JobIndustryAreaName]
			,ES.EmploymentStatusName
			,JP.[Gender]
			,JP.[NoPosition]
		FROM dbo.JobPostDetail AS JP
			LEFT JOIN dbo.Users AS U
			ON U.[Userid]=JP.[Userid]
			LEFT JOIN dbo.JobIndustryArea AS JA
			ON JP.JobIndustryAreaId = JA.JobIndustryAreaId
			LEFT JOIN dbo.JobRoleMapping JRM
			ON JP.JobPostId = JRM.JobId
			LEFT JOIN dbo.JobTitle AS JT
			ON JRM.JobRoleId = JT.JobTitleId
			LEFT JOIN dbo.Countries AS Country
			ON JP.CountryCode = Country.CountryCode
			LEFT JOIN dbo.Cities AS City
			ON JP.CityCode = City.CityCode
			LEFT JOIN dbo.EmploymentStatus AS ES
			ON JP.EmploymentStatusId = ES.EmploymentStatusId
			INNER JOIN dbo.States AS States
			ON JP.StateCode = States.StateCode

			LEFT JOIN dbo.Users U2
			ON JP.CreatedBy = U2.UserId
			LEFT JOIN dbo.UserRoles UR
			ON U2.UserId = UR.UserId
			LEFT JOIN dbo.Roles R
			ON UR.RoleId = R.Id

		WHERE MONTH(JP.CreatedDate) = @Month
			AND U.IsActive = 1
			AND Year(JP.CreatedDate) = @Year
			AND ISNULL(R.ID,0) !=1
		)	
		SELECT
			DISTINCT
			JobPostId 
			,[Userid]
			,[Email]
			,[MobileNo]
			,[ContactPerson]
			,City
			,[State]
			,Country
			,STUFF(
			(
				SELECT 
					', ' + JobTitleName
				FROM CTE_GetJobsOnAllState CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobTitleName
			,[JobIndustryAreaName]
			,EmploymentStatusName
			,[Gender]
			,[NoPosition]	
		FROM CTE_GetJobsOnAllState CTE1
	END
	ELSE
	BEGIN
		WITH CTE_GetJobsOnStateBasis AS
		(
		SELECT 
			 JP.JobPostId,
			 U.[Userid]
			,U.[Email]
			,U.[MobileNo]
			,U.[ContactPerson]
			,City.[Name] AS City
			,States.[Name] AS [State]
			,Country.Name AS Country
			,JT.JobTitleName
			,JA.[JobIndustryAreaName]
			,ES.EmploymentStatusName
			,JP.[Gender]
			,JP.[NoPosition]
		FROM dbo.JobPostDetail AS JP
			LEFT JOIN dbo.Users AS U
			ON U.[Userid]=JP.[Userid]
			LEFT JOIN dbo.JobIndustryArea AS JA
			ON JP.JobIndustryAreaId = JA.JobIndustryAreaId
			LEFT JOIN dbo.JobRoleMapping JRM
			ON JP.JobPostId = JRM.JobId
			LEFT JOIN dbo.JobTitle AS JT
			ON JRM.JobRoleId = JT.JobTitleId
			LEFT JOIN dbo.Countries AS Country
			ON JP.CountryCode = Country.CountryCode
			LEFT JOIN dbo.Cities AS City
			ON JP.CityCode = City.CityCode
			LEFT JOIN dbo.EmploymentStatus AS ES
			ON JP.EmploymentStatusId = ES.EmploymentStatusId
			INNER JOIN dbo.States AS States
			ON JP.StateCode = States.StateCode

			LEFT JOIN dbo.Users U2
			ON JP.CreatedBy = U2.UserId
			LEFT JOIN dbo.UserRoles UR
			ON U2.UserId = UR.UserId
			LEFT JOIN dbo.Roles R
			ON UR.RoleId = R.Id

		WHERE MONTH(JP.CreatedDate) = @Month
			AND U.IsActive=1
			AND Year(JP.CreatedDate) = @Year
			AND States.StateCode = @State
			AND ISNULL(R.ID,0) !=1
		)
		SELECT
			DISTINCT
			JobPostId 
			,[Userid]
			,[Email]
			,[MobileNo]
			,[ContactPerson]
			,City
			,[State]
			,Country
			,STUFF(
			(
				SELECT 
					', ' + JobTitleName
				FROM CTE_GetJobsOnStateBasis CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobTitleName
			,[JobIndustryAreaName]
			,EmploymentStatusName
			,[Gender]
			,[NoPosition]	
		FROM CTE_GetJobsOnStateBasis CTE1
	END	
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobRoles]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetJobRoles]
(
	@roleId INT = 0
)
AS
BEGIN
	SELECT
		JobTitleId,
		JobTitleName
	FROM [dbo].[JobTitle]
	WHERE
		 Status = 1
		 AND
		 (
			(
				@roleId <> 0
				AND
				JobTitleId = @roleId
			)
			OR
			(
				@roleId = 0
			)
		)
	
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerContactedDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobSeekerContactedDetails] 
(
 @UserId INT
)
AS
BEGIN
SELECT 
	[Subject],
	CreatedOn,
	FromEmail,
	ToEmail 
FROM EmailQueue
 WHERE ToId = @UserId
END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerDashboardStats]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			11/08/2020			CREATE - Getting job seeker dashboard stats
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetJobSeekerDashboardStats]
(
@UserId INT
)
AS 
BEGIN

	SELECT  
		COUNT(ViewedId) AS ViewedYourProfile
	FROM [dbo].[ProfileViewSummary] WHERE ViewedId = @UserId 

	SELECT 
		COUNT(UserId) AS TotalAppliedJobs
	FROM [dbo].[AppliedJobs] 
	WHERE 
	UserId = @UserId
	AND [Status] =1


	SELECT 
		COUNT(ToId) AS TotalContactedNo
	FROM EmailQueue where ToId=@UserId


	SELECT COUNT(JobSeekerID) AS TotalCompaniesFollowed 
	FROM EmployerFollower
	WHERE JobSeekerID = @UserId
	AND IsActive=1
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerInformation]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobSeekerInformation]
(
	@UserId INT
)
AS
BEGIN

	--	Get Marital Master
	EXEC usp_GetMaritalStatusMaster

	--	Get Gender Master
	EXEC usp_GetGenderMaster

	--	Get Countries Master
	EXEC usp_GetCountries

	--	Personnel Details
	EXEC usp_GetUserPersonalDetails @UserId

	--	Professional Details
	EXEC usp_GetUserProfessionalDetails @UserId

	--	Get All Cities
	EXEC usp_GetCities

	--	Get All Job Industries
	EXEC usp_GetAllJobIndustryArea

	--	Get All Course Categories
	EXEC usp_GetCourseCategories

	--	Get All Course Types Master
	EXEC usp_GetCourseTypeMaster
END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerInformationForResumeBuilder]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobSeekerInformationForResumeBuilder]
(
	@UserId INT
)
AS
BEGIN

	--	Professional Details
	EXEC usp_GetUserProfessionalDetails @UserId

	--	Personnel Details
	EXEC usp_GetUserPersonalDetails @UserId

END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobseekerProfileData]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_GetJobseekerProfileData] 
(  
 @userId INT  
)  
AS BEGIN  
 SELECT   
  U.FirstName,  
  U.LastName,  
  U.MobileNo,  
  U.Email,  
  U.MaritalStatus,  
  U.Address1,  
  U.City,  
  U.Country,  
  U.[State],  
  U.Gender,   
  U.ProfilePic,  
  U.Candidateid,  
  JT.JobTitleName,
  UP.JobTitleId,  
  UP.ID,  
  UP.ExperienceDetails,  
  UP.EducationalDetails,  
  UP.Skills,  
  UP.CurrentSalary,  
  UP.ExpectedSalary,  
  UP.TotalExperience,  
  UP.DateOfBirth,  
  UP.[Resume],  
  UP.AboutMe,  
  UP.ProfileSummary,  
  UP.EmploymentStatusId,
  UP.JobIndustryAreaId,  
  UP.[Resume],  
  M.Status AS MaritalStatusName,
  UP.LinkedinProfile,
  ES.EmploymentStatusName,
  ISNULL(UP.IsJobAlert,0) AS IsJobAlert
 FROM [dbo].[Users] AS U  
  LEFT JOIN [dbo].[UserProfessionalDetails] AS UP  
  ON U.UserId = UP.UserId  
  LEFT JOIN [dbo].[JobTitle] AS JT  
  ON UP.JobTitleId = JT.JobTitleId  
  LEFT JOIN [dbo].[MaritalStatus] AS M
  ON U.MaritalStatus = M.StatusCode  
  LEFT JOIN EmploymentStatus AS ES  
  ON UP.EmploymentStatusId = ES.EmploymentStatusId
 WHERE U.UserId = @userId
END  


GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekersBasedOnEmployerHiringCriteria]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetJobSeekersBasedOnEmployerHiringCriteria]     
(    
 @Year VARCHAR(MAX) = NULL,    
 @JobRole VARCHAR(MAX)=NULL,    
 @City Varchar(MAX) = NULL,    
 @EmpId INT=NULL    
)    
AS    
BEGIN    
SELECT    
  U.UserId,    
  JT.JobTitleName,    
  CT.Name,    
  U.Candidateid,    
  U.FirstName,    
  U.LastName,    
  U.MobileNo,    
  U.Email,    
  G.Gender,    
  UPD.Skills,    
  UPD.CurrentSalary,    
  UPD.ExpectedSalary,    
  UPD.Resume,    
  UPD.ProfileSummary,    
  UPD.AboutMe    
  INTO #T  
 FROM dbo.Users U    
  INNER JOIN UserRoles UR    
  ON U.UserId = UR.UserId               
  LEFT JOIN dbo.UserProfessionalDetails UPD    
  ON U.UserId = UPD.UserId    
  LEFT JOIN dbo.Gender G    
  ON U.Gender = G.GenderCode    
  LEFT JOIN [dbo].[Cities] AS CT    
  ON CT.CityCode = U.City    
  LEFT JOIN [dbo].[JobTitle] AS JT    
  ON JT.JobTitleId = UPD.JobTitleId

  WHERE UR.RoleId = 2     
  AND     
  (    
   (    
    ISNULL(@City,'') <> ''    
    AND    
    U.city = @City    
   )    
    
   OR    
   (    
    ISNULL(@city,'') = ''    
   )       
  )    
  AND    
  (    
   (    
    ISNULL(@JobRole,'') <> ''    
    AND    
    JT.[JobTitleId] IN (SELECT val FROM dbo.f_split(@JobRole, ','))    
   )    
    
   OR    
   (    
    ISNULL(@JobRole,'') = ''    
   )       
  )    
    
  AND    
  (    
   (    
    ISNULL(@Year,'') <> ''    
    AND    
    Year(U.CreatedOn) = @Year    
   )    
    
   OR    
   (    
    ISNULL(@Year,'') = ''    
   )       
  )    
 ORDER BY    
  CASE     
   WHEN U.CreatedOn IS NOT NULL THEN U.CreatedOn    
   WHEN UPD.CreatedDate IS NOT NULL THEN UPD.CreatedDate    
   WHEN U.UpdatedOn IS NOT NULL THEN U.UpdatedOn    
   ELSE UPD.UpdatedDate END    
   DESC    
  
Select Distinct * from #T  
  
END 


GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekersFilterByCity]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobSeekersFilterByCity] 
(
	@City VARCHAR(MAX) = NULL
)
AS
BEGIN
	SELECT
		U.UserId,
		U.Candidateid,
		U.FirstName,
		U.LastName,
		U.MobileNo,
		U.Email,
		G.Gender,
		UPD.Skills,
		UPD.CurrentSalary,
		UPD.ExpectedSalary,
		UPD.Resume,
		UPD.ProfileSummary,
		UPD.AboutMe
	FROM dbo.Users U
		LEFT JOIN dbo.Gender G
		ON U.Gender = G.GenderCode
		LEFT JOIN dbo.UserProfessionalDetails UPD
		ON U.UserId = UPD.UserId
		INNER JOIN UserRoles UR
		ON U.UserId = UR.UserId
		WHERE UR.RoleId = 2
		AND 
		U.City = @City
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekersFilterByYear]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobSeekersFilterByYear] 
(
	@Year VARCHAR(MAX) = NULL
)
AS
BEGIN
	SELECT
		U.UserId,
		U.Candidateid,
		U.FirstName,
		U.LastName,
		U.MobileNo,
		U.Email,
		G.Gender,
		UPD.Skills,
		UPD.CurrentSalary,
		UPD.ExpectedSalary,
		UPD.Resume,
		UPD.ProfileSummary,
		UPD.AboutMe
	FROM dbo.Users U
		LEFT JOIN dbo.Gender G
		ON U.Gender = G.GenderCode
		LEFT JOIN dbo.UserProfessionalDetails UPD
		ON U.UserId = UPD.UserId
		INNER JOIN UserRoles UR
		ON U.UserId = UR.UserId
		WHERE UR.RoleId = 2
		AND 
		Year(U.CreatedOn) = @Year
	END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekersForPostedJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobSeekersForPostedJobs]
(
	@EmpId INT,
	@JobId INT = 0
)
AS
BEGIN
	WITH CTE_GEtJobSeekers AS
	(
	SELECT
		JPD.JobPostId,
		JPD.JobTitleByEmployer,
		U.UserId,
		U.Candidateid,
		U.FirstName,
		U.LastName,
		U.MobileNo,
		U.Email,
		G.Gender,
		UPD.Skills,
		UPD.CurrentSalary,
		UPD.ExpectedSalary,
		UPD.Resume,
		JT.JobTitleName AS JobRole		
	FROM dbo.Users U
		LEFT JOIN dbo.UserProfessionalDetails UPD
		ON U.UserId = UPD.UserId
		LEFT JOIN dbo.Gender G
		ON U.Gender = G.GenderCode
		LEFT JOIN dbo.AppliedJobs AJ
		ON U.UserId = AJ.UserId
		LEFT JOIN dbo.JobPostDetail JPD
		ON AJ.JobPostId = JPD.JobPostId
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JPD.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle JT
		ON JRM.JobRoleId = JT.JobTitleId
	WHERE JPD.UserId = @EmpId
		AND (
				(
					ISNULL(@JobId,0) = 0
				)
				OR
				(
					ISNULL(@JobId,0) <> 0
					AND JPD.JobPostId = @JobId				
				)
			)
		AND U.IsActive=1   --- To exclude deleted user 06/12/2020
	)

	SELECT
		DISTINCT 
		JobPostId,
		JobTitleByEmployer,
		UserId,
		Candidateid,
		FirstName,
		LastName,
		MobileNo,
		Email,
		Gender,
		Skills,
		CurrentSalary,
		ExpectedSalary,
		[Resume],		
		STUFF(
			(
				SELECT
					DISTINCT 
					', ' + JobRole
				FROM CTE_GEtJobSeekers CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobRole
	FROM CTE_GEtJobSeekers CTE1	
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerSkills]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetJobSeekerSkills]
(
@UserId INT
)
AS
BEGIN
SELECT [Skills] FROM UserProfessionalDetails WHERE UserId = @UserId
END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobsInDateRange]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobsInDateRange]
(
@StartDate Varchar(MAX)=NULL,
@EndDate Varchar(MAX) = NULL
)
AS
BEGIN
;WITH CTE_JobsOnRange AS
(
SELECT
JPD.JobPostId,
C.Name AS Country,
S.Name AS [State],
CT.Name AS City,
JPD.HiringCriteria,
JTT.Id AS JobType,
JTT.[Type] AS JobTypeSummary,
JPD.JobDetails,
JPD.CTC,
JPD.Featured,
JPD.FeaturedJobDisplayOrder,
JPD.CreatedDate AS PostedOn,
JPD.Quarter1,
JPD.Quarter2,
JPD.Quarter3,
JPD.Quarter4,
JPD.JobTitleByEmployer,
U2.CompanyName
FROM dbo.JobPostDetail JPD
LEFT JOIN dbo.Countries C
ON JPD.CountryCode = C.CountryCode
LEFT JOIN dbo.States S
ON JPD.StateCode = S.StateCode
LEFT JOIN dbo.Cities CT
ON JPD.CityCode = CT.CityCode
LEFT JOIN dbo.JobRoleMapping JRM
ON JPD.JobPostId = JRM.JobId
LEFT JOIN dbo.JobTitle JT
ON JRM.JobRoleId = JT.JobTitleId
LEFT JOIN dbo.JobTypes JTT
ON JPD.JobType = JTT.Id

LEFT JOIN dbo.Users U2
ON JPD.UserId = U2.UserId

LEFT JOIN dbo.Users U
ON JPD.CreatedBy = U.UserId
LEFT JOIN dbo.UserRoles UR
ON U.UserId = UR.UserId
LEFT JOIN dbo.Roles R
ON UR.RoleId = R.ID
WHERE CAST(JPD.CreatedDate AS DATE) >= CAST(@StartDate AS DATE)
AND CAST(JPD.CreatedDate AS DATE) <= CAST(@EndDate AS DATE)
AND R.ID IN (3,4)
AND U.IsActive =1  --- To exclude deleted user 06/12/2020 
)

SELECT
DISTINCT
JobPostId,
Country,
[State],
City,
HiringCriteria,
JobType,
JobTypeSummary,
JobDetails,
CTC,
Featured,
FeaturedJobDisplayOrder,
PostedOn,
Quarter1,
Quarter2,
Quarter3,
Quarter4,
JobTitleByEmployer,
CompanyName
FROM CTE_JobsOnRange
ORDER BY
PostedOn DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobTypes]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobTypes]
AS
BEGIN
	SELECT
		Id,
		[Type]
	FROM dbo.JobTypes
	WHERE IsActive = 1
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetMaritalStatusMaster]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetMaritalStatusMaster]
AS
BEGIN
	SELECT
		StatusId,
		StatusCode,
		Status
	FROM dbo.MaritalStatus
	WHERE IsActive = 1
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetMessages]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetMessages]
(
	@SelectedDate DATETIME = NULL,
	@ToId INT
)
AS
BEGIN
	SET @SelectedDate = COALESCE(@SelectedDate,GETDATE())
	SELECT
		EQ.Id AS MessageId,
		EQ.FromId AS SenderId,
		EQ.ToId AS ReceiverId,
		EQ.IsReplied,
		EQ.FromEmail,
		EQ.ToEmail,
		U.FirstName AS SenderFName,
		U.LastName AS SenderLName,
		U.MobileNo AS SenderMobile
	FROM dbo.EmailQueue EQ
		INNER JOIN dbo.Users U
		ON EQ.FromId = U.UserId
		INNER JOIN dbo.MailType MT
		ON EQ.MailType = MT.Id
	WHERE U.IsActive = 1
		AND EQ.ToId = @ToId
		AND CAST(EQ.CreatedOn AS DATE) = CAST(@SelectedDate AS DATE)
		AND MT.Id = 6
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetMessagesCount]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetMessagesCount]
(
	@SelectedDate DATETIME = NULL,
	@ToId INT
)
AS
BEGIN
	SET @SelectedDate = COALESCE(@SelectedDate,GETDATE())
	SELECT
		COUNT(EQ.Id) AS TotalMessages
	FROM dbo.Users U
		INNER JOIN dbo.EmailQueue EQ
		ON U.UserId = EQ.FromId
	WHERE U.IsActive = 1
		AND EQ.ToId = @ToId
		AND CAST(EQ.CreatedOn AS DATE) = CAST(@SelectedDate AS DATE)
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetMonthlyAppliedJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetMonthlyAppliedJobs]
(
	@Month INT,
	@Year INT,
	@Gender VARCHAR(15),
	@State VARCHAR(50)
)
AS
BEGIN
	SELECT  
		U.[Userid],  
		U.FirstName,  
		U.LastName,  
		U.[Email],  
		U.[MobileNo],
		JPD.JobPostId,  
		JPD.JobTitleByEmployer,  
		JPD.CTC,  
		JT.[Type] AS JobTypeDesc,  
		U2.CompanyName,  
		CT.Name AS City,  
		S.Name AS [State],  
		AJ.AppliedDate  
	FROM dbo.AppliedJobs AJ  
		INNER JOIN dbo.JobPostDetail JPD  
		ON AJ.JobPostId = JPD.JobPostId  
		LEFT JOIN dbo.Users U  
		ON AJ.UserId = U.UserId  
		LEFT JOIN dbo.JobTypes JT  
		ON JPD.JobType = JT.Id  
		LEFT JOIN dbo.Users U2  
		ON JPD.UserId = U2.UserId  
		LEFT JOIN dbo.States S  
		ON JPD.StateCode = S.StateCode  
		LEFT JOIN dbo.Cities CT  
		ON JPD.CityCode = CT.CityCode  
		
		LEFT JOIN dbo.Users U3  
		ON JPD.CreatedBy = U3.UserId  
		LEFT JOIN dbo.UserRoles UR  
		ON UR.UserId = U3.UserId  
		LEFT JOIN dbo.Roles R  
		ON UR.RoleId = R.ID  
	WHERE YEAR(CAST(AJ.AppliedDate AS DATE)) = @Year  
		AND MONTH(CAST(AJ.AppliedDate AS DATE)) = @Month  
		AND R.ID IN (3,4)  
		AND (
			(
				ISNULL(@State,'') = ''
			)
			OR
			(
				ISNULL(@State,'') <> ''
				AND JPD.StateCode = @State
			)
		)	
		AND(
			(
				ISNULL(@Gender, 'all') = 'all'
			)
			OR
			(
				ISNULL(@Gender, 'all') <> 'all'
				AND U.Gender = @Gender
			)
		)
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020 
	ORDER BY   
		AJ.AppliedDate DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetMonthlyJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetMonthlyJobs]
(
	@Month INT,
	@Year INT,
	@State VARCHAR(50),
	@ActiveJobs BIT
)
AS
BEGIN
	;WITH CTE_MonthlyJobs AS
	(
SELECT
		JPD.JobPostId,
		C.Name AS Country,
		S.Name AS [State],
		CT.Name AS City,
		JTT.[Type] AS JobTypeSummary,
		JPD.JobDetails,
		JPD.CTC,
		JPD.CreatedDate AS PostedOn,
		JT.JobTitleName,
		JPD.JobTitleByEmployer,
		U.CompanyName As CompanyName
	FROM dbo.JobPostDetail JPD
		LEFT JOIN dbo.Countries C
		ON JPD.CountryCode = C.CountryCode
		LEFT JOIN dbo.States S
		ON JPD.StateCode = S.StateCode
		LEFT JOIN dbo.Cities CT
		ON JPD.CityCode = CT.CityCode
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JPD.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.JobTypes JTT
		ON JPD.JobType = JTT.Id
		LEFT JOIN dbo.Users U
		ON JPD.CreatedBy = U.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.ID
	WHERE YEAR(JPD.CreatedDate) = @year
		AND MONTH(JPD.CreatedDate) = @Month
		AND R.ID IN (3,4)
		AND (
			(
				ISNULL(@State,'') = ''
			)
			OR
			(
				ISNULL(@State,'') <> ''
				AND JPD.StateCode = @State
			)
		)
		AND (
				(
					@ActiveJobs = 0
					AND CAST(JPD.PositionEndDate AS DATE) < CAST(GETDATE() AS DATE)
				)
				OR
				(
					@ActiveJobs = 1
					AND CAST(JPD.PositionEndDate AS DATE) >= CAST(GETDATE() AS DATE)
				)
		)
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020 
	)

	SELECT
		DISTINCT
		JobPostId,
		Country,
		[State],
		City,
		JobTypeSummary,
		JobDetails,
		CTC,
		PostedOn,
		CompanyName,
		STUFF(
			(
				SELECT
					DISTINCT
					', ' + JobTitleName
				FROM CTE_MonthlyJobs CTE2
				WHERE CTE1.JobPostId = CTE2.JobPostId
				FOR XML PATH('')),1,2,''
			) AS JobTitleName,
		JobTitleByEmployer	
	FROM CTE_MonthlyJobs CTE1
	ORDER BY
		PostedOn DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetMonthlyRegisteredUsers]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetMonthlyRegisteredUsers] 
(
	@Month  INT, 
	@Year   INT, 
	@State  VARCHAR(50), 
	@Gender VARCHAR(50)
) 
AS 
  BEGIN 
      SELECT U.[userid], 
             U.[firstname], 
             U.[lastname], 
             U.[mobileno], 
             U.[email], 
             CT.[name] AS City, 
             ST.[name] AS State, 
             U.[gender], 
             U.createdon, 
             U.[maritalstatus], 
             R.[rolename] 
      FROM   [dbo].[users] U 
             LEFT JOIN dbo.userroles UR 
                    ON U.[userid] = UR.[userid] 
             LEFT JOIN dbo.roles R 
                    ON UR.[roleid] = R.[id] 
             LEFT JOIN [dbo].[cities] AS CT 
                    ON U.city = CT.citycode 
             LEFT JOIN [dbo].[states] AS ST 
                    ON U.[state] = ST.statecode 
      WHERE  Year(Cast(U.createdon AS DATE)) = @Year 
             AND Month(Cast(U.createdon AS DATE)) = @Month 
             AND R.id <> 1 
             AND Isnull(U.isregisteronlyfordemandaggregationdata, 0) = 0 
             AND (
					( 
					Isnull(@State, '') = '' 
					) 
					OR 
					( 
					Isnull(@State, '') <> '' 
					AND
					U.[state] = @State 
					) 
				) 
             AND (
					(
						Isnull(@Gender, 'all') = 'all'
					) 
					OR 
					( 
						Isnull(@Gender, 'all') <> 'all' 
						AND U.gender = @Gender 
					)
				) 
			AND U.IsActive=1   --- To exclude deleted user 06/12/2020
      ORDER  BY U.createdon DESC 
  END 


GO
/****** Object:  StoredProcedure [dbo].[usp_GetMonthWiseCountJobPost]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetMonthWiseCountJobPost]
AS
BEGIN
	SELECT  
		[1] AS January,
		[2] AS February,
		[3] AS March,
		[4] AS April,
		[5] AS May,
		[6] AS June,
		[7] AS July,
		[8] AS August,
		[9] AS September,
		[10] AS October,
		[11] AS November, 
		[12] AS December 
	FROM
	(
	SELECT MONTH(CreatedDate) AS MONTH, [UserId] FROM JobPostDetail
	) AS t
	PIVOT (
	COUNT([UserId])
	  FOR MONTH IN([1], [2], [3], [4], [5],[6],[7],[8],[9],[10],[11],[12])
	) p
END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetNotificationsCounter]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetNotificationsCounter]
AS
BEGIN
	SELECT
		COUNT(UserId) AS TotalNewUsers
	FROM dbo.Users
	WHERE ISNULL(IsViewedByAdmin,0) = 0
		AND IsActive = 1
		AND ISNULL(IsRegisterOnlyForDemandAggregationData,0) = 0
END




GO
/****** Object:  StoredProcedure [dbo].[usp_GetPopulerSearchCategory]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 /*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			16/01/2020			Created - Getting populer searches
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetPopulerSearchCategory]
AS 
BEGIN
	SELECT TOP 8
	JA.JobIndustryAreaId AS JobIndustryAreaId,
	JA.JobIndustryAreaName AS JobIndustry,
	COUNT(JPD.JobPostId) AS [COUNT]
FROM dbo.JobIndustryArea JA
	LEFT JOIN dbo.JobPostDetail JPD
	LEFT JOIN dbo.Users U2
		ON JPD.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id
	ON JA.JobIndustryAreaId = JPD.JobIndustryAreaId
	LEFT JOIN dbo.PopularJobSearches PJS
	ON PJS.FilterName = 'JobCategory'
		AND PJS.FilterValue = JA.JobIndustryAreaId
		Where JPD.JobPostId !='0'
		AND ISNULL(R.ID,0) !=1
		AND U2.IsActive=1   --- To exclude deleted user 06/12/2020
	GROUP BY
		JA.JobIndustryAreaId,
		JA.JobIndustryAreaName,
		PJS.Count
	ORDER BY
		PJS.Count DESC

END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetPopulerSearchCity]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			16/01/2020			Created - Getting populer searches City
                       Update Date          Update 
					   19-03-2020			Only employer job will show
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetPopulerSearchCity]
AS 
BEGIN
	SELECT	TOP 10
	C.CityCode,
	C.Name AS City,
	COUNT(JPD.JobPostId) AS [COUNT]
FROM dbo.Cities C
	LEFT JOIN dbo.JobPostDetail JPD
	INNER JOIN dbo.Users AS U
	ON
	 JPD.UserId =U.UserId
	ON C.CityCode = JPD.CityCode

	LEFT JOIN dbo.Users U2
		ON JPD.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

	LEFT JOIN dbo.PopularJobSearches PJS
	ON PJS.FilterName = 'City'
		AND PJS.FilterValue = C.CityCode
		Where JPD.JobPostId !='0'
		AND ISNULL(R.ID,0) !=1
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020
	GROUP BY
		C.CityCode,
		C.Name,
		PJS.Count
	ORDER BY
		PJS.Count DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetProfileScore]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetProfileScore]
(
@UserId INT
)
AS
BEGIN

DECLARE @ITSKILLS INT;
IF(NOT EXISTS(SELECT Id FROM ITSkills WHERE CreatedBy = @UserId))
BEGIN
SET @ITSKILLS=0;
END
ELSE 
BEGIN
SET @ITSKILLS=10;
END
	SELECT 
	@ITSKILLS AS ITSkills,
	(CASE WHEN ExperienceDetails IS NULL THEN 0 ELSE 10 END) AS ExperienceDetails,
	(CASE WHEN EducationalDetails IS NULL THEN 0 ELSE 10 END) AS EducationalDetails,
	(CASE WHEN Skills IS NULL THEN 0 ELSE 10 END) AS Skills,
	(CASE WHEN AboutMe IS NULL THEN 0 ELSE 10 END) AS AboutMe,
	(CASE WHEN [Resume] IS NULL THEN 0 ELSE 10 END) AS [Resume],
	(CASE WHEN ProfileSummary IS NULL THEN 0 ELSE 10 END) AS ProfileSummary,
	(CASE WHEN EmploymentStatusId IS NULL THEN 0 ELSE 10 END) AS EmploymentStatus,
	(CASE WHEN [JobIndustryAreaId] IS NULL THEN 0 ELSE 10 END) AS JobIndustryAreaId,
	(CASE WHEN [TotalExperience] IS NULL THEN 0 ELSE 5 END) AS TotalExperience,
	(CASE WHEN DateOfBirth IS NULL THEN 0 ELSE 5 END) AS DateOfBirth
	INTO #TempProfileScore
	FROM UserProfessionalDetails
	WHERE UserId=@UserId

	SELECT (
	ITSkills + ExperienceDetails + EducationalDetails + Skills + AboutMe + [Resume] + ProfileSummary + EmploymentStatus + JobIndustryAreaId
	+ TotalExperience + DateOfBirth ) AS Total FROM #TempProfileScore
	DROP TABLE #TempProfileScore
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetRecentJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			10/08/2020			Created - Getting Recent Jobs   
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetRecentJobs]
AS
BEGIN
WITH CTE_GetRecentsJobs AS
	(
	SELECT  TOP 4    
		JP.JobPostId,
		JP.JobTitleByEmployer,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.[CompanyName] AS CompanyName,
		JP.CTC AS CTC,
		DATEDIFF(DAY, JP.CreatedDate, GETDATE()) AS NumberOfDays
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId

		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

	WHERE ISNULL(R.ID,0) !=1
	AND U.IsActive=1
	ORDER BY 
	JP.CreatedDate DESC
	)
	SELECT
		DISTINCT
		JobPostId,
		STUFF(
		(
			SELECT 
				', ' + JobTitle
			FROM CTE_GetRecentsJobs CTE2
			WHERE CTE1.JobPostId = CTE2.JobPostId
			FOR XML PATH('')),1,2,''
		) AS JobTitle,
		JobTitleByEmployer,
		EmploymentStatus,
		City,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		CTC,
		NumberOfDays
	FROM CTE_GetRecentsJobs CTE1
	ORDER BY NumberOfDays ASC
END

--------2--------------


GO
/****** Object:  StoredProcedure [dbo].[usp_GetResponseTime]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			10/19/2019			Created - Converted Inline Queries to SP
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetResponseTime]
AS
BEGIN
	Select * from [EmailQueue] where IsReplied=0
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetResume]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetResume]
(
	@UserId INT
)
AS
BEGIN
	SELECT
		UPD.Resume AS ResumePath
	FROM
		dbo.UserProfessionalDetails UPD
		INNER JOIN dbo.Users U
		ON UPD.UserId = U.UserId
	WHERE U.UserId = @UserId
		AND U.IsActive = 1
		AND U.IsApproved = 1
END






GO
/****** Object:  StoredProcedure [dbo].[usp_GetRoles]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetRoles]
AS
BEGIN
	SELECT id,RoleName,IsEmployee FROM Roles where RoleName != 'Admin'
END







GO
/****** Object:  StoredProcedure [dbo].[usp_GetSearchJobOnSkills]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			13/08/2020			Created - Getting jobs on job seeker skills
   
-------------------------------------------------------------------------------------------------
*/

CREATE PROCEDURE [dbo].[usp_GetSearchJobOnSkills]
(
	@Skills VARCHAR(1000) = NULL,
	@UserId INT
)
AS
BEGIN
DECLARE @Experience VARCHAR =  (SELECT TotalExperience FROM UserProfessionalDetails WHERE UserId=@UserId)

SELECT items
INTO #TempInputSkills
 FROM udf_Split(@Skills,',')
 
 SELECT
  JobPostId,items
  INTO #TempTotalSkills
FROM dbo.JobPostDetail 
CROSS APPLY  udf_Split(Skills,',')
WHERE Skills IS NOT NULL
AND Skills <> '' 

SELECT JobPostId INTO #TempFinalSkills FROM #TempTotalSkills AS TTS
INNER JOIN #TempInputSkills AS INS
ON
TTS.items=INS.items



;WITH CTE_Jobs AS
(
	SELECT 
		JP.JobPostId,
		JP.JobTitleByEmployer,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		ISNULL(JP.Skills,'') AS Skills,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.CompanyName,
		CAST(JP.PositionStartDate AS DATETIME) AS PostingDate,
		CAST(JP.PositionEndDate AS DATETIME) AS ExpiryDate,
		CAST(JP.CreatedDate AS DATETIME) AS CreatedDate,
		JP.CTC,
		JP.MinExperience
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId
		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id
		INNER JOIN #TempFinalSkills AS FA
		ON
		JP.JobPostId= FA.JobPostId

	WHERE 
		ISNULL(JP.SPOCEmail,'') <> ''
		AND R.Id IN (3,4)
		AND U.IsActive =1
		AND JP.MinExperience>=@Experience
)

SELECT
	DISTINCT
	JobPostId,
	JobTitleByEmployer,
	STUFF(
		(
			SELECT 
				', ' + JobTitle
			FROM CTE_Jobs cte2
			WHERE cte2.JobPostId = cte1.JobPostId
			FOR XML PATH('')),1,2,''
		) AS JobTitle,
	EmploymentStatus,
	Skills,
	City,
	HiringCriteria,
	CompanyLogo,
	CompanyName,
	PostingDate,
	ExpiryDate,
	CreatedDate,
	CTC,
	MinExperience
FROM CTE_Jobs cte1
ORDER BY 
	CreatedDate DESC

	DROP TABLE #TempInputSkills
	DROP TABLE #TempTotalSkills
	DROP TABLE #TempFinalSkills

END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetSearchList]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_GetSearchList]
(
	@Skills VARCHAR(1000) = NULL,
	@jobTitle INT = 0,
	@jobCategory VARCHAR(1000) = NULL,
	@Experience INT = -1,
	@city VARCHAR(1000) =NULL,
	@user INT = 0,
	@CompanyUserId VARCHAR(1000)=NULL
)
AS
BEGIN

	EXEC usp_UpdatePopularSearches
	@jobCategory,
	@city,
	@jobTitle,
	@Experience,
	@user
--........................................


	;WITH CTE_Jobs AS
	(
		SELECT
		JP.JobPostId,
		JP.JobTitleByEmployer,
		JT.JobTitleName AS JobTitle,
		JP.CTC,		
		ES.EmploymentStatusName AS EmploymentStatus,
		ISNULL(JP.Skills,'') AS Skills,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.CompanyName,
		CAST(JP.PositionStartDate AS DATETIME) AS PostingDate,
		CAST(JP.PositionEndDate AS DATETIME) AS ExpiryDate,
		CAST(JP.CreatedDate AS DATETIME) AS CreatedDate,
		DATEDIFF(DAY, JP.CreatedDate, GETDATE()) AS NumberOfDays
		FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.EmploymentStatus AS ES
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId
		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

	WHERE
		ISNULL(JP.SPOCEmail,'') <> ''
		AND R.Id IN (3,4)
		AND U.IsActive = 1 --- To exclude deleted user 06/12/2020
		AND
		(
		(
		ISNULL(@city,'') <> ''
		AND
		C.CityCode IN (SELECT val FROM dbo.f_split(@city, ','))
		)
		OR
		(
		ISNULL(@city,'') = ''
		)
		)
		AND
		(
		(
		ISNULL(@jobCategory,'') <> ''
		AND
		JA.JobIndustryAreaId IN (SELECT val FROM dbo.f_split(@jobCategory, ','))
		)
		OR
		(
		ISNULL(@jobCategory,'') = ''
		)
		)
		AND
		(
		(
		@jobTitle > 0
		AND
		JT.JobTitleId = @jobTitle
		)
		OR
		(
		@jobTitle = 0
		)
		)
		AND
		(
			(
				ISNULL(@Skills,'') <> ''
				AND
				JP.Skills like '%'+@Skills+'%'
			)		
		OR
			(
				ISNULL(@Skills,'') = ''
			)
		)
		AND
		(
			(
				@Experience > -1
				AND
				@Experience BETWEEN Jp.MinExperience AND JP.MaxExperience
			)
		OR
		(
		@Experience = -1
		)
		)
		AND
		(
		(
		ISNULL(@CompanyUserId,'') <> ''
		AND
		U.UserId IN (SELECT val FROM dbo.f_split(@CompanyUserId, ','))
		)
		OR
		(
		ISNULL(@CompanyUserId,'') = ''
		)
		)
		)

		SELECT
		DISTINCT
		JobPostId,
		JobTitleByEmployer,
		STUFF((	SELECT ', ' + JobTitle FROM CTE_Jobs cte2 
		WHERE cte2.JobPostId = cte1.JobPostId FOR XML PATH('')),1,2,'') AS JobTitle,
		EmploymentStatus,
		Skills,
		City,
		CTC,
		NumberOfDays,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		PostingDate,
		ExpiryDate,
		CreatedDate
		FROM CTE_Jobs cte1
		ORDER BY
		CreatedDate DESC
END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetStaffingPartnerCount]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetStaffingPartnerCount]
AS 
BEGIN
	SELECT 
	U.UserId,Email
	FROM
	Users AS U 
	INNER JOIN 
	UserRoles AS UR 
	on 
	U.UserId = UR.UserId  
	WHERE CAST(UR.Createddate AS DATE)= GETDATE() 
	AND UR.RoleId = 4
	AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0
END




GO
/****** Object:  StoredProcedure [dbo].[usp_GetStates]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetStates]
(
	@countryCode NVARCHAR(5)
)
AS 
BEGIN
	SELECT 
		CountryCode,
		StateCode,
		Name as State
	FROM [dbo].[States]
	WHERE IsActive=1
		AND CountryCode=@countryCode
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetStudentCount]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetStudentCount]
AS 
BEGIN
	SELECT 
	U.UserId,Email
	FROM
	Users AS U 
	INNER JOIN 
	UserRoles AS UR 
	on 
	U.UserId = UR.UserId  
	WHERE CAST(UR.Createddate AS DATE)= GETDATE() 
	AND UR.RoleId = 2
	AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetSuccessStory]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
 /*
-------------------------------------------------------------------------------------------------
SR  		By			Date				Remarks
1			SR			14/01/2020			Created - update to check wheather approved or not
                                            Updated Date - 11-02-2020  
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetSuccessStory]
AS
BEGIN
  SELECT
   ROW_NUMBER() Over (Order by ID) As CountValue, 
		SS.[Id],
		U.[FirstName],
		SS.[Email],
		SS.[TagLine],
		SS.[Message],
		SS.[CreatedDate],
		U.[ProfilePic],
		U.City AS City
	FROM [dbo].[SuccessSotry] AS SS
		INNER JOIN [dbo].[Users] AS U
	ON
		U.UserId = SS.UserId
		
	WHERE SS.[Status] = 1
		AND SS.[IsApproved] = 1
	GROUP BY 
		SS.Id,
		U.[FirstName],
		SS.[Email],
		SS.[TagLine],
		SS.[Message],
		SS.[CreatedDate],
		U.[ProfilePic],
		U.City
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetSuccessStoryReview]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR  		By			Date				Remarks
1			SR			11/02/2020			Created - update to check wheather approved or not
                                             
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetSuccessStoryReview]
AS
BEGIN
  SELECT
    ROW_NUMBER() Over (Order by ID) As CountValue, 
    [Id],
    [Name],
	[Email],
    [TagLine],
    [Message],
    [CreatedDate],
    
	[IsApproved]
  FROM [dbo].[SuccessSotry]
  WHERE [Status] = 1
  GROUP BY 
		[Id],
		[Name],
		[Email],
		[TagLine],
		[Message],
		[CreatedDate],
		[IsApproved]
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetSuccessStoryVideoPosted]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			11/02/2019			Created - for getting success story video
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetSuccessStoryVideoPosted] 
AS 
  BEGIN 
	SELECT [title], 
			[filename], 
			[type], 
			[createdby],
			[CreatedDate],
			[DisplayOrder]
	FROM   [dbo].[successstoryvideo] 
	WHERE  [status] = 1 
	ORDER BY [DisplayOrder]
  END 



GO
/****** Object:  StoredProcedure [dbo].[usp_GetTopEmployer]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetTopEmployer]
AS
BEGIN
	SELECT TOP(4) 
	COUNT(JP.UserId) AS [Count],
	----COUNT(JP.JobPostId) AS [JobCount],
	U.[CompanyName] AS CompanyName,
	U.ProfilePic AS Logo,
	JP.UserId AS UserId,
	ISNULL(EF.JobSeekerID,0) AS JobSeekerID,
	ISNULL(EF.IsActive,0) As FollowIsActive
	FROM 
	AppliedJobs AS AJ
	INNER JOIN
	JobPostDetail AS JP
	ON
	JP.JobPostId = AJ.JobPostId
	INNER JOIN
	Users AS U
	ON
	U.UserId = JP.UserId
	INNER JOIN 
	[dbo].[UserRoles] AS JR
	ON
	JR.UserId = U.UserId
	LEFT JOIN EmployerFollower AS EF
	ON
	U.UserId = EF.EmployerID
	WHERE ISNULL(U.[CompanyName],'') <> ''
	--AND
	--ISNULL(U.ProfilePic,'') <> ''
	AND JR.RoleId=3
	GROUP BY U.[CompanyName],JP.UserId,U.ProfilePic,EF.JobSeekerID,EF.IsActive
	ORDER BY COUNT(1) DESC
END



-----------2-------------------

GO
/****** Object:  StoredProcedure [dbo].[usp_GetTotalApplicationsForAllJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetTotalApplicationsForAllJobs]
(
	@EmpId INT
)
AS
BEGIN
	SELECT 
		COUNT(AJ.UserId) AS TotalApplications
	FROM dbo.AppliedJobs AJ
		INNER JOIN dbo.JobPostDetail JPD
		ON AJ.JobPostId = JPD.JobPostId
		INNER JOIN dbo.Users U
		ON JPD.UserId = U.UserId
	WHERE U.UserId = @EmpId
		AND U.IsActive = 1
END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetTotalProfileViewed]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetTotalProfileViewed]
(
	@ViewerId INT
)
AS
BEGIN
	SELECT
		COUNT(PVS.ViewedId) AS TotalViewed
	FROM dbo.ProfileViewSummary PVS
		INNER JOIN dbo.Users U
		ON PVS.ViewerId = U.UserId
	WHERE U.UserId = @ViewerId
		AND U.IsActive = 1

END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetTPDetail]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR By Date Remarks
1 SR 01/29/2020 Created - To get the tp details from INSDMS
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetTPDetail]
@tpid varchar(50)
AS
BEGIN
/*
SELECT
-- TP.ID,
TP.JobPortalTPID AS ID,
U.email,
U.FirstName,
U.LastName
FROM [172.31.13.229].nasscom_staging.dbo.TrainingPartners AS TP
INNER JOIN [172.31.13.229].nasscom_staging.dbo.users AS U
ON TP.email=U.email WHERE TP.JobPortalTPID=@tpid
*/
SELECT TOP 1
-- TP.ID,
JobPortalTPID AS ID,
email,
FirstName,
LastName
FROM NASSCOM_LIVE_0529.dbo.Users Where JobPortalTPID=@tpid

END

GO
/****** Object:  StoredProcedure [dbo].[usp_GETTPDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			09/03/2020			Created - To get the TP Details
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GETTPDetails]
(
	@userid INT
)
AS
BEGIN
	SELECT UserId,
		FirstName,
		LastName,
		Email,
		Candidateid,
		ProfilePic
	FROM dbo.Users 
	WHERE Userid=@userid;
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetTrainingPartnerCandidates]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetTrainingPartnerCandidates]
(
	@TpId INT
)
AS
BEGIN
	SELECT
		UserId,
		Candidateid,
		FirstName,
		LastName,
		Email,
		[Password],
		IsActive
	FROM dbo.Users
	WHERE CreatedBy = @TpId
	  AND    IsActive=1
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetTrainingPartnerCount]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetTrainingPartnerCount]
AS 
BEGIN
	SELECT 
	U.UserId,Email
	FROM
	Users AS U 
	INNER JOIN 
	UserRoles AS UR 
	on 
	U.UserId = UR.UserId  
	WHERE CAST(UR.Createddate AS DATE)= GETDATE()
	AND UR.RoleId = 5
	AND ISNULL(U.IsRegisterOnlyForDemandAggregationData,0) = 0
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetuserITSkills]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

--------1----------------

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			06/08/2020			Created - To Get IT Skills
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetuserITSkills]
(
	@UserId INT
)
AS
BEGIN
	SELECT 
		[Id],
		[Skill],
		[SkillVersion],
		[LastUsed],
		[ExperienceYear],
		[ExperienceMonth]
	From ITSkills WHERE CreatedBy=@UserId
	AND [Status] = 1
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetUserPersonalDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetUserPersonalDetails]
(
	@UserId INT
)
AS
BEGIN
	DECLARE @StateCode NVARCHAR(5)
	DECLARE @CountryCode NVARCHAR(15)
	SELECT
		U.UserId,
		U.FirstName,
		U.LastName,
		U.Email,
		U.MobileNo,
		U.Address1,
		U.Address2,
		U.Address3,
		U.Country,
		C.Name AS CountryName,
		U.State,
		S.Name AS StateName,
		U.City,
		CT.Name AS CityName,
		U.MaritalStatus,
		MS.Status AS MaritalStatusName,
		U.Gender,
		G.Gender AS GenderName,
		UPD.DateOfBirth,
		UPD.TotalExperience
	FROM dbo.Users U
		LEFT JOIN dbo.Countries C
		ON U.Country = C.CountryCode
		LEFT JOIN dbo.States S
		ON U.State = S.StateCode
		LEFT JOIN dbo.Cities CT
		ON U.City = CT.CityCode		
		LEFT JOIN dbo.MaritalStatus MS
		ON U.MaritalStatus = MS.StatusCode
		LEFT JOIN dbo.Gender G
		ON U.Gender = G.GenderCode
		LEFT JOIN dbo.UserProfessionalDetails UPD
		ON U.UserId = UPD.UserId
	WHERE U.UserId = @UserId
		AND U.IsActive = 1
		AND U.IsApproved = 1

		-- Get User's State and City
	SELECT
		@StateCode = U.State,
		@CountryCode = U.Country
	FROM dbo.Users U
		LEFT JOIN dbo.Countries C
		ON U.Country = C.CountryCode
		LEFT JOIN dbo.States S
		ON U.State = S.StateCode
		LEFT JOIN dbo.Cities CT
		ON U.City = CT.CityCode		
		LEFT JOIN dbo.MaritalStatus MS
		ON U.MaritalStatus = MS.StatusCode
		LEFT JOIN dbo.Gender G
		ON U.Gender = G.GenderCode
		LEFT JOIN dbo.UserProfessionalDetails UPD
		ON U.UserId = UPD.UserId
	WHERE U.UserId = @UserId
		AND U.IsActive = 1
		AND U.IsApproved = 1


		-- Get Related States
		EXEC usp_GetStates @CountryCode

		-- Get Related Cities

		EXEC usp_GetCities @StateCode
	
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetuserPreferredlocations]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			10/02/2020			Created - To Get User Preferred Location
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetuserPreferredlocations]
(
	@UserId INT
)
AS
BEGIN
	SELECT LocationId,OtherLocation
	From PreferredLocation WHERE Userid=@UserId
END




GO
/****** Object:  StoredProcedure [dbo].[usp_GetUserProfessionalDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetUserProfessionalDetails]
(
	@UserId INT
)
AS
BEGIN
	SELECT
		U.UserId,
		UPD.ExperienceDetails,
		UPD.EducationalDetails,
		UPD.Skills
	FROM dbo.Users U
		INNER JOIN dbo.UserProfessionalDetails UPD
		ON U.UserId = UPD.UserId
	WHERE U.UserId = @UserId
		AND U.IsActive = 1
		AND U.IsApproved = 1
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetViewedProfiel]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			11/08/2020			CREATED -  For viewed profile 
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetViewedProfiel]
  (
	@UserId Int
  )
  AS
  BEGIN
	  SELECT 
	  PVS.ModifiedViewedOn,
	  U.CompanyName

	   FROM [dbo].[ProfileViewSummary] AS PVS
	  INNER JOIN
	  Users AS U
	  ON PVS.ViewerId = U.UserId
	  WHERE PVS.ViewedId = @UserId
  END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetViewedProfileDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetViewedProfileDetails]    
(    
 @EmpId INT    
)    
AS    
BEGIN    
 SELECT    
  U.UserId,    
  U.Candidateid,    
  U.FirstName,    
  U.LastName,    
  U.MobileNo,    
  U.Email,    
  G.Gender,    
  UPD.Skills,    
  UPD.CurrentSalary,    
  UPD.ExpectedSalary,    
  UPD.Resume,    
  CT.Name,    
  JT.[JobTitleName]    
 FROM dbo.Users U  
  INNER JOIN dbo.ProfileViewSummary PVS    
  ON PVS.ViewedId = U.UserId  
  LEFT JOIN dbo.Gender G    
  ON U.Gender = G.GenderCode    
  LEFT JOIN dbo.UserProfessionalDetails UPD    
  ON U.UserId = UPD.UserId         
  LEFT JOIN [dbo].[JobTitle] AS JT    
  ON JT.JobTitleId = UPD.JobTitleId    
  LEFT JOIN [dbo].[Cities] AS CT    
  ON CT.CityCode = U.City    
 WHERE PVS.ViewerId= @EmpId    
  AND U.IsActive = 1    
END   



GO
/****** Object:  StoredProcedure [dbo].[usp_GetWalkinJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			10/08/2020			Created - Getting Walk-in Jobs   
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetWalkinJobs]
AS
BEGIN
WITH CTE_GetRecentsJobs AS
	(
	SELECT  TOP 4    
		JP.JobPostId,
		JP.JobTitleByEmployer,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.[CompanyName] AS CompanyName,
		JP.CTC AS CTC,
		DATEDIFF(DAY, JP.CreatedDate, GETDATE()) AS NumberOfDays
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId

		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id

	WHERE ISNULL(R.ID,0) !=1
	AND U.IsActive=1
	AND JP.IsWalkIn = 1
	ORDER BY JP.CreatedDate DESC
	)
	SELECT
		DISTINCT
		JobPostId,
		STUFF(
		(
			SELECT 
				', ' + JobTitle
			FROM CTE_GetRecentsJobs CTE2
			WHERE CTE1.JobPostId = CTE2.JobPostId
			FOR XML PATH('')),1,2,''
		) AS JobTitle,
		JobTitleByEmployer,
		EmploymentStatus,
		City,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		CTC,
		NumberOfDays
	FROM CTE_GetRecentsJobs CTE1
	Order BY
	NumberOfDays ASC
END

-------------5-------------------

GO
/****** Object:  StoredProcedure [dbo].[usp_InsertAppliedJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_InsertAppliedJobs]
(
	@userId INT,
	@jobPostId INT
)
AS BEGIN
  IF NOT EXISTS(SELECT 1 FROM [AppliedJobs] WHERE JobPostId=@jobPostId AND UserId = @userId) 
   BEGIN
		INSERT INTO [dbo].[AppliedJobs]
		(
			UserId,
			JobPostId,
			AppliedDate,
			[Status],
			CreatedBy,
			CreatedDate
		)
		VALUES
		(
			@userId,
			@jobPostId,
			GETDATE(),
			1,
			@userId,
			GETDATE()
		)
		END
		
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertBulkJobPostSummaryDetail]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE proc [dbo].[usp_InsertBulkJobPostSummaryDetail]
(
	@SerialNo INT,
	@CompanyName VARCHAR(250), 
	@State VARCHAR(70),
	@JobLocation VARCHAR(70),
	@JobTitle VARCHAR(200),
	@SPOC VARCHAR(200),
	@SPOCEmail VARCHAR(100),
	@SPOCContact VARCHAR(15),
	@CTC VARCHAR(15),
	@HiringCriteria VARCHAR(MAX),
	@MinExp VARCHAR(5),
	@MaxExp VARCHAR(5),
	@JobType VARCHAR(75),
	@JobDetails VARCHAR(MAX),
	@Total INT,
	@ProcessedBy VARCHAR(200),
	@ProcessedOn DATETIME,
	@Status VARCHAR(25),
	@ErrorDetails VARCHAR(max),
	@FileName VARCHAR(500),
	@CreatedBy INT
)
AS
BEGIN
	INSERT INTO dbo.BulkJobPostSummary
	(

		SerialNo,
		CompanyName, 
		[State],
		JobLocation,
		JobTitle,
		SPOC,
		SPOCEmail,
		SPOCContact,
		CTC,
		HiringCriteria,
		MinExp,
		MaxExp,
		JobType,
		JobDetails,
		Total,
		ProcessedBy,
		ProcessedOn,
		[Status],
		ErrorDetails,
		[FileName],
		CreatedBy
	)
	VALUES
	(
		@SerialNo,
		@CompanyName, 
		@State,
		@JobLocation,
		@JobTitle,
		@SPOC,
		@SPOCEmail,
		@SPOCContact,
		@CTC,
		@HiringCriteria,
		@MinExp,
		@MaxExp,
		@JobType,
		@JobDetails,
		@Total,
		@ProcessedBy,
		@ProcessedOn,
		@Status,
		@ErrorDetails,
		@FileName,
		@CreatedBy
	)
END




GO
/****** Object:  StoredProcedure [dbo].[usp_InsertCity]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
Create PROC [dbo].[usp_InsertCity]
(
	@CityName VARCHAR (50),
	@StateCode VARCHAR(5),
	@CityCode VARCHAR(15)  = NULL OUT
)
AS
BEGIN
	DECLARE @IsCityExist BIT = 1	
	SELECT 
		@CityCode = CityCode
	FROM dbo.Cities 
	WHERE Name = @CityName;

	IF(ISNULL(@CityCode,'') = '')
	BEGIN
		SET @IsCityExist = 0
	END

	DECLARE @CityCodeLength INT = 2
	WHILE(@IsCityExist = 0)
	BEGIN
		SET @CityCode = UPPER(SUBSTRING(@CityName,1,@CityCodeLength))
		IF NOT EXISTS
		(
			SELECT
				1
			FROM dbo.Cities 
			WHERE CityCode = @CityCode
		)
		BEGIN
			INSERT INTO dbo.Cities
			(
				CityCode,
				Name,
				StateCode,
				IsActive
			)
			VALUES
			(
				@CityCode,
				@CityName,
				@StateCode,
				1
			)
			SET @IsCityExist = 1
		END
		ELSE
		BEGIN
			SET @CityCodeLength = @CityCodeLength + 1
		END
	END
END



GO
/****** Object:  StoredProcedure [dbo].[USP_InsertEducationalDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[USP_InsertEducationalDetails]
(
	@educationalDetails VARCHAR(MAX),
	@userId INT
)
AS BEGIN	
	IF NOT EXISTS 
	(
	   SELECT ID
	   FROM UserProfessionalDetails
	   WHERE UserId=@userId
	)
	BEGIN
		INSERT INTO [dbo].[UserProfessionalDetails]
		(
			EducationalDetails,
			UserId,
			CreatedDate,
			CreatedBy
		)
		VALUES
		(
			@educationalDetails,
			@userId,
			GETDATE(),
			@userId
		)
	END
	ELSE
	BEGIN
		UPDATE [dbo].[UserProfessionalDetails]
			SET EducationalDetails = @educationalDetails,
			UpdatedDate = GETDATE(),
			UpdatedBy = @userId
		WHERE UserId = @userId
	END
END




GO
/****** Object:  StoredProcedure [dbo].[usp_InsertEmailQueueData]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertEmailQueueData]
(
	@From NVARCHAR(50),
	@To NVARCHAR(50),
	@Subject NVARCHAR(1000),
	@Body NVARCHAR(3999),
	@CreatedBy INT,
	@mailType INT
)
AS
BEGIN
	DECLARE @FromId INT = NULL,@ToId INT = NULL

	SELECT
		@FromId = UserId
	From dbo.Users
	WHERE Email = @From

	SELECT
		@ToId = UserId
	From dbo.Users
	WHERE Email = @To

	INSERT INTO dbo.EmailQueue
	(
		FromId,
		ToId,
		Subject,
		Body,
		CreatedBy,
		FromEmail,
		ToEmail,
		MailType
	)
	VALUES
	(
		@FromId,
		@ToId,
		@Subject,
		@Body,
		@CreatedBy,
		@From,
		@To,
		@mailType
	)
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertEmpDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_InsertEmpDetails]
(	
	@companyName VARCHAR(120)= NULL,
	@contactPerson VARCHAR(50)= NULL,
	@email VARCHAR(120)= NULL,
	@phone VARCHAR(50)= NULL,
	@firstname VARCHAR(100)= NULL,
	@password VARCHAR(100)= NULL,
	@address VARCHAR(100)= NULL,
	@profile VARCHAR(100)= NULL,
	@userId int,
	@Gender VARCHAR(10)=NULL,
	@MaritalStatus VARCHAR(50) Null
)
AS BEGIN	
	IF NOT EXISTS 
	(
	   SELECT UserId
	   FROM UserRoles
	   WHERE UserId=@userId
	)
	BEGIN
		INSERT INTO [dbo].[Users]
		(
			FirstName,
			Email,
			CompanyName,			
			[Password],
			CreatedOn
		)
		VALUES
		(
			@firstName,
			@email,
			@companyName,			
			@password,
			GETDATE()
		)
	END
	ELSE
	BEGIN
		IF (ISNULL(@profile,'') <>'')
		BEGIN
			UPDATE [dbo].[Users]
				SET CompanyName = @companyName,
				ContactPerson = @contactPerson,
				Address1 = @address,
				MobileNo = @phone,
				ProfilePic = @profile,
			   [UpdatedBy] =@userId,
			   [UpdatedOn] = GETDATE(),
			   [Gender]	= @Gender,
			   [MaritalStatus] = @MaritalStatus
			WHERE UserId = @userId
		END
		ELSE
		BEGIN
			UPDATE [dbo].[Users]
				SET CompanyName = @companyName,
				ContactPerson = @contactPerson,
				Address1 = @address,
				MobileNo = @phone,
				[UpdatedBy] =@userId,
				[UpdatedOn] = GETDATE(),
				[Gender]	= @Gender,
				[MaritalStatus] = @MaritalStatus
			WHERE UserId = @userId
		END
	END
END






GO
/****** Object:  StoredProcedure [dbo].[usp_InsertEmployerFollower]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertEmployerFollower] 
(
@EmployerId INT,
@JobSeekerId INT 
)
AS
BEGIN
	  IF EXISTS (SELECT ID FROM EmployerFollower WHERE JobSeekerID = @JobSeekerId AND EmployerID=@EmployerId)
		BEGIN
        Update EmployerFollower SET IsActive = 1 WHERE JobSeekerID = @JobSeekerId AND EmployerID=@EmployerId
		END
	ELSE
		BEGIN
			INSERT INTO EmployerFollower
			(
				JobSeekerID,
				EmployerID,
				CreatedDate,
				IsActive
			)
			VALUES
			(
				@JobSeekerId,
				@EmployerId,
				GETDATE(),
				1
			)
		END
END
GO
/****** Object:  StoredProcedure [dbo].[USP_InsertExperienceDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[USP_InsertExperienceDetails]
(
	@experienceDetails VARCHAR(MAX),
	@userId INT
)
AS BEGIN
	IF NOT EXISTS 
	(
	   SELECT ExperienceDetails
	   FROM UserProfessionalDetails
	   WHERE UserId=@userId
	)
	BEGIN
		INSERT INTO [dbo].[UserProfessionalDetails]
		(
			ExperienceDetails,
			UserId,
			CreatedDate,
			CreatedBy
		)
		VALUES
		(
			@experienceDetails,
			@userId,
			GETDATE(),
			@userId
		)
	END
	ELSE
	BEGIN
		UPDATE [dbo].[UserProfessionalDetails]
			SET ExperienceDetails = @experienceDetails,
			UpdatedDate = GETDATE(),
			UpdatedBy = @userId
		WHERE UserId = @userId
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertIntOptDate]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertIntOptDate]
(
@Otp Varchar(MAX),
@Email Varchar(MAX)
)
AS
BEGIN
	INSERT INTO [dbo].[OTPData]
	(
		[EmailID],
		[OTP],
		[CreatedDate],
		[IsUsed]
	)
	Values
	(
		@Email,
		@Otp,
		GETDATE(),
		1
	)
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertJobPost]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
--sp_helptext usp_InsertJobPost


CREATE PROCEDURE [dbo].[usp_InsertJobPost]
(
	@CTC VARCHAR(50),
	@CityCode NVARCHAR(15),
	@CountryCode NVARCHAR(5),
	@CreatedBy NVARCHAR(50),
	@EmploymentStatusId INT,
	@EmploymentTypeId INT,
	@Gender VARCHAR(10),
	@HiringCriteria NVARCHAR(MAX),
	@Jobdetails VARCHAR(MAX),
	@JobIndustryAreaId INT,	
	@OtherJobIndustryArea VARCHAR(100),
	@JobTitleId NVARCHAR(MAX),
	@JobType INT,
	@MonthlySalary NVARCHAR(50),
	@Nationality NVARCHAR(10),
	@NoPosition INT,
	@IsWalkInJob BIT,
	@PositionStartDate NVARCHAR(50),
	@PositionEndDate NVARCHAR(50),
	@Quarter1 INT = 0,
	@Quarter2 INT = 0,
	@Quarter3 INT = 0,
	@Quarter4 INT = 0,
	@Spoc VARCHAR(50),
	@SpocContact VARCHAR(15),
	@SpocEmail VARCHAR(50),
	@StateCode NVARCHAR(5),	
	@PostedTo int,
	@Skills VARCHAR(MAX),
	@JobTitleByEmployer NVARCHAR(255),
	@MinExp INT,
	@MaxExp INT,
	@FinancialYear INT,
	@IsFromBulkUpload BIT
)
AS 
BEGIN
	--	Validate Job....................
	SELECT
		val AS value
	INTO #TempJobRoles
	FROM F_SPLIT(@JobTitleId,',')

	IF EXISTS
		(
			SELECT
				1
			FROM dbo.JobPostDetail JPD
				INNER JOIN dbo.JobRoleMapping JRM
				ON JPD.JobPostId = JRM.JobId
			WHERE JPD.UserId = @PostedTo
				AND JPD.CountryCode = @CountryCode
				AND JPD.StateCode = @StateCode
				AND JPD.CityCode = @CityCode
				AND JPD.CTC = @CTC
				AND JPD.Quarter1 = @Quarter1
				AND JPD.Quarter2 = @Quarter2
				AND JPD.Quarter3 = @Quarter3
				AND JPD.Quarter4 = @Quarter4
				AND JPD.JobDetails = @Jobdetails
				AND JPD.FinancialYear = @FinancialYear
				AND JRM.JobRoleId IN (SELECT value FROM #TempJobRoles)
		)
		BEGIN
			RAISERROR('This job already exist',11,1)
			RETURN
		END

	--..................................

	DECLARE @LastInsertedJobId INT

	INSERT INTO JobPostDetail
	(
		JobIndustryAreaId,
		OtherJobIndustryArea,
		CountryCode,
		StateCode,
		CityCode,
		EmploymentStatusId,
		--JobTitleId,
		EmploymentTypeId ,
		MonthlySalary,
		NoPosition,
		IsWalkIn,
		Nationality,
		PositionStartDate,
		PositionEndDate,
		HiringCriteria,
		[Status],
		CreatedBy,
		CreatedDate,
		JobType,
		Gender,
		JobDetails,
		UserId,
		SPOC,
		SPOCEmail,
		SPOCContact,
		CTC,
		Quarter1,
		Quarter2,
		Quarter3,
		Quarter4,
		Skills,
		JobTitleByEmployer,
		MinExperience,
		MaxExperience,
		FinancialYear,
		IsFromBulkUpload
	)
	VALUES
	(
		CASE WHEN @JobIndustryAreaId < 1 THEN 4 ELSE @JobIndustryAreaId END,
		@OtherJobIndustryArea, 
		@CountryCode,
		@StateCode,
		@CityCode,
		CASE WHEN @EmploymentStatusId < 1 THEN 5 ELSE @EmploymentStatusId END,
		--@JobTitleId,
		CASE WHEN @EmploymentTypeId < 1 THEN NULL ELSE @EmploymentTypeId END,
		@MonthlySalary,
		@NoPosition ,
		@IsWalkInJob,
		@Nationality ,
		@PositionStartDate ,
		@PositionEndDate ,
		@HiringCriteria, 
		1,
		@CreatedBy,
		GETDATE(),
		@JobType,
		@Gender,
		@Jobdetails,
		@PostedTo,
		@Spoc,
		@SpocEmail,
		@SpocContact,
		@CTC,
		@Quarter1, 
		@Quarter2, 
		@Quarter3, 
		@Quarter4,
		ISNULL(@Skills,''),
		@JobTitleByEmployer,
		@MinExp,
		@MaxExp,
		@FinancialYear,
		@IsFromBulkUpload
	)

	SELECT @LastInsertedJobId = IDENT_CURRENT('JobPostDetail')

		INSERT INTO dbo.JobRoleMapping
		(
			JobId,
			JobRoleId
		)
		SELECT
			@LastInsertedJobId,
			value
		FROM #TempJobRoles

	DROP TABLE #TempJobRoles
END


GO
/****** Object:  StoredProcedure [dbo].[usp_InsertJobPost0403]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_InsertJobPost0403]
(
	@CTC VARCHAR(50),
	@CityCode NVARCHAR(15),
	@CountryCode NVARCHAR(5),
	@CreatedBy NVARCHAR(50),
	@EmploymentStatusId INT,
	@EmploymentTypeId INT,
	@Gender VARCHAR(10),
	@HiringCriteria NVARCHAR(MAX),
	@Jobdetails VARCHAR(MAX),
	@JobIndustryAreaId INT,	
	@OtherJobIndustryArea VARCHAR(100),
	@JobTitleId NVARCHAR(MAX),
	@JobType INT,
	@MonthlySalary NVARCHAR(50),
	@Nationality NVARCHAR(10),
	@NoPosition INT,
	@PositionStartDate NVARCHAR(50),
	@PositionEndDate NVARCHAR(50),
	@Quarter1 INT,
	@Quarter2 INT,
	@Quarter3 INT,
	@Quarter4 INT,
	@Spoc VARCHAR(50),
	@SpocContact VARCHAR(15),
	@SpocEmail VARCHAR(50),
	@StateCode NVARCHAR(5),	
	@PostedTo int,
	@Skills VARCHAR(MAX),
	@JobTitleByEmployer NVARCHAR(255),
	@MinExp INT,
	@MaxExp INT,
	@FinancialYear INT,
	@IsFromBulkUpload BIT
)
AS 
BEGIN
	--	Validate Job....................
	SELECT
		val AS value
	INTO #TempJobRoles
	FROM F_SPLIT(@JobTitleId,',')

	IF EXISTS
		(
			SELECT
				1
			FROM dbo.JobPostDetail JPD
				INNER JOIN dbo.JobRoleMapping JRM
				ON JPD.JobPostId = JRM.JobId
			WHERE JPD.UserId = @PostedTo
				AND JPD.CountryCode = @CountryCode
				AND JPD.StateCode = @StateCode
				AND JPD.CityCode = @CityCode
				AND JPD.CTC = @CTC
				AND JPD.Quarter1 = @Quarter1
				AND JPD.Quarter2 = @Quarter2
				AND JPD.Quarter3 = @Quarter3
				AND JPD.Quarter4 = @Quarter4
				AND JPD.JobDetails = @Jobdetails
				AND JPD.FinancialYear = @FinancialYear
				AND JRM.JobRoleId IN (SELECT value FROM #TempJobRoles)
		)
		BEGIN
			RAISERROR('This job already exist',11,1)
			RETURN
		END

	--..................................

	DECLARE @LastInsertedJobId INT

	INSERT INTO JobPostDetail
	(
		JobIndustryAreaId,
		OtherJobIndustryArea,
		CountryCode,
		StateCode,
		CityCode,
		EmploymentStatusId,
		--JobTitleId,
		EmploymentTypeId ,
		MonthlySalary,
		NoPosition,
		Nationality,
		PositionStartDate,
		PositionEndDate,
		HiringCriteria,
		[Status],
		CreatedBy,
		CreatedDate,
		JobType,
		Gender,
		JobDetails,
		UserId,
		SPOC,
		SPOCEmail,
		SPOCContact,
		CTC,
		Quarter1,
		Quarter2,
		Quarter3,
		Quarter4,
		Skills,
		JobTitleByEmployer,
		MinExperience,
		MaxExperience,
		FinancialYear,
		IsFromBulkUpload
	)
	VALUES
	(
		CASE WHEN @JobIndustryAreaId < 1 THEN 4 ELSE @JobIndustryAreaId END,
		@OtherJobIndustryArea, 
		@CountryCode,
		@StateCode,
		@CityCode,
		CASE WHEN @EmploymentStatusId < 1 THEN 5 ELSE @EmploymentStatusId END,
		--@JobTitleId,
		CASE WHEN @EmploymentTypeId < 1 THEN NULL ELSE @EmploymentTypeId END,
		@MonthlySalary,
		@NoPosition ,
		@Nationality ,
		@PositionStartDate ,
		@PositionEndDate ,
		@HiringCriteria, 
		1,
		@CreatedBy,
		GETDATE(),
		@JobType,
		@Gender,
		@Jobdetails,
		@PostedTo,
		@Spoc,
		@SpocEmail,
		@SpocContact,
		@CTC,
		@Quarter1, 
		@Quarter2, 
		@Quarter3, 
		@Quarter4,
		ISNULL(@Skills,''),
		@JobTitleByEmployer,
		@MinExp,
		@MaxExp,
		@FinancialYear,
		@IsFromBulkUpload
	)

	SELECT @LastInsertedJobId = IDENT_CURRENT('JobPostDetail')

		INSERT INTO dbo.JobRoleMapping
		(
			JobId,
			JobRoleId
		)
		SELECT
			@LastInsertedJobId,
			value
		FROM #TempJobRoles

	DROP TABLE #TempJobRoles
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertPlacedCandidate]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*  
-------------------------------------------------------------------------------------------------  
SR   By   Date			Remarks  
1    SR   26/03/2020    	Created - To Insert Data Into PlacedCandidateDetails
-------------------------------------------------------------------------------------------------  
*/

CREATE PROC [dbo].[usp_InsertPlacedCandidate]
(
	@SumofCandidateContactNo VARCHAR(250),
	@CandidateEmail VARCHAR(250),
	@CandidateID VARCHAR(250),
	@CandidateName VARCHAR(250),
	@Castecategory VARCHAR(250), 
	@CertificateDate VARCHAR(250),
	@Certified VARCHAR(250),
	@EmployerspocEmail VARCHAR(250),
	@EmployerspocMobile VARCHAR(250),
	@EmployerType VARCHAR(250),
	@EmployerSpocName VARCHAR(250),
	@FirstEmploymentCreatedDate VARCHAR(250),
	@FromDate VARCHAR(250),
	@FYWise VARCHAR(250),
	@Gender VARCHAR(250),
	@Jobrole VARCHAR(250),
	@AvgofNoofdaysbetweennDOCDOP VARCHAR(250),
	@AverageofNoOfMonthsofPlacement VARCHAR(250),
	@OrganisationDistrict VARCHAR(250),
	@OrganisationState VARCHAR(250),
	@OrganizationAddress VARCHAR(250),
	@OrganizationName VARCHAR(250),
	@PartnerName VARCHAR(250),
	@PartnerSPOCMobile VARCHAR(250), 
	@PartnerSPOCName VARCHAR(250),
	@CountofPartnerID VARCHAR(250),
	@SumofSalleryPerMonth VARCHAR(250),
	@PartnerSPOCEmail VARCHAR(250),
	@CountofSCTrainingCentreID VARCHAR(250),
	@SectorName VARCHAR(250),
	@SelfEmployedDistrict VARCHAR(250),
	@SelfEmployedState VARCHAR(250),
	@TCDistrict VARCHAR(250),
	@TCSPOCEmail VARCHAR(250),
	@SumofTCSPOCMobile VARCHAR(250),
	@TCSPOCName VARCHAR(250),
	@TCState VARCHAR(250),
	@ToDate VARCHAR(250),
	@TrainingCentreName VARCHAR(250),
	@TrainingType VARCHAR(250),
	@EducationAttained VARCHAR(250),	
	@CreatedBy VARCHAR(250)
)
AS
BEGIN
	IF EXISTS(SELECT UserId FROM dbo.Users Where Candidateid = @CandidateID AND IsHired = 0 AND ISNULL(@CandidateID,'')<>'')
	BEGIN
		UPDATE dbo.Users SET 
		IsHired = 1 WHERE Candidateid = @CandidateID
	END
	IF NOT EXISTS(SELECT Id FROM dbo.PlacedCandidateDetails WHERE Candidateid = @CandidateID)
	BEGIN
		INSERT INTO dbo.PlacedCandidateDetails
		(
			SumofCandidateContactNo,
			CandidateEmail,
			CandidateID,
			CandidateName,
			Castecategory, 
			CertificateDate,
			Certified ,
			EmployerspocEmail ,
			EmployerspocMobile,
			EmployerType ,
			EmployerSpocName ,
			FirstEmploymentCreatedDate ,
			FromDate ,
			FYWise ,
			Gender ,
			Jobrole ,
			AvgofNoofdaysbetweennDOCDOP ,
			AverageofNoOfMonthsofPlacement ,
			OrganisationDistrict ,
			OrganisationState ,
			OrganizationAddress ,
			OrganizationName ,
			PartnerName ,
			PartnerSPOCMobile , 
			PartnerSPOCName ,
			CountofPartnerID ,
			SumofSalleryPerMonth ,
			PartnerSPOCEmail ,
			CountofSCTrainingCentreID ,
			SectorName ,
			SelfEmployedDistrict ,
			SelfEmployedState ,
			TCDistrict ,
			TCSPOCEmail ,
			SumofTCSPOCMobile ,
			TCSPOCName ,
			TCState ,
			ToDate ,
			TrainingCentreName ,
			TrainingType ,
			EducationAttained ,
			CreatedDate ,
			CreatedBy
		)
		VALUES
		(
			@SumofCandidateContactNo,
			@CandidateEmail,
			@CandidateID,
			@CandidateName,
			@Castecategory, 
			@CertificateDate,
			@Certified ,
			@EmployerspocEmail ,
			@EmployerspocMobile,
			@EmployerType ,
			@EmployerSpocName ,
			@FirstEmploymentCreatedDate ,
			@FromDate ,
			@FYWise ,
			@Gender ,
			@Jobrole ,
			@AvgofNoofdaysbetweennDOCDOP ,
			@AverageofNoOfMonthsofPlacement ,
			@OrganisationDistrict ,
			@OrganisationState ,
			@OrganizationAddress ,
			@OrganizationName ,
			@PartnerName ,
			@PartnerSPOCMobile , 
			@PartnerSPOCName ,
			@CountofPartnerID ,
			@SumofSalleryPerMonth ,
			@PartnerSPOCEmail ,
			@CountofSCTrainingCentreID ,
			@SectorName ,
			@SelfEmployedDistrict ,
			@SelfEmployedState ,
			@TCDistrict ,
			@TCSPOCEmail ,
			@SumofTCSPOCMobile ,
			@TCSPOCName ,
			@TCState ,
			@ToDate ,
			@TrainingCentreName ,
			@TrainingType ,
			@EducationAttained ,
			GETDATE() ,
			@CreatedBy
		)
	END

END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertProfileSummary]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_InsertProfileSummary]
(
	@profile VARCHAR(MAX),
	@userId INT
)
AS BEGIN	
	IF NOT EXISTS 
	(
	   SELECT ID
	   FROM UserProfessionalDetails
	   WHERE UserId=@userId
	)
	BEGIN
		INSERT INTO [dbo].[UserProfessionalDetails]
		(
			ProfileSummary,
			UserId,
			CreatedDate,
			CreatedBy
		)
		VALUES
		(
			@profile,
			@userId,
			GETDATE(),
			@userId
		)
	END
	ELSE
	BEGIN
		UPDATE [dbo].[UserProfessionalDetails]
			SET ProfileSummary = @profile,
			UpdatedDate = GETDATE(),
			UpdatedBy = @userId
		WHERE UserId = @userId
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertProfileViewSummary]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertProfileViewSummary]
(
	@ViewerId INT,
	@ViewedId INT
)
AS
BEGIN
	IF EXISTS
		(
			SELECT
				1
			FROM dbo.ProfileViewSummary
			WHERE ViewerId = @ViewerId
				AND ViewedId = @ViewedId
		)
	BEGIN
		UPDATE dbo.ProfileViewSummary
			SET ModifiedViewedOn = GETDATE()
		WHERE ViewerId = @ViewerId
			AND ViewedId = @ViewedId
	END
	ELSE
	BEGIN
		INSERT INTO dbo.ProfileViewSummary
		(
			ViewerId,
			ViewedId
		)
		VALUES
		(
			@ViewerId,
			@ViewedId
		)
	END
END





GO
/****** Object:  StoredProcedure [dbo].[usp_InsertSkillsDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_InsertSkillsDetails]
(
	@skillDetails VARCHAR(MAX),
	@userId INT
)
AS BEGIN	
	IF NOT EXISTS 
	(
	   SELECT ID
	   FROM UserProfessionalDetails
	   WHERE UserId=@userId
	)
	BEGIN
		INSERT INTO [dbo].[UserProfessionalDetails]
		(
			Skills,
			UserId,
			CreatedDate,
			CreatedBy
		)
		VALUES
		(
			@skillDetails,
			@userId,
			GETDATE(),
			@userId
		)
	END
	ELSE
	BEGIN
		UPDATE [dbo].[UserProfessionalDetails]
			SET Skills = @skillDetails,
			UpdatedDate = GETDATE(),
			UpdatedBy = @userId
		WHERE UserId = @userId
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertState]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertState]
(
	@StateName VARCHAR (50),
	@CountryCode VARCHAR(5),
	@StateCode VARCHAR(5)  = NULL OUT
)
AS
BEGIN
	DECLARE @IsStateExist BIT = 1	
	SELECT 
		@StateCode = StateCode
	FROM dbo.States 
	WHERE Name = @StateName

	IF(ISNULL(@StateCode,'') = '')
	BEGIN
		SET @IsStateExist = 0
	END

	DECLARE @StateCodeLength INT = 2
	WHILE(@IsStateExist = 0)
	BEGIN
		SET @StateCode = UPPER(SUBSTRING(@StateName,1,@StateCodeLength))
		IF NOT EXISTS
		(
			SELECT
				1
			FROM dbo.States 
			WHERE StateCode = @StateCode
		)
		BEGIN
			INSERT INTO dbo.States
			(
				StateCode,
				Name,
				CountryCode,
				IsActive
			)
			VALUES
			(
				@StateCode,
				@StateName,
				@CountryCode,
				1
			)
			SET @IsStateExist = 1
		END
		ELSE
		BEGIN
			SET @StateCodeLength = @StateCodeLength + 1
		END
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertStateDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_InsertStateDetails]
(
	@countryCode NVARCHAR(5),
	@stateCode NVARCHAR(50),
	@stateName NVARCHAR(50)
)
AS 
BEGIN
	INSERT INTO States
	(
		CountryCode,
		StateCode,
		Name,
		IsActive
	)
	VALUES
	(
	@countryCode,
	@stateCode,
	@stateName,
	1
	)	
END


GO
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateJobTitle]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_InsertUpdateJobTitle]
	@JobTitleId int,
	@JobTitleName NVARCHAR(MAX),
	@UpdatedBy NVARCHAR(50)
AS 
BEGIN
	DECLARE @JobId INT
	SELECT @JobId =  JobTitleId from JobTitle where JobTitleId=@JobTitleId
 if(@JobId IS NOT NULL)
 Begin
	UPDATE JobTitle
	SET 
	JobTitleName=@JobTitleName,
	[UpdatedBy] = @UpdatedBy,
	[UpdatedDate] = GETDATE()
	WHERE 
	JobTitleId=@JobTitleId
	END
	ELSE
	BEGIN
	INSERT INTO JobTitle
	(
	JobTitleName,
	[Status],
	[CreatedBy],
	[CreatedDate]
	)
	Values
	(
	@JobTitleName,
	1,
	@UpdatedBy,
	GETDATE()
	)
	END
END






GO
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateSuccessStoryVid]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			15/01/2020			Created - Insert and update ssuccessStoryVid SP
-------------------------------------------------------------------------------------------------
*/
CREATE PROCEDURE [dbo].[usp_InsertUpdateSuccessStoryVid]
	@SSId INT,
	@SSTitle VARCHAR(MAX) NULL,
	@SSFileName VARCHAR(MAX) NULL,
	@SSType VARCHAR(MAX) = NULL,
	@UpdatedBy Varchar(MAX) = NULL,
	@DisplayOrder int = NULL
AS 
BEGIN
	DECLARE @ID INT
	SELECT @ID =  Id from [dbo].[SuccessStoryVideo] where [Id]=@SSId
 if(@ID IS NOT NULL)
 Begin
	UPDATE [dbo].[SuccessStoryVideo]
	SET 
	[Title]=@SSTitle,
	[FileName] = @SSFileName,
	[Type] = @SSType,
	[UpdatedBy] = @UpdatedBy,
	[UpdatedDate] = GETDATE(),
	[DisplayOrder]=@DisplayOrder
	WHERE 
	[Id]=@SSId
	END
	ELSE
	BEGIN
	INSERT INTO [dbo].[SuccessStoryVideo]
	(
	[Title],
	[FileName],
	[Type],
	[CreatedBy],
	[CreatedDate],
	[Status],
	[DisplayOrder]
	)
	Values
	(
	@SSTitle,
	@SSFileName,
	@SSType,
	@UpdatedBy,
	GETDATE(),
	1,
	@DisplayOrder
	)
	END
END







GO
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateUserEducationDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertUpdateUserEducationDetails]
(
	@UserId INT,
	@EduDetails VARCHAR(MAX)
)
AS
BEGIN
	UPDATE dbo.UserProfessionalDetails
		SET EducationalDetails = @EduDetails,
		UpdatedDate = GETDATE(),
		UpdatedBy = @UserId
	WHERE UserId = @UserId
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateUserExperienceDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertUpdateUserExperienceDetails]
(
	@UserId INT,
	@ExpDetails VARCHAR(MAX),
	@Skills VARCHAR(MAX)
)
AS
BEGIN
	UPDATE dbo.UserProfessionalDetails
		SET ExperienceDetails = @ExpDetails,
		Skills = @Skills,
		UpdatedDate = GETDATE(),
		UpdatedBy = @UserId
	WHERE UserId = @UserId
END




GO
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateUserPersonalDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertUpdateUserPersonalDetails]
(
	@userId INT,
	@FirstName NVARCHAR(20),
	@LastName NVARCHAR(20),
	@MaritalStatus NVARCHAR(10),
	@Gender VARCHAR(8),
	@Email NVARCHAR(50),
	@Address1 NVARCHAR(100),
	@Address2 NVARCHAR(100),
	@Address3 NVARCHAR(100),
	@City NVARCHAR(50),
	@Country NVARCHAR(25),
	@DOB VARCHAR(50),
	@State NVARCHAR(50),
	@MobileNo NVARCHAR(15)
)
AS
BEGIN
	BEGIN TRY
		BEGIN TRAN
			UPDATE dbo.Users
				SET FirstName = @FirstName,
				LastName = @LastName,
				MaritalStatus = @MaritalStatus,
				Gender = @Gender,
				Email = @Email,
				Address1 = @Address1,
				Address2 = @Address2,
				Address3 = @Address3,
				City = @City,
				Country = @Country,
				State = @State,
				MobileNo = @MobileNo,
				UpdatedOn = GETDATE(),
				UpdatedBy = @userId
			WHERE UserId = @userId

			IF EXISTS
			(
				SELECT
					1
				FROM dbo.UserProfessionalDetails
				WHERE UserId = @userId
			)
			BEGIN
				UPDATE dbo.UserProfessionalDetails
					SET DateOfBirth = @DOB,
					UpdatedBy = @userId,
					UpdatedDate = GETDATE()
				WHERE UserId = @userId
			END
			ELSE
			BEGIN
				INSERT INTO dbo.UserProfessionalDetails
				(
					UserId,
					DateOfBirth,
					CreatedBy,
					CreatedDate
				)
				VALUES
				(
					@userId,
					@DOB,
					@userId,
					GETDATE()
				)
			END

		COMMIT TRAN
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN
		-- Some exception Stuff will be here
	END CATCH

END




GO
/****** Object:  StoredProcedure [dbo].[usp_InsertUserProfessionalDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[usp_InsertUserProfessionalDetails]
(
	@userId INT,	
	@currentSalary VARCHAR(50),
	@expectedSalary VARCHAR(50),
	@dateOfBirth VARCHAR(50),	
	@aboutMe VARCHAR(MAX),	
	@status VARCHAR(50),
	@email NVARCHAR(50),	
	@mobileNo NVARCHAR(15),
	@address VARCHAR(MAX),
	@maritalStatus VARCHAR(10),
	@gender VARCHAR(8),
	@jobCategory INT,
	@employmentStatus INT,
	@country VARCHAR(25),
	@state VARCHAR(50),
	@city VARCHAR(50),
	@jobTitleId INT = 0,
	@TotalExperience VARCHAR(5) = '0.0',
	@LinkedinProfile VARCHAR(MAX)
)
AS
BEGIN
	BEGIN TRY
       BEGIN TRANSACTION
		IF(ISNULL(@employmentStatus,'')='') -- Rev 2
		BEGIN
			SET @employmentStatus=5
		END

	   --insert or update UserProfessionalDetails table--
		  IF NOT EXISTS 
			(
				SELECT UserId
				FROM dbo.UserProfessionalDetails
				WHERE UserId = @userId 
			)
			BEGIN
				INSERT INTO dbo.UserProfessionalDetails
				(
					UserId,	
					CurrentSalary,
					ExpectedSalary,
					DateOfBirth,		
					AboutMe,		
					[Status],
					EmploymentStatusId,
					JobIndustryAreaId,
					CreatedDate,
					CreatedBy,
					TotalExperience,
					LinkedinProfile,
					JobTitleId
				)
				VALUES
				(
					@userId,
					@currentSalary,
					@expectedSalary,
					@dateOfBirth,
					@aboutMe,
					@status,
					@employmentStatus,		
					@jobCategory,
					GETDATE(),
					@userId,
					@TotalExperience,
					@LinkedinProfile,
					@jobTitleId
				)	
			END
			ELSE		
				BEGIN
					UPDATE dbo.UserProfessionalDetails
					SET			
						CurrentSalary = @currentSalary,
						ExpectedSalary = @expectedSalary,
						DateOfBirth = @dateOfBirth,			
						AboutMe =@aboutMe,		
						EmploymentStatusId = @employmentStatus,
						JobIndustryAreaId = @jobCategory,	
						[Status] = @status,
						UpdatedDate = GETDATE(),
						TotalExperience = @TotalExperience,
						UpdatedBy = @userId,
						LinkedinProfile=@LinkedinProfile,
						JobTitleId = @jobTitleId
					WHERE UserId = @userId
				 END	

			-- insert and update users table ---			
			UPDATE dbo.Users
			SET			
				Email = @email,
				Address1 = @address,
				City = @city,			
				[State] = @state,		
				Country = @country,
				MaritalStatus = @maritalStatus,
				Gender = @gender,
				MobileNo = @mobileNo,			
				UpdatedOn = GETDATE(),
				UpdatedBy = @userId
			WHERE UserId = @userId		
		COMMIT	
	END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
         ROLLBACK

      -- Raise an error with the details of the exception
      DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int
      SELECT @ErrMsg = ERROR_MESSAGE(),
             @ErrSeverity = ERROR_SEVERITY()

      RAISERROR(@ErrMsg, @ErrSeverity, 1)
    END CATCH
END 


GO
/****** Object:  StoredProcedure [dbo].[usp_JobSeekerAppliedJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			11/08/2020			CREATED -  For getting job seeker applied jobs 
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_JobSeekerAppliedJobs] 
(
@UserId INT
)
AS
BEGIN
WITH CTE_GetAppliedJobs AS
	(
	SELECT   
		JP.JobPostId,
		JP.JobTitleByEmployer,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.[CompanyName] AS CompanyName,
		JP.CTC AS CTC,
		DATEDIFF(DAY, JP.CreatedDate, GETDATE()) AS NumberOfDays,
		JP.CreatedDate
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId

		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.Id
		INNER JOIN dbo.AppliedJobs AS APJ
		ON
		APJ.JobPostId = JP.JobPostId


	WHERE ISNULL(R.ID,0) !=1
	AND U.IsActive=1
	AND APJ.UserId = @UserId
	AND APJ.[Status] = 1
	)
	SELECT
		DISTINCT
		JobPostId,
		STUFF(
		(
			SELECT 
				', ' + JobTitle
			FROM CTE_GetAppliedJobs CTE2
			WHERE CTE1.JobPostId = CTE2.JobPostId
			FOR XML PATH('')),1,2,''
		) AS JobTitle,
		JobTitleByEmployer,
		EmploymentStatus,
		City,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		CTC,
		NumberOfDays,
		CreatedDate
	FROM CTE_GetAppliedJobs CTE1
	Order BY
	NumberOfDays ASC
END

GO
/****** Object:  StoredProcedure [dbo].[usp_JobSeekerJobsAlert]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_JobSeekerJobsAlert]
(
@UserId INT,
@JobAlert INT
)
AS
BEGIN
Update UserProfessionalDetails
 SET 
	IsJobAlert = @JobAlert
  WHERE UserId=@UserId 
END
GO
/****** Object:  StoredProcedure [dbo].[usp_PostSuccessStory]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR  		By			Date				Remarks
1			SR			14/01/2020			Created - For posting success story
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_PostSuccessStory] 
(
	@Name varchar(max),
	@Email varchar(max),
	@Message varchar(max),
	@UserId INT
)
AS
BEGIN
  INSERT INTO [dbo].[SuccessSotry] 
	(
	[Name],
	[Email],
	[Message],
	[CreatedBy],
	[CreatedDate],
	[Status],
	[UserId]
	)
	VALUES 
	(
	@Name,
	@Email, 
	@Message, 
	@Name,
	GETDATE(), 
	1,
	@UserId
	)
END



GO
/****** Object:  StoredProcedure [dbo].[usp_RecommendedJobsOnRole]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_RecommendedJobsOnRole] 
(
@roleId INT
)
AS
BEGIN
--DECLARE @JobTitleID int = 
	WITH CTE_GetFeeaturedJobs AS
	(
	SELECT  
		JP.JobPostId,
		JP.JobTitleByEmployer,
		JP.CreatedDate AS CreatedDate,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.[CompanyName] AS CompanyName
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.JobIndustryArea JA
		ON JP.JobIndustryAreaId=JA.JobIndustryAreaId
		LEFT JOIN dbo.Users U
		ON JP.UserId = U.UserId
		LEFT JOIN dbo.Users U2
		ON JP.CreatedBy = U2.UserId
		LEFT JOIN dbo.UserRoles UR
		ON U2.UserId = UR.UserId
		LEFT JOIN dbo.Roles R
		ON UR.RoleId = R.ID
	WHERE 
		(
			JT.JobTitleId = @roleId
			OR
			JT.JobTitleId = JT.JobTitleId
		)
		AND
		R.ID IN (3,4) 
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020 
		AND CAST( ISNULL(JP.PositionEndDate,'01/01/2900') AS Date)>=cast(GETDATE() AS DATE)
	)
	SELECT
		DISTINCT
		JobPostId,
		STUFF(
		(
			SELECT 
				', ' + JobTitle
			FROM CTE_GetFeeaturedJobs CTE2
			WHERE CTE1.JobPostId = CTE2.JobPostId
			FOR XML PATH('')),1,2,''
		) AS JobTitle,
		JobTitleByEmployer,
		EmploymentStatus,
		City,
		HiringCriteria,
		CompanyLogo,
		CompanyName,
		CreatedDate
	FROM CTE_GetFeeaturedJobs CTE1
	ORDER BY CTE1.CreatedDate  DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_RegisterEmployer]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[usp_RegisterEmployer]
(
	@CompanyName NVARCHAR(MAX),
	@Email NVARCHAR(50),
	@Password NVARCHAR(MAX),
	@RoleId INT,
	@profilepic VARCHAR(100),
	@isRegisterOnlyForDemandAggregationData BIT,
	@IsApproved BIT,
	@IsActive BIT
)
AS
	BEGIN
		BEGIN TRY
			IF EXISTS
			(
				SELECT
					1
				FROM dbo.Users
				WHERE CompanyName = @CompanyName
			)
			BEGIN
				UPDATE dbo.Users
					SET FirstName = @CompanyName,
						Email = @Email,
						Password = @Password,
						PasswordExpiryDate = (GETDATE()+30),
						ProfilePic = @profilepic,
						UpdatedOn = GETDATE(),
						IsRegisterOnlyForDemandAggregationData = @isRegisterOnlyForDemandAggregationData
				WHERE CompanyName = @CompanyName
			END
			ELSE
			BEGIN
				INSERT INTO dbo.Users
				(
					FirstName,
					Email,
					Password,
					CompanyName,
					PasswordExpiryDate,
					ProfilePic,
					CreatedOn,
					IsRegisterOnlyForDemandAggregationData,
					IsActive,
					IsApproved
				)
				VALUES
				(
					@CompanyName,
					@Email,
					@Password,
					@CompanyName,
					GETDATE()+30,
					@profilepic,
					GETDATE(),
					@isRegisterOnlyForDemandAggregationData,
					@IsActive,
					@IsApproved
				)
				DECLARE @UserId INT
				SET @UserId=@@IDENTITY

				INSERT INTO dbo.UserRoles
				(
					RoleId,
					UserId,
					Createddate,
					CreatedBy
				)
				VALUES
				(
					@RoleId,
					@UserId,
					GETDATE(),
					@UserId
				)
			END
			
	END TRY
	BEGIN CATCH
        SELECT  
             ERROR_NUMBER() AS ErrorNumber  
            ,ERROR_SEVERITY() AS ErrorSeverity  
            ,ERROR_STATE() AS ErrorState  
            ,ERROR_PROCEDURE() AS ErrorProcedure  
            ,ERROR_LINE() AS ErrorLine  
            ,ERROR_MESSAGE() AS ErrorMessage;  
    END CATCH
END


GO
/****** Object:  StoredProcedure [dbo].[usp_RegisterUser]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_RegisterUser]
(
	@Email VARCHAR(50),
	@FName VARCHAR(20),
	@LName VARCHAR(20),
	@MobileNo VARCHAR(15),
	@Password VARCHAR(MAX),
	@RoleId INT,
	@IsActive BIT,
	@ActivationKey VARCHAR(100),
	@OutUserId INT = 0 OUT,
	@CreatedBy INT,
	@IsApproved BIT
)
AS
BEGIN
	BEGIN TRY
		BEGIN TRAN
			INSERT INTO dbo.Users
			(
			
				FirstName,
				LastName,
				MobileNo,
				Email,
				[Password],
				PasswordExpiryDate,				
				IsActive,
				ActivationKey,
				CreatedBy,
				CreatedOn,
				IsApproved
			)
			VALUES
			(
				@FName,
				@LName,
				@MobileNo,
				@Email,
				@Password,
				GETDATE()+30,				
				@IsActive,
				@ActivationKey,
				@CreatedBy,
				GETDATE(),
				@IsApproved
			)

			SET @OutUserId=@@IDENTITY

			INSERT INTO dbo.UserRoles
			(
				RoleId,
				UserId,
				Createddate,
				CreatedBy
			)
			VALUES
			(

				@RoleId,
				@OutUserId,
			
	GETDATE(),
				@OutUserId
			)			
			
		COMMIT TRAN
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN
	END CATCH

END

--------2----------------

GO
/****** Object:  StoredProcedure [dbo].[usp_SearchBulkJobList]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_SearchBulkJobList]
(
	@CompanyId Int = 0,
	@FY VARCHAR(1000) = NULL,
	@statecode NVARCHAR(1000) = NULL,
	@citycode NVARCHAR(1000) = NULL
)
AS
BEGIN  
 ;WITH CTE_JobsOnRange AS  
 (  
 SELECT  
  JPD.JobPostId,  
  C.Name AS Country,  
  S.Name AS [State],  
  CT.Name AS City, 
  JTT.[Type] AS JobTypeSummary,  
  JPD.JobDetails,  
  JPD.CTC, 
  JPD.CreatedDate AS PostedOn,  
JPD.JobTitleByEmployer,
  U2.CompanyName 
 FROM dbo.JobPostDetail JPD  
  LEFT JOIN dbo.Countries C  
  ON JPD.CountryCode = C.CountryCode  
  LEFT JOIN dbo.States S  
  ON JPD.StateCode = S.StateCode  
  LEFT JOIN dbo.Cities CT  
  ON JPD.CityCode = CT.CityCode  
  LEFT JOIN dbo.JobRoleMapping JRM  
  ON JPD.JobPostId = JRM.JobId  
  LEFT JOIN dbo.JobTitle JT  
  ON JRM.JobRoleId = JT.JobTitleId  
  LEFT JOIN dbo.JobTypes JTT  
  ON JPD.JobType = JTT.Id

  LEFT JOIN dbo.Users U2
  ON JPD.UserId = U2.UserId
  
  LEFT JOIN dbo.Users U  
  ON JPD.CreatedBy = U.UserId  
  LEFT JOIN dbo.UserRoles UR  
  ON U.UserId = UR.UserId  
  LEFT JOIN dbo.Roles R  
  ON UR.RoleId = R.ID  
WHERE
	JPD.IsFromBulkUpload = 1
	AND
	JPD.[Status]=1
	AND
		(
			(
				ISNULL(@citycode,'') <> ''
				AND
				JPD.CityCode =@citycode
			)
			OR
			(
				ISNULL(@citycode,'') = ''
			)
		)
		AND
		(
			(
				ISNULL(@CompanyId,'') <> ''
				AND
				JPD.UserId IN (SELECT val FROM dbo.f_split(@CompanyId, ','))
			)
			OR
			(
				ISNULL(@CompanyId,'0') = ''
			)
		)
		AND
		(
			(
				ISNULL(@statecode,'') <> ''
				AND
				JPD.StateCode =@statecode
			)
			OR
			(
				ISNULL(@statecode,'') = ''
			)
		)
		AND
		(
			(
				ISNULL(@FY,'') <> ''
				AND
				JPD.FinancialYear =@FY
			)
			OR
			(
				ISNULL(@FY,'') = ''
			)
		)
 )  
  
 SELECT  
  DISTINCT  
  JobPostId,  
  Country,  
  [State],  
  City,  
  JobTypeSummary,  
  JobDetails,  
  CTC,  
	JobTitleByEmployer,
  CompanyName,
   PostedOn 
 FROM CTE_JobsOnRange  
 ORDER BY  
  PostedOn DESC  
END 



GO
/****** Object:  StoredProcedure [dbo].[usp_SearchCandidateDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[usp_SearchCandidateDetails]    
(    
 @employerId INT,    
 @jobSeekerId INT    
)    
AS    
BEGIN    
 BEGIN TRY    
  BEGIN TRAN    
   SELECT     
    FirstName,    
    LastName,    
    Email,     
    Skills,    
    [Resume],    
    JobIndustryAreaName,    
    CityCode,  
	CT.Name AS CityName,  
    U.UserId,    
    U.CreatedOn,    
    U.Address1,    
    U.[State],    
	ST.Name AS StateName,  
    U.Country,    
	Country.Name AS CountryName,  
    U.MobileNo,    
    U.ProfilePic,    
    UD.AboutMe,    
    ISNULL(UD.TotalExperience,0) AS TotalExperience,    
    UD.DateOfBirth,    
    Ud.CurrentSalary,    
    UD.ExpectedSalary,    
    UD.ExperienceDetails,    
    Ud.EducationalDetails,  
	UD.LinkedinProfile ,  
	JT.JobTitleName
   FROM Users AS U    
    LEFT JOIN UserProfessionalDetails AS UD    
    ON U.UserId = UD.UserId     
    LEFT JOIN JobIndustryArea AS JI     
    ON UD.JobIndustryAreaId = JI.JobIndustryAreaId    
    LEFT JOIN Cities AS CT     
    ON U.City = CT.CityCode    
	LEFT JOIN States AS ST  
	ON U.State= ST.StateCode  
	LEFT JOIN [dbo].[JobTitle] AS JT  
	ON UD.JobTitleId = JT.JobTitleId   
	LEFT JOIN [dbo].[Countries] AS Country  
    ON  
	U.Country = Country.CountryCode  
    WHERE U.UserId = @jobSeekerId    
    
   EXEC usp_InsertProfileViewSummary @employerId,@jobSeekerId    
    
  COMMIT TRAN    
 END TRY    
 BEGIN CATCH    
  ROLLBACK    
  DECLARE @ErrorMessage VARCHAR(MAX)    
  DECLARE @ErrorSeverity VARCHAR(MAX)    
  SELECT @ErrorMessage = ERROR_MESSAGE()    
  SELECT @ErrorSeverity = ERROR_SEVERITY()    
  RAISERROR(@ErrorMessage,@ErrorSeverity,1)    
 END CATCH    
END



GO
/****** Object:  StoredProcedure [dbo].[usp_SearchResume]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_SearchResume]
(  
	@Skills VARCHAR(1000) = NULL,  
	@JobIndustryAreaId VARCHAR(1000) = NULL,  
	@CityCode NVARCHAR(1000) = NULL,  
	@MinExp INT = -1,  
	@MaxExp INT = -1  
)  
AS  
BEGIN  
	SELECT   
		U.UserId,  
		U.FirstName,  
		U.LastName,  
		U.Email,  
		U.ProfilePic,  		
		UD.Skills,  
		UD.ExperienceDetails,
		UD.AboutMe,
		UD.[Resume],  
		JI.JobIndustryAreaName,  
		JT.JobTitleName,		
		CT.Name AS CityName,
		UD.CurrentSalary,
		UD.ExpectedSalary,
		UD.ProfileSummary,
		UD.LinkedinProfile,
		UD.TotalExperience
		--IT.Skill AS ITSkill		
	FROM dbo.Users AS U  
		INNER JOIN dbo.UserProfessionalDetails AS UD  
		ON U.UserId = UD.UserId
		INNER JOIN UserRoles AS UR  
		ON UR.UserId = U.UserId
		AND UR.RoleId = 2
		LEFT JOIN dbo.JobTitle AS JT
		ON JT.JobTitleId = UD.JobTitleId
		LEFT JOIN dbo.JobIndustryArea AS JI   
		ON UD.JobIndustryAreaId = JI.JobIndustryAreaId  
		LEFT JOIN dbo.Cities AS CT   
		ON U.City = CT.CityCode 
		--LEFT JOIN dbo.ITSkills IT
		--ON UD.UserId=IT.CreatedBy		
	WHERE (  
		  (  
		   ISNULL(@CityCode,'') <> ''  
		   AND  
		   CT.CityCode IN (SELECT val FROM dbo.f_split(@CityCode, ','))  
		  )  
		  OR  
		  (  
		   ISNULL(@CityCode,'') = ''  
		  )  
		 )  
		 AND  
		 (  
		  (  
		   ISNULL(@JobIndustryAreaId,'') <> ''  
		   AND  
		   JI.JobIndustryAreaId IN (SELECT val FROM dbo.f_split(@JobIndustryAreaId, ','))  
		  )  
		  OR  
		  (  
		   ISNULL(@JobIndustryAreaId,'') = ''  
		  )  
		 )  
		 AND  
		 (  
		  (  
		   ISNULL(@Skills,'') <> ''  
		   AND  
		   UD.Skills LIKE '%' + @Skills +'%'  
		  )
		  OR(
			ISNULL(@Skills,'') <> ''  
		   AND  
		   UD.ExperienceDetails LIKE '%' + @Skills +'%'  
		  )  		  
		 -- OR (
			--ISNULL(@Skills,'') <> ''  
			--AND
			--IT.Skill LIKE '%' + @Skills +'%'
		 -- )
		  OR  
		  (  
		   ISNULL(@Skills,'') = ''  
		  )
		 )  
		 AND  
		 (  
		  (  
		   @MinExp > -1  
		   AND  
		   @MaxExp = -1  
		   AND  
		   UD.TotalExperience >= @MinExp  
		  )  
		  OR  
		  (  
		   @MinExp = -1  
		   AND  
		   @MaxExp > -1  
		   AND  
		   UD.TotalExperience <= @MaxExp  
		  )  
		  OR  
		  (  
		   @MinExp > -1  
		   AND  
		   @MaxExp > -1  
		   AND  
		   UD.TotalExperience BETWEEN @MinExp AND @MaxExp  
		  )  
		  OR  
		  (  
		   @MinExp = -1  
		   AND  
		   @MaxExp = -1  
		  )  
		 ) 
		 
	ORDER BY
		CASE 
			WHEN U.CreatedOn IS NOT NULL THEN U.CreatedOn
			WHEN UD.CreatedDate IS NOT NULL THEN UD.CreatedDate
			WHEN U.UpdatedOn IS NOT NULL THEN U.UpdatedOn
			ELSE UD.UpdatedDate END
			DESC 
END 
GO
/****** Object:  StoredProcedure [dbo].[usp_UnfollowEmployerForJobseeker]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

 CREATE PROC [dbo].[usp_UnfollowEmployerForJobseeker]
(
@UserId INT,
@EmployerId INT
)
AS
BEGIN
UPDATE [dbo].[EmployerFollower]
	SET [IsActive] = 0
	WHERE [EmployerID] = @EmployerId
	AND [JobSeekerID]= @UserId
END


--------------------7--------------------

GO
/****** Object:  StoredProcedure [dbo].[usp_updateCandidateByUserid]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_updateCandidateByUserid]
(
	@userid INT,
	@firstname VARCHAR(200),
	@lastname VARCHAR(200),
	@password VARCHAR(200)
)
AS
BEGIN
	BEGIN
		UPDATE dbo.Users
		SET FirstName = @firstname,
			LastName = @lastname,
			Password = @password,
			UpdatedOn = GETDATE()
		WHERE UserId = @userid
	END
END




GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateCity]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*  
-------------------------------------------------------------------------------------------------  
SR   By   Date			Remarks  
1    SR   24/03/2020    Created - To update City data  
-------------------------------------------------------------------------------------------------  
*/
CREATE PROC [dbo].[usp_UpdateCity]
(
	@citycode varchar(100),
	@statecode varchar(100),
	@city varchar(200)
)
AS
BEGIN
	BEGIN
		UPDATE dbo.Cities
		SET StateCode=@statecode,
		Name = @city
		WHERE CityCode=@citycode
	END	
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateDesignation]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_UpdateDesignation]
(
	@id int,
	@designation VARCHAR(50),
	@abbr VARCHAR(30)
)
AS
BEGIN
	UPDATE Designations SET
	Designation = @designation , Abbr=@abbr WHERE DesignationId = @id
END







GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateFeaturedJobDisplayOrder]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			03/02/2020			Created - To Upadte display order of featuredjob
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_UpdateFeaturedJobDisplayOrder]
(
	@jobpostid int,
	@displayorder int 
)
AS
BEGIN
	UPDATE [dbo].[JobPostDetail]
	SET FeaturedJobDisplayOrder = @displayorder
	WHERE JobPostid = @jobpostid
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateITSkills]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			06/08/2020			Update - Inserting and updating IT Skills
-------------------------------------------------------------------------------------------------
*/
CREATE PROC[dbo].[usp_UpdateITSkills]
(
@ITSkillId INT,
@ITSkill VARCHAR(50),
@SkillVersion VARCHAR(50),
@LastUsed VARCHAR(10),
@ExperienceYear VARCHAR(10),
@ExperienceMonth VARCHAR(10),
@UserId INT
)
AS
BEGIN
	if(@ITSkillId=0)
		BEGIN
			INSERT INTO [dbo].[ITSkills]
			(
			[Skill],
			[SkillVersion],
			[LastUsed],
			[ExperienceYear],
			[ExperienceMonth],
			[CreatedBy],
			[CreatedDate],
			[Status]
			)
			VALUES
			(
			@ITSkill,
			@SkillVersion,
			@LastUsed,
			@ExperienceYear,
			@ExperienceMonth,
			@UserId,
			GETDATE(),
			1
			)
		END
	ELSE
		BEGIN
			UPDATE [dbo].[ITSkills]
			SET
			[Skill] = @ITSkill,
			[SkillVersion]=@SkillVersion,
			[LastUsed]=@LastUsed,
			[ExperienceYear]=@ExperienceYear,
			[ExperienceMonth]=@ExperienceMonth,
			[UpdateDate] = GETDATE(),
			[UpdatedBy] = @UserId
			WHERE Id = @ITSkillId
		END
END

--------3------------

GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateJobDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_UpdateJobDetails]
(
	@JobId INT,
	@CityCode NVARCHAR(15),
	@CountryCode NVARCHAR(5),
	@CTC VARCHAR(15),
	@UpdatedBy NVARCHAR(50),
	@HiringCriteria NVARCHAR(MAX),
	@Jobdetails NVARCHAR(MAX),
	@JobTitleId NVARCHAR(MAX),
	@JobType VARCHAR(50),
	@MonthlySalary NVARCHAR(50),
	@Quarter1 INT,
	@Quarter2 INT,
	@Quarter3 INT,
	@Quarter4 INT,
	@Spoc VARCHAR(50),
	@SpocContact VARCHAR(15),
	@SpocEmail VARCHAR(50),
	@StateCode NVARCHAR(5),
	@Feauterdjobs BIT,
	@DisplayOrder INT,
	@JobTitleByEmployer NVARCHAR(255),
	@PostingDate VARCHAR(MAX),
	@ExpiryDate VARCHAR(MAX),
	@FinancialYear VARCHAR(5)
)
AS 
BEGIN
BEGIN TRY
	BEGIN TRAN
		SELECT
			val AS value
		INTO #TempJobRoles
		FROM F_SPLIT(@JobTitleId,',')

		UPDATE dbo.JobPostDetail
			SET CountryCode = @CountryCode,
				StateCode = @StateCode,
				CityCode = @CityCode,
				MonthlySalary = @MonthlySalary,
				HiringCriteria = @HiringCriteria,
				UpdatedBy = @UpdatedBy,
				UpdatedDate = GETDATE(),
				JobType = @JobType,
				JobDetails = @JobDetails,
				SPOC = @Spoc,
				SPOCEmail = @SpocEmail,
				SPOCContact = @SpocContact,
				CTC = @CTC,
				Quarter1 = @Quarter1,
				Quarter2 = @Quarter2,
				Quarter3 = @Quarter3,
				Quarter4 = @Quarter4,
				Featured = @Feauterdjobs,
				JobTitleByEmployer = @JobTitleByEmployer,
				PositionStartDate = @PostingDate,
				PositionEndDate = @ExpiryDate,
				FinancialYear=@FinancialYear,
				FeaturedJobDisplayOrder = @DisplayOrder
			WHERE JobPostId = @JobId

		DELETE FROM dbo.JobRoleMapping
		WHERE JobId = @JobId

		INSERT INTO dbo.JobRoleMapping
		(
			JobId,
			JobRoleId
		)
		SELECT
			@JobId,
			value
		FROM #TempJobRoles

		DROP TABLE #TempJobRoles

	COMMIT TRAN
END TRY
BEGIN CATCH
	ROLLBACK
END CATCH
END


GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateJobIndustryArea]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_UpdateJobIndustryArea]
	@JobIndustryAreaId int,
	@JobIndustryAreaName NVARCHAR(MAX),
	@UpdatedBy NVARCHAR(50)=NULL
AS 
BEGIN
	DECLARE @IndustryId INT
	SELECT @IndustryId =  JobIndustryAreaId from JobIndustryArea where JobIndustryAreaId=@JobIndustryAreaId
 if(@IndustryId IS NOT NULL)
 Begin
	UPDATE JobIndustryArea
	SET 
	JobIndustryAreaName=@JobIndustryAreaName,
	[UpdatedBy] = @UpdatedBy,
	[UpdatedDate] = GETDATE()
	WHERE 
	JobIndustryAreaId=@JobIndustryAreaId
	END
	ELSE
	BEGIN
	INSERT INTO JobIndustryArea
	(
	JobIndustryAreaName,
	[Status],
	[CreatedDate]
	)
	Values
	(
	@JobIndustryAreaName,
	1,
	GETDATE()
	)
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateJobSeekerMailStatus]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_UpdateJobSeekerMailStatus]
(
	@MessageId INT,
	@UserId INT
)
AS
BEGIN
	DECLARE @CDate DATETIME = GETDATE();
	UPDATE dbo.EmailQueue
		SET IsReplied = 1,
			RepliedOn = @CDate,
			UpdatedBy = @UserId,
			UpdatedOn = @CDate
	WHERE Id = @MessageId
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UpdatePassword]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_UpdatePassword]
(
	@Email NVARCHAR(50),
	@Password NVARCHAR(MAX)
)
AS
BEGIN
	Update Users
	SET [Password] = @Password,
		UpdatedBy = 0,
		UpdatedOn =GETDATE()
    WHERE Email = @Email
END







GO
/****** Object:  StoredProcedure [dbo].[usp_UpdatePopularSearches]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_UpdatePopularSearches] 
(
	@jobCategory VARCHAR(1000) = NULL,
	@city VARCHAR(1000) = NULL,
	@jobTitle INT = 0,
	@experience INT = 0,
	@user INT = 0
)
AS
BEGIN
	IF(ISNULL(@jobCategory,'') <> '')
	BEGIN
		IF EXISTS
		(
			SELECT
				1
			FROM dbo.PopularJobSearches
			WHERE FilterName =  'JobCategory'
				AND FilterValue IN (SELECT TOP 1 val FROM dbo.f_split(@jobCategory, ','))
		)
		BEGIN
			UPDATE dbo.PopularJobSearches
				SET Count = Count+1,
				UpdatedBy = @user,
				UpdatedDate = GETDATE()
			WHERE FilterName =  'JobCategory'
				AND FilterValue IN (SELECT TOP 1 val FROM dbo.f_split(@jobCategory, ','))
		END
		ELSE
		BEGIN
			INSERT INTO dbo.PopularJobSearches
			(
				FilterName,
				FilterValue,
				Count,
				CreatedBy,
				CreatedDate
			)
			VALUES
			(
				'JobCategory',
				(SELECT TOP 1 val FROM dbo.f_split(@jobCategory, ',')),
				1,
				@user,
				GETDATE()
			)
		END

	END
	IF(ISNULL(@city,'') <> '')
	BEGIN
		IF EXISTS
		(
			SELECT
				1
			FROM dbo.PopularJobSearches
			WHERE FilterName =  'City'
				AND FilterValue IN (SELECT TOP 1 val FROM dbo.f_split(@city, ','))
		)
		BEGIN
			UPDATE dbo.PopularJobSearches
				SET Count = Count+1,
				UpdatedBy = @user,
				UpdatedDate = GETDATE()
			WHERE FilterName =  'City'
				AND FilterValue IN (SELECT TOP 1 val FROM dbo.f_split(@city, ','))
		END
		ELSE
		BEGIN
			INSERT INTO dbo.PopularJobSearches
			(
				FilterName,
				FilterValue,
				Count,
				CreatedBy,
				CreatedDate
			)
			VALUES
			(
				'City',
				(SELECT TOP 1 val FROM dbo.f_split(@city, ',')),
				1,
				@user,
				GETDATE()
			)
		END
	END
	IF(@jobTitle > 0)
	BEGIN
		IF EXISTS
		(
			SELECT
				1
			FROM dbo.PopularJobSearches
			WHERE FilterName =  'JobRole'
				AND FilterValue = CAST(@jobTitle AS VARCHAR(100))
		)
		BEGIN
			UPDATE dbo.PopularJobSearches
				SET Count = Count+1,
				UpdatedBy = @user,
				UpdatedDate = GETDATE()
			WHERE FilterName =  'JobRole'
				AND FilterValue = CAST(@jobTitle AS VARCHAR(100))
		END
		ELSE
		BEGIN
			INSERT INTO dbo.PopularJobSearches
			(
				FilterName,
				FilterValue,
				Count,
				CreatedBy,
				CreatedDate
			)
			VALUES
			(
				'JobRole',
				@jobTitle,
				1,
				@user,
				GETDATE()
			)
		END
	END
	IF(ISNULL(@experience,'') <> '')
	BEGIN
		IF EXISTS
		(
			SELECT
				1
			FROM dbo.PopularJobSearches
			WHERE FilterName =  'Experience'
				AND FilterValue = @experience
		)
		BEGIN
			UPDATE dbo.PopularJobSearches
				SET Count = Count+1,
				UpdatedBy = @user,
				UpdatedDate = GETDATE()
			WHERE FilterName =  'Experience'
				AND FilterValue = @experience
		END
		ELSE
		BEGIN
			INSERT INTO dbo.PopularJobSearches
			(
				FilterName,
				FilterValue,
				Count,
				CreatedBy,
				CreatedDate
			)
			VALUES
			(
				'Experience',
				@experience,
				1,
				@user,
				GETDATE()
			)
		END
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateState]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_UpdateState]
(
	@countryCode NVARCHAR(5),
	@stateCode NVARCHAR(50),
	@stateName NVARCHAR(50)
	)
AS 
BEGIN
	UPDATE States 
	SET
		StateCode=@stateCode,
		Name=@stateName
		WHERE
		CountryCode=@countryCode
		AND
		StateCode=@stateCode
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateSuccessStory]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR		By		Date			Remarks
1		SR		02/06/2020		Created - For updating the success story
-------------------------------------------------------------------------------------------------
*/
CREATE PROCEDURE [dbo].[usp_UpdateSuccessStory] 
(
	@Id int, 
	@name VARCHAR(100), 
	@Email VARCHAR(100), 
	@Tagline VARCHAR(Max), 
	@Message VARCHAR(MAX),
	@UserId int
)
AS 
BEGIN 

UPDATE 
  [dbo].[SuccessSotry] 
SET 
  [Name] = @name, 
  [Email] = @Email, 
  [TagLine] = @Tagline, 
  [Message] = @Message, 
  [UpdatedBy] = @UserId, 
  [UpdatedDate] = GETDATE() 
WHERE 
  Id = @Id 
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateTPDetails]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_UpdateTPDetails]
(
	@userid INT,
	@firstname VARCHAR(100),
	@lastname VARCHAR(100),
	@email VARCHAR(100),
	@picture VARCHAR(200)
)
AS
BEGIN
	Update dbo.Users
	SET FirstName=@firstname,
		LastName = @lastname,
		Email = @email,
		ProfilePic=@picture,
		UpdatedOn = GETDATE()
	WHERE UserId = @userid 
END




GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateUserData]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*    
-------------------------------------------------------------------------------------------------    
SR   By   Date			Remarks    
1    SR   30/03/2020    	Created - To Update ManageUsers Data
-------------------------------------------------------------------------------------------------    
*/ 
CREATE PROCEDURE [dbo].[usp_UpdateUserData] 
(
 @id INT,  
 @firstname VARCHAR(64),  
 @lastname VARCHAR(64)=NULL,  
 @email VARCHAR(64)=NULL,  
 @RoleId INT=NULL,  
 @psd VARCHAR(64)=NULL  
 )
AS   
BEGIN  
 BEGIN TRY  
  BEGIN TRAN  
   UPDATE dbo.Users  
   SET FirstName=@firstname ,  
   LastName = @lastname,  
  -- Password = @psd,  
   --Email = @email ,  
   UpdatedOn = GETDATE(),  
   UpdatedBy = @id  
   WHERE userid=@id  
  
    
   --UPDATE UserRoles SET   
   -- RoleId=@RoleId  
    --WHERE userid=@id  
 COMMIT TRAN  
 END TRY  
 BEGIN CATCH  
  ROLLBACK TRAN  
 END CATCH  
END  


GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateUsersAsAdminViewed]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_UpdateUsersAsAdminViewed]
AS
BEGIN
	UPDATE dbo.Users
	SET IsViewedByAdmin = 1
	WHERE IsViewedByAdmin = 0
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UploadProfilePicture]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_UploadProfilePicture]
(
	@UserId INT,
	@fName VARCHAR(MAX)
)
AS BEGIN	
	IF NOT EXISTS 
	(
	   SELECT UserId
	   FROM dbo.Users
	   WHERE UserId=@UserId
	)
	BEGIN
		INSERT INTO [dbo].[Users]
		(
			[ProfilePic],
			UserId,
			CreatedOn,
			CreatedBy
		)
		VALUES
		(
			@fName,
			@userId,
			GETDATE(),
			@UserId
		)
	END
	ELSE
	BEGIN
		UPDATE [dbo].[Users]
			SET [ProfilePic] = @fName,
			UpdatedOn = GETDATE(),
			UpdatedBy = @UserId
		WHERE UserId = @UserId
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UploadResume]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_UploadResume]
(
	@UserId INT,
	@fName VARCHAR(MAX)
)
AS BEGIN	
	IF NOT EXISTS 
	(
	   SELECT ID
	   FROM UserProfessionalDetails
	   WHERE UserId=@UserId
	)
	BEGIN
		INSERT INTO [dbo].[UserProfessionalDetails]
		(
			[Resume],
			UserId,
			CreatedBy,
			CreatedDate
		)
		VALUES
		(
			@fName,
			@userId,
			@UserId,
			GETDATE()
		)
	END
	ELSE
	BEGIN
		UPDATE [dbo].[UserProfessionalDetails]
			SET [Resume] = @fName,
			UpdatedBy = @UserId,
			UpdatedDate = GETDATE()
		WHERE UserId = @UserId
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UserActivity]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			03/03/2020			Created - To Add the user activity
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_UserActivity]
(
	@userid int
)
AS
BEGIN
	INSERT INTO dbo.[UserActivity]
	(
		UserId,
		LoginDateTime
	)
	VALUES
	(
		@userid,
		GETDATE()
	)
END



GO
/****** Object:  StoredProcedure [dbo].[usp_UserLogin]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_UserLogin]    
(    
 @Email NVARCHAR(50),    
 @Password NVARCHAR(MAX)    
)    
AS    
BEGIN    
 SELECT    
  U.UserId,    
  U.FirstName,    
  U.LastName,      
  U.MobileNo,    
  U.Email,    
  U.PasswordExpiryDate,    
  U.[Password],    
  R.RoleName,    
  U.CompanyName,    
  U.IsApproved,    
  U.ProfilePic,  
  U.Address1,
  U.Address2,
  U.Address3,
  ISNULL(JT.JobTitleId,0) AS JobTitleId,    
  JT.JobTitleName    
 FROM dbo.Users AS U    
  LEFT JOIN UserRoles AS UR    
   ON U.UserId = UR.UserId    
  INNER JOIN Roles AS R    
   ON UR.RoleId = R.ID      
   LEFT JOIN dbo.UserProfessionalDetails UD
   ON U.UserId = UD.UserId
  LEFT JOIN dbo.JobTitle JT    
   ON UD.JobTitleId = JT.JobTitleId    
 WHERE U.Email = @Email    
  AND U.[Password] = @Password COLLATE Latin1_General_CS_AS    
  AND U.IsActive = 1    
END



GO
/****** Object:  StoredProcedure [dbo].[usp_VerifyEmailUsingActivationKey]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_VerifyEmailUsingActivationKey]
(
	@UserId INT,
	@ActivationKey VARCHAR(100)
)
AS
BEGIN
	IF EXISTS
	(
		SELECT
			1
		FROM dbo.Users
		WHERE UserId = @UserId
		AND ActivationKey = @ActivationKey
	)
	BEGIN
		UPDATE dbo.Users
			SET IsActive = 1
		WHERE UserId = @UserId
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_VerifyOTP]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_VerifyOTP] 
(
@OTP VARCHAR(MAX),
@Email VARCHAR(MAX)
)
AS
BEGIN
	SELECT
	 * 
	 FROM 
	 [dbo].[OTPData] 
	 WHERE 
	 OTP = @OTP 
	 AND 
	 EmailID = @Email
END





GO
/****** Object:  StoredProcedure [dbo].[usp_ViewAllFeaturedJobs]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE PROC [dbo].[usp_ViewAllFeaturedJobs]
AS
BEGIN
  WITH CTE_GetFeeaturedJobs
  AS (SELECT
    JP.JobPostId,
    JP.JobTitleByEmployer,
    JP.FeaturedJobDisplayOrder,
    JT.JobTitleName AS JobTitle,
    ES.EmploymentStatusName AS EmploymentStatus,
    C.Name AS City,
    JP.HiringCriteria AS HiringCriteria,
    U.[ProfilePic] AS CompanyLogo,
    U.[CompanyName] AS CompanyName,
    JP.CreatedDate
  FROM dbo.JobPostDetail AS JP
  LEFT JOIN dbo.EmploymentStatus AS ES
    ON JP.EmploymentStatusId = ES.EmploymentStatusId
  LEFT JOIN dbo.Cities AS C
    ON JP.CityCode = C.CityCode
  LEFT JOIN dbo.JobRoleMapping JRM
    ON JP.JobPostId = JRM.JobId
  LEFT JOIN dbo.JobTitle AS JT
    ON JRM.JobRoleId = JT.JobTitleId
  LEFT JOIN dbo.JobIndustryArea JA
    ON JP.JobIndustryAreaId = JA.JobIndustryAreaId
  LEFT JOIN dbo.Users U
    ON JP.UserId = U.UserId

  LEFT JOIN dbo.Users U2
    ON JP.CreatedBy = U2.UserId
  LEFT JOIN dbo.UserRoles UR
    ON U2.UserId = UR.UserId
  LEFT JOIN dbo.Roles R
    ON UR.RoleId = R.Id

  WHERE JP.Featured = 1
  AND JP.FeaturedJobDisplayOrder <= 20
  AND ISNULL(R.ID, 0) != 1
  AND U.IsActive = 1  --- To exclude deleted user 06/12/2020
  )
  SELECT
  DISTINCT TOP 20
    JobPostId,
    STUFF((SELECT
      ', ' + JobTitle
    FROM CTE_GetFeeaturedJobs CTE2
    WHERE CTE1.JobPostId = CTE2.JobPostId
    FOR xml PATH ('')), 1, 2, ''
    ) AS JobTitle,
    JobTitleByEmployer,
    EmploymentStatus,
    City,
    HiringCriteria,
    CompanyLogo,
    CompanyName,
    CreatedDate,
    FeaturedJobDisplayOrder
  FROM CTE_GetFeeaturedJobs CTE1
  ORDER BY CreatedDate
END

GO
/****** Object:  StoredProcedure [dbo].[usp_WriteToDB]    Script Date: 8/28/2020 10:24:44 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			01/30/2020			Created - For Logging
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_WriteToDB]
(
	@userid int,
	@logtype VARCHAR(30),
	@message VARCHAR(500),
	@data VARCHAR(Max)=NULL,
	@exception VARCHAR(Max)=NULL,
	@asseblyinfo VARCHAR(200)=NULL,
	@classinfo VARCHAR(200)=NULL
)
AS
BEGIN
	INSERT INTO Logging
	(
		LogType ,
		Message,
		Data,
		Exception,
		AssemblyInfo,
		ClassInfo,
		CreatedDate, 
		CreatedBy
	)
	VALUES
	(	
		@logtype,
		@message,
		@data,
		@exception,
		@asseblyinfo,
		@classinfo,
		GETDATE(),--CONVERT(TIME, GETDATE()),
		@userid
	)
END



GO
USE [master]
GO
ALTER DATABASE [JobPortalSR] SET  READ_WRITE 
GO
