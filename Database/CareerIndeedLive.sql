USE [master]
GO
/****** Object:  Database [CareerIndeedLive]    Script Date: 10/6/2020 12:07:02 PM ******/
CREATE DATABASE [CareerIndeedLive]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'CareerIndeedLive', FILENAME = N'D:\rdsdbdata\DATA\CareerIndeedLive.mdf' , SIZE = 5120KB , MAXSIZE = UNLIMITED, FILEGROWTH = 10%)
 LOG ON 
( NAME = N'CareerIndeedLive_log', FILENAME = N'D:\rdsdbdata\DATA\CareerIndeedLive_log.ldf' , SIZE = 3136KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
ALTER DATABASE [CareerIndeedLive] SET COMPATIBILITY_LEVEL = 120
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [CareerIndeedLive].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [CareerIndeedLive] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET ARITHABORT OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [CareerIndeedLive] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [CareerIndeedLive] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET  DISABLE_BROKER 
GO
ALTER DATABASE [CareerIndeedLive] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [CareerIndeedLive] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET RECOVERY FULL 
GO
ALTER DATABASE [CareerIndeedLive] SET  MULTI_USER 
GO
ALTER DATABASE [CareerIndeedLive] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [CareerIndeedLive] SET DB_CHAINING OFF 
GO
ALTER DATABASE [CareerIndeedLive] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [CareerIndeedLive] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
ALTER DATABASE [CareerIndeedLive] SET DELAYED_DURABILITY = DISABLED 
GO
USE [CareerIndeedLive]
GO
/****** Object:  User [steeprise]    Script Date: 10/6/2020 12:07:06 PM ******/
CREATE USER [steeprise] FOR LOGIN [steeprise] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_owner] ADD MEMBER [steeprise]
GO
/****** Object:  UserDefinedFunction [dbo].[f_split]    Script Date: 10/6/2020 12:07:08 PM ******/
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
/****** Object:  UserDefinedFunction [dbo].[parseJSON]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  UserDefinedFunction [dbo].[udf_PivotParameters]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  UserDefinedFunction [dbo].[udf_Split]    Script Date: 10/6/2020 12:07:09 PM ******/
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


GO
/****** Object:  UserDefinedFunction [dbo].[UTC2Indian]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[Advertisements]    Script Date: 10/6/2020 12:07:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Advertisements](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[ImageUrl] [varchar](max) NULL,
	[Section] [int] NULL,
	[Order] [int] NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[UpdatedBy] [int] NULL,
	[UpdatedDate] [datetime] NULL,
	[IsActive] [bit] NULL,
	[JobPage] [varchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[AppliedJobs]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[BulkJobPostSummary]    Script Date: 10/6/2020 12:07:09 PM ******/
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
	[CreatedOn] [datetime] NULL,
	[CreatedBy] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Cities]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[Countries]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[CourseCategories]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[Courses]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[CourseType]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[Designations]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[DownloadProfileHistory]    Script Date: 10/6/2020 12:07:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[DownloadProfileHistory](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NULL,
	[JobSeekerIds] [varchar](max) NULL,
	[FileUrl] [varchar](200) NULL,
	[CreatedBY] [int] NULL,
	[CreatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[EmailQueue]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[EmployerAdvanceSearch]    Script Date: 10/6/2020 12:07:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[EmployerAdvanceSearch](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserId] [int] NOT NULL,
	[HiringRequirement] [varchar](max) NULL,
	[AnyKeyword] [varchar](max) NULL,
	[AllKeyword] [varchar](max) NULL,
	[ExculudeKeyword] [varchar](max) NULL,
	[MinExperience] [int] NULL,
	[MaxExperience] [int] NULL,
	[MinSalary] [varchar](20) NULL,
	[MaxSalary] [varchar](20) NULL,
	[CurrentLocation] [varchar](10) NULL,
	[PreferredLocation1] [varchar](10) NULL,
	[PreferredLocation2] [varchar](10) NULL,
	[PreferredLocation3] [varchar](10) NULL,
	[FuncationlArea] [int] NULL,
	[JobIndustryAreaId] [int] NULL,
	[CurrentDesignation] [varchar](50) NULL,
	[NoticePeriod] [varchar](10) NULL,
	[Skills] [varchar](max) NULL,
	[AgeFrom] [int] NULL,
	[AgeTo] [int] NULL,
	[Gender] [varchar](20) NULL,
	[CandidatesType] [varchar](20) NULL,
	[ShowCandidateSeeking] [int] NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
	[IsSavedSearch] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[EmployerFollower]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[EmploymentStatus]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[EmploymentType]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[Gender]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[ITSkills]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[JobIndustryArea]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[JobPostDetail]    Script Date: 10/6/2020 12:07:09 PM ******/
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
	[IsDraft] [bit] NOT NULL CONSTRAINT [CONS_DraftNOTNULL]  DEFAULT ((0)),
 CONSTRAINT [PK__JobPostD__57689C3A625A8D56] PRIMARY KEY CLUSTERED 
(
	[JobPostId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[JobRoleMapping]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[JobTitle]    Script Date: 10/6/2020 12:07:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[JobTitle](
	[JobTitleId] [int] IDENTITY(1,1) NOT NULL,
	[JobTitleName] [nvarchar](max) NULL,
	[Status] [bit] NULL DEFAULT ((1)),
	[JobIndustryAreaId] [int] NOT NULL,
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
/****** Object:  Table [dbo].[JobTypes]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[LoggedInUsers]    Script Date: 10/6/2020 12:07:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[LoggedInUsers](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[SessionId] [varchar](max) NULL,
	[Userdata] [varchar](max) NULL,
	[CreatedAt] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Logging]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[MailType]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[MaritalStatus]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[Modules]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[Organizations]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[OTPData]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[PlacedCandidateDetails]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[PopularJobSearches]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[PreferredLocation]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[ProfileViewSummary]    Script Date: 10/6/2020 12:07:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ProfileViewSummary](
	[SummaryId] [int] IDENTITY(1,1) NOT NULL,
	[ViewerId] [int] NULL,
	[ViewedId] [int] NULL,
	[ViewedOn] [datetime] NULL,
	[ModifiedViewedOn] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[SummaryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Roles]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[SearchJobHistory]    Script Date: 10/6/2020 12:07:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SearchJobHistory](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserIP] [varchar](100) NULL,
	[Location] [varchar](max) NULL,
	[JobSeekerId] [int] NULL,
	[SearchCriteria] [varchar](max) NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[SearchResumeHistory]    Script Date: 10/6/2020 12:07:09 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[SearchResumeHistory](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserIP] [varchar](100) NULL,
	[Location] [varchar](max) NULL,
	[EmployerId] [int] NULL,
	[SearchCriteria] [varchar](max) NULL,
	[CreatedBy] [int] NULL,
	[CreatedDate] [datetime] NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[States]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[SuccessSotry]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[SuccessStoryVideo]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[UserActivity]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[UserProfessionalDetails]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[UserRoles]    Script Date: 10/6/2020 12:07:09 PM ******/
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
/****** Object:  Table [dbo].[Users]    Script Date: 10/6/2020 12:07:09 PM ******/
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
	[JobPortalTPID] [varchar](max) NULL,
	[PasswordHash] [varbinary](max) NULL,
	[PasswordSalt] [varbinary](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[UserId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  UserDefinedFunction [dbo].[TotalMonthCount]    Script Date: 10/6/2020 12:07:09 PM ******/
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
INSERT [dbo].[Cities] ([CityCode], [Name], [IsActive], [StateCode]) VALUES (N'Noida', N'GautamBuddha Nagar', 1, N'UP')
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

INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (1, NULL, 2, N'Welcome in careerindeed.in!', N'<b>Hi Career</b>,<br/><br/>Thank You for signing up with careerindeed.in. We are delighted to have you on board.<br/><br/>Your login details are below:<br/><br/>User Name: hrcareerindeed@gmail.com<br>Password: A7kb7<br/><br/>You can update your contact and registration details at any time by logging on to https://careerindeed.in/<br/><br/>See you on board!<br/><a href=https://httpslocalhost:44319/Auth/EmployerLogin> CareerIndeed</a> Team', 0, NULL, -1, CAST(N'2020-10-05 19:06:01.333' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'hrcareerindeed@gmail.com', 5)
INSERT [dbo].[EmailQueue] ([Id], [FromId], [ToId], [Subject], [Body], [IsReplied], [RepliedOn], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [FromEmail], [ToEmail], [MailType]) VALUES (2, NULL, 3, N'Welcome to careerindeed.in', N'<b>Dear Sunil</b>,<br/><br/>Congratulations! You have successfully registered with careerindeed.in<br/><br/>Please note that your username and password are both case sensitive.<br/><br/>Your login details are below:<br/><br/>User Name: sunilkumardec15@gmail.com<br>Password: Admin@123<br/><br/>You can update your contact and registration details at any time by logging on to careerindeed.in<br/><br/>Wish you all the best!<br/><a href=https://httpslocalhost:44319/Auth/JobSeekerLogin> CareerIndeed</a> Team', 0, NULL, -1, CAST(N'2020-10-06 05:46:55.710' AS DateTime), NULL, NULL, N'nasscomtestmail@gmail.com', N'sunilkumardec15@gmail.com', 5)
SET IDENTITY_INSERT [dbo].[EmailQueue] OFF
SET IDENTITY_INSERT [dbo].[EmploymentStatus] ON 

INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'Full Time', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, N'Part Time', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (3, N'Free Lancer', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (4, N'Contract', 1, NULL, NULL, NULL, NULL)
INSERT [dbo].[EmploymentStatus] ([EmploymentStatusId], [EmploymentStatusName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (5, N'Not Disclosed', 1, NULL, NULL, NULL, NULL)
SET IDENTITY_INSERT [dbo].[EmploymentStatus] OFF
SET IDENTITY_INSERT [dbo].[Gender] ON 

INSERT [dbo].[Gender] ([GenderId], [GenderCode], [Gender], [IsActive]) VALUES (1, N'male', N'Male', 1)
INSERT [dbo].[Gender] ([GenderId], [GenderCode], [Gender], [IsActive]) VALUES (2, N'female', N'Female', 1)
INSERT [dbo].[Gender] ([GenderId], [GenderCode], [Gender], [IsActive]) VALUES (3, N'all', N'ALL', 1)
SET IDENTITY_INSERT [dbo].[Gender] OFF
SET IDENTITY_INSERT [dbo].[ITSkills] ON 

INSERT [dbo].[ITSkills] ([Id], [Skill], [SkillVersion], [LastUsed], [ExperienceYear], [ExperienceMonth], [CreatedDate], [CreatedBy], [UpdateDate], [UpdatedBy], [Status]) VALUES (1, N'.net core', N'v2.2', N'2020', N'1', N'2', CAST(N'2020-10-06 05:54:53.973' AS DateTime), N'3', NULL, NULL, 1)
INSERT [dbo].[ITSkills] ([Id], [Skill], [SkillVersion], [LastUsed], [ExperienceYear], [ExperienceMonth], [CreatedDate], [CreatedBy], [UpdateDate], [UpdatedBy], [Status]) VALUES (2, N'C#', N'v16.3', N'2020', N'2', N'5', CAST(N'2020-10-06 05:59:14.010' AS DateTime), N'3', NULL, NULL, 1)
SET IDENTITY_INSERT [dbo].[ITSkills] OFF
SET IDENTITY_INSERT [dbo].[JobIndustryArea] ON 

INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'IT Services', 1, NULL, CAST(N'2020-09-24 15:24:22.747' AS DateTime), NULL, NULL)
INSERT [dbo].[JobIndustryArea] ([JobIndustryAreaId], [JobIndustryAreaName], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, N'Marketing', 1, NULL, CAST(N'2020-09-24 15:33:42.493' AS DateTime), NULL, NULL)
SET IDENTITY_INSERT [dbo].[JobIndustryArea] OFF
SET IDENTITY_INSERT [dbo].[JobPostDetail] ON 

INSERT [dbo].[JobPostDetail] ([JobPostId], [JobIndustryAreaId], [CountryCode], [StateCode], [CityCode], [EmploymentStatusId], [EmploymentTypeId], [Skills], [MonthlySalary], [NoPosition], [Nationality], [PositionStartDate], [PositionEndDate], [HiringCriteria], [Status], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate], [JobType], [Gender], [JobDetails], [UserId], [SPOC], [SPOCEmail], [SPOCContact], [CTC], [Quarter1], [Quarter2], [Quarter3], [Quarter4], [Featured], [JobTitleByEmployer], [MinExperience], [MaxExperience], [FinancialYear], [FeaturedJobDisplayOrder], [IsFromBulkUpload], [OtherJobIndustryArea], [IsWalkIn], [IsDraft]) VALUES (1, 1, N'IN', N'UP', N'Noida', 1, NULL, N'Java,C++,Scalibility,Algo,DS,Python,SQL,Designe Pattern', NULL, 0, NULL, N'2020-10-05', N'2020-11-05', N'B.Tech/M.Tech', 1, N'2', CAST(N'2020-10-05 15:53:05.917' AS DateTime), N'1', CAST(N'2020-10-05 15:55:22.640' AS DateTime), 1, NULL, N'<p>Responsibilities :<br><br>- Owns team''s output and E2E definition and execution of SDLC. Drives sprint planning, estimates &amp; prioritizes tasks, Keeps key stakeholders updated on progress, milestones and any potential slippages.<br><br>- Identifies pitfalls across code bases proactively. Writes model code that is looked up to. Understands internals of programming languages &amp; runtimes. Creates common reusable components / libraries- Uses advanced data structures.<br><br>- Designs API contracts between large systems with end to end service design and active leadership towards long term sustainability including versioning, complex migration plans, impact analysis across products.<br><br>- Owns NFRs and pushes the envelop on performance, scalability and high availability with cognisance towards cost of infra. Drivestech stack selection independently, mentors junior engineers. Evangelises of generic platform building across the organisation.<br><br>- Troubleshoots unseen issues across codebases. Solves large end to end cross cutting problems with elegant solutions with an eye on long term sustainability.<br><br>- Partners with and influences product managers on - how- . Leads the pack on hiring and evangalizes steeper hiring standards towards building A+ team.<br><br>Interview process :<br><br>- Coding, Designingand problem solving, DS&amp; Algo<br><br>- Design patterns (HLD,LLD)<br><br>- Database design (No Sql, My Sql, Mongo DB)<br><br>- Project managemnt<br><br>- VP/Cofounder round<br><br>- Cultural fitment</p><p><strong>Required Candidate profile</strong></p><p>Qualifications :<br><br>- Bachelor''s Degree in Computer Science or similar discipline<br><br>- 4+ years relevant work experience in software engineering.<br><br>- Proficiency in more than one modern programming language such as Python/Java/C++ &amp; associated tech stack to write maintainable, scalable, unit-tested code<br><br>- Experience in building complex software systems that have been successfully delivered<br><br>- Deep understanding of design patterns, optimizations, deployments with a Strong object oriented design skills<br><br>- Experience mentoring other software engineers.<br><br>- Experience with full life cycle development in any programming language.</p><p>Role<a data-cke-saved-href="https://www.naukri.com/software-developer-jobs" href="https://www.naukri.com/software-developer-jobs" target="_blank">Software Developer</a></p><p>Industry Type<a data-cke-saved-href="https://www.naukri.com/it-software-jobs" href="https://www.naukri.com/it-software-jobs" target="_blank">IT-Software</a>,<a data-cke-saved-href="https://www.naukri.com/software-services-jobs" href="https://www.naukri.com/software-services-jobs" target="_blank">&nbsp;Software Services</a></p><p>Functional Area<a data-cke-saved-href="https://www.naukri.com/it-software-application-programming-jobs" href="https://www.naukri.com/it-software-application-programming-jobs" target="_blank">IT Software - Application Programming</a>,<a data-cke-saved-href="https://www.naukri.com/maintenance-jobs" href="https://www.naukri.com/maintenance-jobs" target="_blank">&nbsp;Maintenance</a></p><p>Employment TypeFull Time, Permanent</p><p>Role CategoryProgramming &amp; Design</p><p>Education</p><p>UG :B.Tech/B.E. in Computers</p><p>PG :Any Postgraduate in Any Specialization</p><p>Doctorate :Any Doctorate in Any Specialization, Doctorate Not Required</p>', 2, N'Rajesh Prajapati', N'hrcareerindeed@gmail.com', N'9811966378', N'800000', 0, 0, 0, 0, 1, N'Senior Software Engineer - Python/ C++/ Java', -1, -1, 2020, 0, 0, NULL, 1, 0)
SET IDENTITY_INSERT [dbo].[JobPostDetail] OFF
SET IDENTITY_INSERT [dbo].[JobRoleMapping] ON 

INSERT [dbo].[JobRoleMapping] ([MapId], [JobId], [JobRoleId]) VALUES (2, 1, NULL)
SET IDENTITY_INSERT [dbo].[JobRoleMapping] OFF
SET IDENTITY_INSERT [dbo].[JobTitle] ON 

INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'Software Developer', 1, 1, N'Admin', CAST(N'2020-09-24 15:28:30.457' AS DateTime), NULL, CAST(N'2020-09-25 07:13:46.510' AS DateTime))
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (2, N'Sales Executive', 1, 2, N'Admin', CAST(N'2020-09-24 15:35:13.167' AS DateTime), NULL, CAST(N'2020-09-25 06:40:04.627' AS DateTime))
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (3, N'Marketing Executive', 1, 2, NULL, CAST(N'2020-09-25 07:57:02.310' AS DateTime), NULL, CAST(N'2020-09-25 07:59:25.190' AS DateTime))
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (4, N'Backend Developer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:35.990' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (5, N'Fronted Developer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:35.990' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (6, N'Full Stack Developer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:35.990' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (7, N'MEAN Stack Developer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (8, N'Fronted Developer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (9, N'MERN Stack Developer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (10, N'Fresher', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (11, N'Programmer Analyst', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (12, N'Senior Applications Engineer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (13, N'Senior Programmer Analyst', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (14, N'Senior Software Engineer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (15, N'Senior System Architect', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (16, N'Software Quality Assurance Analyst', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (17, N'System Architect', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (18, N'Data Analyst', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (19, N'IT Technician', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (20, N'Information Security Analyst', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (21, N'IT Manager', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (22, N'Cyber Security Analyst', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (23, N'Devops Engineer', 1, 1, N'Admin', CAST(N'2020-10-06 06:34:36.003' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (24, N'Content Creator', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.890' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (25, N'Content Marketing Manager', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.893' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (26, N'Digital Brand Manager', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.893' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (27, N'Creative Director', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.893' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (28, N'Creative Assistant', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.893' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (29, N'Marketing Data Analyst', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.897' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (30, N'Marketing Technologist', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.897' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (31, N'Digital Marketing Manager', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.897' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (32, N'Social Media Coordinator', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.897' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (33, N'Social Media Strategist', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.897' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (34, N'Community Manager', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.900' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (35, N'SEO Specialist', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.900' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (36, N'SEO Strategist', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.900' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (37, N'SEO/Marketing Manager', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.900' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (38, N'Account Executive', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.900' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (39, N'Social Media Manager', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.900' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (40, N'Internet marketing specialist', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.900' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (41, N'User Experience Manager', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.903' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (42, N'Marketing Specialist', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.903' AS DateTime), NULL, NULL)
INSERT [dbo].[JobTitle] ([JobTitleId], [JobTitleName], [Status], [JobIndustryAreaId], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (43, N'Chief marketing officer', 1, 2, N'Admin', CAST(N'2020-10-06 06:35:27.903' AS DateTime), NULL, NULL)
SET IDENTITY_INSERT [dbo].[JobTitle] OFF
SET IDENTITY_INSERT [dbo].[JobTypes] ON 

INSERT [dbo].[JobTypes] ([Id], [Type], [IsActive]) VALUES (1, N'Fresher', 1)
INSERT [dbo].[JobTypes] ([Id], [Type], [IsActive]) VALUES (2, N'Experience', 1)
INSERT [dbo].[JobTypes] ([Id], [Type], [IsActive]) VALUES (3, N'Any', 1)
SET IDENTITY_INSERT [dbo].[JobTypes] OFF
SET IDENTITY_INSERT [dbo].[LoggedInUsers] ON 

INSERT [dbo].[LoggedInUsers] ([Id], [SessionId], [Userdata], [CreatedAt]) VALUES (2, N'e7fe4a5a-d18c-0dac-a8bc-3e61a03c9fde', N'{"UserId":2,"FirstName":"Career","LastName":"","FullName":"Career ","RoleId":0,"BatchNumber":null,"RoleName":"Corporate","MobileNo":"","UserName":null,"Email":"hrcareerindeed@gmail.com","Password":null,"Address1":"","Address2":"","Address3":"","City":null,"CityName":null,"State":null,"StateName":null,"Country":null,"CountryName":null,"ImageFile":null,"FullAddress":"","MaritalStatus":null,"MaritalStatusName":null,"ProfilePic":"\\ProfilePic\\Avatar.jpg","Gender":null,"GenderName":null,"DOB":null,"CompanyName":"Career","CandidateId":null,"IsApproved":"True","PasswordExpirayDate":"11/4/2020 12:00:00 AM","ProfileSummary":null,"Resume":null,"CTC":null,"ECTC":null,"AboutMe":null,"EmploymentStatus":null,"JobIndustryArea":null,"JobTitleName":"","JobTitleId":0,"JobTitlebyEmployer":null,"Jobdetails":null,"CreatedDate":"0001-01-01T00:00:00","ActiveFrom":"0001-01-01T00:00:00","HiringFor":null,"PreferredLocation":null,"PreferredLocation1":null,"PreferredLocation2":null,"PreferredLocation3":null,"Skills":null,"TotalExperience":0.0,"LinkedinProfile":null,"ReturnUrl":null,"SocialLogins":null,"EmploymentStatusName":null,"IsJobAlert":false,"ProfileScore":0,"PasswordHash":"PRtZQYPFNWNHndovosW9papP5QPzdq1Z54U+B/UauAfiKLsuuIc2kmMHIUHMZ1VzHYI3ZNwvxEmK00w+3G6xsg==","PasswordSalt":"BUlblSoKcfnRaFRNjXpYWYZBQq+1Xmzoy9hXixe+A7Or/8rfSkD5FWkdlYvTWR9MTC2FGJlXWD/hOLve5jKCzO2RWp1lTgNETIP7h4wd8mj5T352VZweqQDlUCMQ2k4s4PuGodcgTrZoEUYnVm6W7DrhH0cg47vgrCq8O97N+74="}', CAST(N'2020-10-05 19:07:18.393' AS DateTime))
INSERT [dbo].[LoggedInUsers] ([Id], [SessionId], [Userdata], [CreatedAt]) VALUES (4, N'28bbae0a-5222-b3ba-8759-40e018655905', N'{"UserId":2,"FirstName":"Career","LastName":"","FullName":"Career ","RoleId":0,"BatchNumber":null,"RoleName":"Corporate","MobileNo":"","UserName":null,"Email":"hrcareerindeed@gmail.com","Password":null,"Address1":"","Address2":"","Address3":"","City":null,"CityName":null,"State":null,"StateName":null,"Country":null,"CountryName":null,"ImageFile":null,"FullAddress":"","MaritalStatus":null,"MaritalStatusName":null,"ProfilePic":"\\ProfilePic\\Avatar.jpg","Gender":null,"GenderName":null,"DOB":null,"CompanyName":"Career","CandidateId":null,"IsApproved":"True","PasswordExpirayDate":"11/4/2020 12:00:00 AM","ProfileSummary":null,"Resume":null,"CTC":null,"ECTC":null,"AboutMe":null,"EmploymentStatus":null,"JobIndustryArea":null,"JobTitleName":"","JobTitleId":0,"JobTitlebyEmployer":null,"Jobdetails":null,"CreatedDate":"0001-01-01T00:00:00","ActiveFrom":"0001-01-01T00:00:00","HiringFor":null,"PreferredLocation":null,"PreferredLocation1":null,"PreferredLocation2":null,"PreferredLocation3":null,"Skills":null,"TotalExperience":0.0,"LinkedinProfile":null,"ReturnUrl":null,"SocialLogins":null,"EmploymentStatusName":null,"IsJobAlert":false,"ProfileScore":0,"PasswordHash":"7RKN1mgNOWErM4O4dxEgpR3X3KpDW9+PIZjfjckJs8obzXpA0RjhfaJkTss14EMSCFLnThDPrMrzVH3lozTjmA==","PasswordSalt":"RIhrgzSrOuGPv4nnpXbfD+uWKmjVPX0RCFtawQZcAcBTRKqcIM7OIkaV7I26j3q1r1OE6rMgX+v9vN0UYELSJaU2ZavBXmgGYmxgHCXpwKM59pBxNS3xqVM5yBpk5zBVQltVtdYUMO0nI26gkAf01KcjE0hB9ZvE5eVD+6kZAoM="}', CAST(N'2020-10-05 19:57:05.580' AS DateTime))
INSERT [dbo].[LoggedInUsers] ([Id], [SessionId], [Userdata], [CreatedAt]) VALUES (5, N'206130bc-ce9c-2c40-a85b-c547a3bb474f', N'{"UserId":2,"FirstName":"Career","LastName":"","FullName":"Career ","RoleId":0,"BatchNumber":null,"RoleName":"Corporate","MobileNo":"","UserName":null,"Email":"hrcareerindeed@gmail.com","Password":null,"Address1":"","Address2":"","Address3":"","City":null,"CityName":null,"State":null,"StateName":null,"Country":null,"CountryName":null,"ImageFile":null,"FullAddress":"","MaritalStatus":null,"MaritalStatusName":null,"ProfilePic":"\\ProfilePic\\Avatar.jpg","Gender":null,"GenderName":null,"DOB":null,"CompanyName":"Career","CandidateId":null,"IsApproved":"True","PasswordExpirayDate":"11/4/2020 12:00:00 AM","ProfileSummary":null,"Resume":null,"CTC":null,"ECTC":null,"AboutMe":null,"EmploymentStatus":null,"JobIndustryArea":null,"JobTitleName":"","JobTitleId":0,"JobTitlebyEmployer":null,"Jobdetails":null,"CreatedDate":"0001-01-01T00:00:00","ActiveFrom":"0001-01-01T00:00:00","HiringFor":null,"PreferredLocation":null,"PreferredLocation1":null,"PreferredLocation2":null,"PreferredLocation3":null,"Skills":null,"TotalExperience":0.0,"LinkedinProfile":null,"ReturnUrl":null,"SocialLogins":null,"EmploymentStatusName":null,"IsJobAlert":false,"ProfileScore":0,"PasswordHash":"7RKN1mgNOWErM4O4dxEgpR3X3KpDW9+PIZjfjckJs8obzXpA0RjhfaJkTss14EMSCFLnThDPrMrzVH3lozTjmA==","PasswordSalt":"RIhrgzSrOuGPv4nnpXbfD+uWKmjVPX0RCFtawQZcAcBTRKqcIM7OIkaV7I26j3q1r1OE6rMgX+v9vN0UYELSJaU2ZavBXmgGYmxgHCXpwKM59pBxNS3xqVM5yBpk5zBVQltVtdYUMO0nI26gkAf01KcjE0hB9ZvE5eVD+6kZAoM="}', CAST(N'2020-10-05 15:44:23.177' AS DateTime))
INSERT [dbo].[LoggedInUsers] ([Id], [SessionId], [Userdata], [CreatedAt]) VALUES (8, N'a6ecd015-fa84-d294-733a-9f77ccfa016c', N'{"UserId":3,"FirstName":"Sunil","LastName":"Kumar","FullName":"Sunil Kumar","RoleId":0,"BatchNumber":null,"RoleName":"Student","MobileNo":"8802680333","UserName":null,"Email":"sunilkumardec15@gmail.com","Password":null,"Address1":"","Address2":"","Address3":"","City":null,"CityName":null,"State":null,"StateName":null,"Country":null,"CountryName":null,"ImageFile":null,"FullAddress":"","MaritalStatus":null,"MaritalStatusName":null,"ProfilePic":"\\ProfilePic\\Avatar.jpg","Gender":null,"GenderName":null,"DOB":null,"CompanyName":"","CandidateId":null,"IsApproved":"True","PasswordExpirayDate":"05-11-2020 00:00:00","ProfileSummary":null,"Resume":null,"CTC":null,"ECTC":null,"AboutMe":null,"EmploymentStatus":null,"JobIndustryArea":null,"JobTitleName":"","JobTitleId":0,"JobTitlebyEmployer":null,"Jobdetails":null,"CreatedDate":"0001-01-01T00:00:00","ActiveFrom":"0001-01-01T00:00:00","HiringFor":null,"PreferredLocation":null,"PreferredLocation1":null,"PreferredLocation2":null,"PreferredLocation3":null,"Skills":null,"TotalExperience":0.0,"LinkedinProfile":null,"ReturnUrl":null,"SocialLogins":null,"EmploymentStatusName":null,"IsJobAlert":false,"ProfileScore":0,"PasswordHash":"rI9qIUk790qxA2DWynJMYD5CJQnDiJelZFkoILGciDboNQZz/kH6vTy4UGLUD9r8HeBrLgT5AXaGGkcNII9auw==","PasswordSalt":"2B2zA4zNZRwudFpP8xziLxKjyhRurcW5uBEdnOnbFCVp1gQp0RwzY3IGQHQurul2JFS19Hw4uClac0qnxfTh1uL0B9cWuthVwkkaBkmoRk/W8pSgzdj6LS8gOS2CsBUlQ7489IV7WuwP8VoTpXybd6lvMrqf54toHPvaQPDZX2A="}', CAST(N'2020-10-06 05:50:34.813' AS DateTime))
SET IDENTITY_INSERT [dbo].[LoggedInUsers] OFF
SET IDENTITY_INSERT [dbo].[Logging] ON 

INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (1, N'Error', N'Data not found', NULL, N'{"Message":"Data not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Admin.SuccessStoryVideoRepository.GetSuccessStoryVid() in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Admin\\SuccessStoryVideoRepository.cs:line 46\r\n   at JobPortal.Business.Handlers.Admin.SuccessStoryVideoHandler.GetSuccessStoryVid() in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Admin\\SuccessStoryVideoHandler.cs:line 29\r\n   at JobPortal.Web.Areas.Admin.Controllers.SuccessStoryVideoController.GetSuccessStoryVideo(String country) in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Admin\\Controllers\\SuccessStoryVideoController.cs:line 115","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'SuccessStoryVideoController', CAST(N'2020-10-05 18:57:06.020' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (2, N'Error', N'Jobs not found', NULL, N'{"Message":"Jobs not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetJobs(Int32 empId, Int32 year, Boolean isDraftJob) in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 101\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetJobs(Int32 year, Int32 employer) in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 119","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-10-05 18:59:37.153' AS DateTime), 1)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (3, N'Error', N'Can not execute query', NULL, N'{"Message":"Can not execute query","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Data.Repositories.Home.HomeRepositories.ViewAllFeaturedJobs() in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Data\\Repositories\\Home\\HomeRepositories.cs:line 329\r\n   at JobPortal.Business.Handlers.Home.HomeHandler.ViewAllFeaturedJobs() in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Home\\HomeHandler.cs:line 249\r\n   at JobPortal.Web.Areas.Admin.Controllers.ManageJobsController.FeaturedJobs() in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Admin\\Controllers\\ManageJobsController.cs:line 41","HelpLink":null,"Source":"JobPortal.Data","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'ManageJobsController', CAST(N'2020-10-05 18:59:41.533' AS DateTime), 0)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (4, N'Error', N'Messages not found', NULL, N'{"Message":"Messages not found","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Employer.DashboardHandler.GetMessages(DateTime msgsOnDate, Int32 empId) in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Employer\\DashboardHandler.cs:line 409\r\n   at JobPortal.Web.Areas.Employer.Controllers.DashboardController.GetMessages(String date) in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Web\\Areas\\Employer\\Controllers\\DashboardController.cs:line 283","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'DashboardController', CAST(N'2020-10-05 19:13:19.697' AS DateTime), 2)
INSERT [dbo].[Logging] ([Id], [LogType], [Message], [Data], [Exception], [AssemblyInfo], [ClassInfo], [CreatedDate], [CreatedBy]) VALUES (5, N'Error', N'Entered user credentials are not valid', NULL, N'{"Message":"Entered user credentials are not valid","Data":{},"InnerException":null,"StackTrace":"   at JobPortal.Business.Handlers.Auth.AuthHandler.Login(String userName, String password) in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Business\\Handlers\\Auth\\AuthHandler.cs:line 75\r\n   at JobPortal.Web.Controllers.AuthController.Login(UserViewModel user) in F:\\Steeprise\\Data\\JobPortalSROld\\JobPortalSR\\SourceCode\\JobPortal.Web\\Controllers\\AuthController.cs:line 55","HelpLink":null,"Source":"JobPortal.Business","HResult":-2146232832}', N'JobPortal.Web, Version=1.0.0.0, Culture=neutral, PublicKeyToken=null', N'AuthController', CAST(N'2020-10-05 19:56:25.223' AS DateTime), 0)
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

INSERT [dbo].[PopularJobSearches] ([Id], [FilterName], [FilterValue], [Count], [CreatedBy], [CreatedDate], [UpdatedBy], [UpdatedDate]) VALUES (1, N'Experience', N'-1', 3, N'0', CAST(N'2020-10-05 15:54:01.983' AS DateTime), N'0', CAST(N'2020-10-06 05:19:38.353' AS DateTime))
SET IDENTITY_INSERT [dbo].[PopularJobSearches] OFF
SET IDENTITY_INSERT [dbo].[PreferredLocation] ON 

INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (1, 3, N'Noida', NULL, 1, CAST(N'2020-10-06' AS Date), N'3', CAST(N'2020-10-06' AS Date), N'3')
INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (2, 3, N'Noida', NULL, 2, CAST(N'2020-10-06' AS Date), N'3', CAST(N'2020-10-06' AS Date), N'3')
INSERT [dbo].[PreferredLocation] ([Id], [UserId], [LocationId], [OtherLocation], [LocationOrder], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy]) VALUES (3, 3, N'Noida', NULL, 3, CAST(N'2020-10-06' AS Date), N'3', CAST(N'2020-10-06' AS Date), N'3')
SET IDENTITY_INSERT [dbo].[PreferredLocation] OFF
SET IDENTITY_INSERT [dbo].[Roles] ON 

INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (1, N'Admin', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 1)
INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (2, N'Student', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 0)
INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (3, N'Corporate', 1, CAST(N'2020-04-03 18:34:57.630' AS DateTime), N'Admin', 1)
INSERT [dbo].[Roles] ([ID], [RoleName], [IsActive], [Createddate], [CreatedBy], [IsEmployee]) VALUES (4, N'Consultant', 1, CAST(N'2020-09-08 05:51:04.863' AS DateTime), N'Admin', 1)
SET IDENTITY_INSERT [dbo].[Roles] OFF
SET IDENTITY_INSERT [dbo].[SearchJobHistory] ON 

INSERT [dbo].[SearchJobHistory] ([Id], [UserIP], [Location], [JobSeekerId], [SearchCriteria], [CreatedBy], [CreatedDate]) VALUES (1, N'::1', N'{
  "ip": "::1",
  "bogon": true
}', 0, N'{"Skills":null,"JobTitle":0,"JobCategory":[],"Experiance":-1,"City":[],"CompanyUserId":[]}', 0, CAST(N'2020-10-05 15:54:01.383' AS DateTime))
INSERT [dbo].[SearchJobHistory] ([Id], [UserIP], [Location], [JobSeekerId], [SearchCriteria], [CreatedBy], [CreatedDate]) VALUES (2, N'::1', N'{
  "ip": "::1",
  "bogon": true
}', 0, N'{"Skills":null,"JobTitle":0,"JobCategory":[],"Experiance":-1,"City":[],"CompanyUserId":[]}', 0, CAST(N'2020-10-05 15:57:14.167' AS DateTime))
INSERT [dbo].[SearchJobHistory] ([Id], [UserIP], [Location], [JobSeekerId], [SearchCriteria], [CreatedBy], [CreatedDate]) VALUES (3, N'::1', N'{
  "ip": "::1",
  "bogon": true
}', 0, N'{"Skills":null,"JobTitle":0,"JobCategory":[],"Experiance":-1,"City":[],"CompanyUserId":[]}', 0, CAST(N'2020-10-06 05:19:37.873' AS DateTime))
SET IDENTITY_INSERT [dbo].[SearchJobHistory] OFF
INSERT [dbo].[States] ([StateCode], [Name], [IsActive], [CountryCode]) VALUES (N'UP', N'Uttar Pradesh', 1, N'IN')
SET IDENTITY_INSERT [dbo].[UserActivity] ON 

INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (1, 1, CAST(N'2020-10-05 18:55:54.023' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (2, 2, CAST(N'2020-10-05 19:07:18.397' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (3, 2, CAST(N'2020-10-05 19:56:38.947' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (4, 2, CAST(N'2020-10-05 19:57:05.593' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (5, 2, CAST(N'2020-10-05 15:44:24.017' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (6, 2, CAST(N'2020-10-05 15:48:16.787' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (7, 1, CAST(N'2020-10-05 15:54:42.140' AS DateTime), NULL)
INSERT [dbo].[UserActivity] ([Id], [UserId], [LoginDateTime], [Url]) VALUES (8, 3, CAST(N'2020-10-06 05:50:35.233' AS DateTime), NULL)
SET IDENTITY_INSERT [dbo].[UserActivity] OFF
SET IDENTITY_INSERT [dbo].[UserProfessionalDetails] ON 

INSERT [dbo].[UserProfessionalDetails] ([ID], [UserId], [ExperienceDetails], [EducationalDetails], [Skills], [CurrentSalary], [ExpectedSalary], [DateOfBirth], [Resume], [AboutMe], [ProfileSummary], [Status], [CreatedDate], [CreatedBy], [UpdatedDate], [UpdatedBy], [EmploymentStatusId], [JobIndustryAreaId], [TotalExperience], [LinkedinProfile], [IsJobAlert], [JobTitleId]) VALUES (1, 3, N'[{"Id":1,"Designation":"Software developer","Organization":"Steep Rise Infotech ","AnnualSalary":"3 Lakhs 20 Thousands","WorkingFrom":"Sep, 2019","WorkingTill":"2020","WorkLocation":"Noida","NoticePeriod":"60","ServingNoticePeriod":false,"Industry":"1","JobProfile":"I am working as a software developer","IsCurrentOrganization":false,"Skills":{"SkillSets":"C#, MVC, .net core 2.2, Sql Server"}}]', N'[{"Id":1,"Qualification":"2","Course":"5","OtherCourseName":null,"Specialization":"IT","University":"VITS","CourseType":"1","PassingYear":"2014","Percentage":"75"}]', N'{"SkillSets":"ASP.NET CORE, C#,SQL SERVER,JQUERY,CSS,C#,MVC,.NET CORE 2.2"}', NULL, NULL, N'1991-12-15', N'\Resume\_637375809304398908.docx', NULL, N'I have worked on the various project as a software developer on technology asp.net core with for backed have also worked on SQL server 2014. On my current project working on .net core 2.2 with all configuration and customization and development', NULL, CAST(N'2020-10-06 05:52:39.073' AS DateTime), N'3', CAST(N'2020-10-06 06:09:31.937' AS DateTime), N'3', NULL, NULL, NULL, NULL, 0, NULL)
SET IDENTITY_INSERT [dbo].[UserProfessionalDetails] OFF
SET IDENTITY_INSERT [dbo].[UserRoles] ON 

INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (1, 1, 1, CAST(N'2020-10-05 18:55:09.997' AS DateTime), N'admin')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (2, 3, 2, CAST(N'2020-10-05 19:05:51.440' AS DateTime), N'2')
INSERT [dbo].[UserRoles] ([ID], [RoleId], [UserId], [Createddate], [CreatedBy]) VALUES (3, 2, 3, CAST(N'2020-10-06 05:46:47.160' AS DateTime), N'3')
SET IDENTITY_INSERT [dbo].[UserRoles] OFF
SET IDENTITY_INSERT [dbo].[Users] ON 

INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID], [PasswordHash], [PasswordSalt]) VALUES (1, N'Admin', NULL, NULL, N'admin@yopmail.com', N'Admin@123', NULL, NULL, NULL, NULL, NULL, NULL, NULL, N'\ProfilePic\120_download (1).jpg', 1, 0, CAST(N'2020-08-05 13:23:09.710' AS DateTime), 0, CAST(N'2020-10-05 18:08:19.967' AS DateTime), NULL, 1, N'Admin', CAST(N'2023-06-04' AS Date), NULL, NULL, NULL, 1, 0, 0, N'12883726', 0x328A2D839AD371CB1228B74AD69312AB1CC1B92A0CFBA2E750A2D898BFCDE2DF94932EC23CEEAFF218FC3030E6ED0F1910580E2AD8076A6A51815DDF0509796B, 0x71A71B18A598F17B37CF5FB6F23ABEEC23798AFB05E75D07E2E0E835CF43F81BB6749B8F824199D1A938FF55576C6ECFAAE4B8EC885AEF0F4DBB14E3B57CAFCA34794BA88DB5135BBB9B4FA2631A4D2B0C10F6D245CA2368D3075111EE9427697ABC9403EB6221B4DB8299B171E8778E94A877E17F48C10555DAF1253F63F7E2)
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID], [PasswordHash], [PasswordSalt]) VALUES (2, N'Career', NULL, NULL, N'hrcareerindeed@gmail.com', NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 1, 0, CAST(N'2020-10-05 19:05:51.440' AS DateTime), 0, CAST(N'2020-10-05 19:56:55.080' AS DateTime), NULL, 1, N'Career', CAST(N'2020-11-04' AS Date), NULL, NULL, NULL, 0, 0, 0, NULL, 0xED128DD6680D39612B3383B8771120A51DD7DCAA435BDF8F2198DF8DC909B3CA1BCD7A40D118E17DA2644ECB35E043120852E74E10CFACCAF3547DE5A334E398, 0x44886B8334AB3AE18FBF89E7A576DF0FEB962A68D53D7D11085B5AC1065C01C05344AA9C20CECE224695EC8DBA8F7AB5AF5384EAB3205FEBFDBCDD146042D225A53665ABC15E6806626C601C25E9C0A339F69071352DF1A95339C81A64E73055425B55B5D61430ED27236EA09007F4D4A723134841F59BC4E5E543FBA9190283)
INSERT [dbo].[Users] ([UserId], [FirstName], [LastName], [MobileNo], [Email], [Password], [Address1], [Address2], [Address3], [City], [State], [Country], [MaritalStatus], [ProfilePic], [IsActive], [CreatedBy], [CreatedOn], [UpdatedBy], [UpdatedOn], [Gender], [IsApproved], [CompanyName], [PasswordExpiryDate], [Candidateid], [ContactPerson], [ActivationKey], [IsViewedByAdmin], [IsHired], [IsRegisterOnlyForDemandAggregationData], [JobPortalTPID], [PasswordHash], [PasswordSalt]) VALUES (3, N'Sunil', N'Kumar', N'8802680333', N'sunilkumardec15@gmail.com', NULL, N'b95', N'Mayur Vihar Phase 3', N'New Delhi', N'Noida', N'UP', N'IN', N'married', NULL, 1, 0, CAST(N'2020-10-06 05:46:47.160' AS DateTime), 3, CAST(N'2020-10-06 06:01:33.933' AS DateTime), N'male', 1, NULL, CAST(N'2020-11-05' AS Date), NULL, NULL, NULL, 0, 0, 0, NULL, 0xAC8F6A21493BF74AB10360D6CA724C603E422509C38897A564592820B19C8836E8350673FE41FABD3CB85062D40FDAFC1DE06B2E04F90176861A470D208F5ABB, 0xD81DB3038CCD651C2E745A4FF31CE22F12A3CA146EADC5B9B8111D9CE9DB142569D60429D11C3363720640742EAEE9762454B5F47C38B8295A734AA7C5F4E1D6E2F407D716BAD855C2491A0649A8464FD6F294A0CDD8FA2D2F20392D82B0152543BE3CF4857B5AEC0FF15A13A57C9B77A96F32BA9FE78B681CFBDA40F0D95F60)
SET IDENTITY_INSERT [dbo].[Users] OFF
ALTER TABLE [dbo].[BulkJobPostSummary] ADD  DEFAULT (getdate()) FOR [CreatedOn]
GO
ALTER TABLE [dbo].[Designations] ADD  DEFAULT ((1)) FOR [IsActive]
GO
ALTER TABLE [dbo].[EmployerAdvanceSearch] ADD  DEFAULT ((0)) FOR [IsSavedSearch]
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
ALTER TABLE [dbo].[ProfileViewSummary] ADD  DEFAULT (getdate()) FOR [ViewedOn]
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
ALTER TABLE [dbo].[JobTitle]  WITH CHECK ADD FOREIGN KEY([JobIndustryAreaId])
REFERENCES [dbo].[JobIndustryArea] ([JobIndustryAreaId])
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
/****** Object:  StoredProcedure [dbo].[DeleteBulkJob]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_AddAdvertisements]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
--------------------------------------------------------------------------------------------------------------------------
SR		By			Date				Remarks
1		SR			14/09/2020			Created to add ads data
2		SR			16/09/2020			added jobpage
--------------------------------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_AddAdvertisements]
(
	@id INT,
	@section INT,
	@order INT,
	@jobpage VARCHAR(MAX),
	@imageurl VARCHAR(MAX)
)
AS
BEGIN
	INSERT INTO dbo.Advertisements
	(
		ImageUrl,
		Section,
		[Order],
		JobPage,
		CreatedBy,
		CreatedDate,
		IsActive
	)
	VALUES
	(
		@imageurl,
		@section,
		@order,
		@jobpage,
		@id,
		GETDATE(),
		1
	)			
END


GO
/****** Object:  StoredProcedure [dbo].[usp_AddCity]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	IF EXISTS(SELECT 1 FROM dbo.Cities WHERE CityCode=@citycode)
	BEGIN
	UPDATE Cities
	SET
	[Name] = @city,
	[IsActive] = 1
	WHERE 
	CityCode = @citycode
	END
	ELSE
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
/****** Object:  StoredProcedure [dbo].[usp_AddDesignation]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_AddPreferredlocation]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_AdminDashboardStats]    Script Date: 10/6/2020 12:07:43 PM ******/
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
  ON JP.UserId = U.UserId
  LEFT JOIN dbo.UserRoles UR    
  ON U.UserId = UR.UserId    
  LEFT JOIN dbo.Roles R    
  ON UR.RoleId = R.Id    
 WHERE CAST(JP.CreatedDate AS DATE) >= CAST(@Date AS DATE)    
  AND CAST(JP.Createddate AS DATE) <= CAST(@EndDate AS DATE)    
  AND JP.IsDraft=0
  AND R.ID IN (3,4)    
  AND U.IsActive=1    --- To exclude deleted user 06/12/2020
    
     
 SELECT     
  @TotalResumePost = COUNT(1)    
 FROM dbo.AppliedJobs AJ  
  LEFT JOIN dbo.Users U  
  ON AJ.UserId = U.UserId  
  LEFT JOIN dbo.JobPostDetail JPD  
  ON AJ.JobPostId = JPD.JobPostId AND JPD.IsDraft = 0
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
/****** Object:  StoredProcedure [dbo].[usp_AdvanceSearchResume]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_AdvanceSearchResume] 
(  
	@UserId INT,
	@HiringRequirement VARCHAR(500) =NULL,
	@AnyKeyword VARCHAR(500) =NULL,
	@AllKeyword VARCHAR(500) =NULL,
	@ExculudeKeyword VARCHAR(500)=NULL,
	@MinExp INT=0,
	@MaxExp INT=0,
	@MinSalary VARCHAR(20)=NULL,
	@MaxSalary VARCHAR(20)=NULL,
	@CurrentLocation VARCHAR(10)=NULL,
	@PreferredLocation1 VARCHAR(10)=NULL,
	@PreferredLocation2 VARCHAR(10)=NULL,
	@PreferredLocation3 VARCHAR(10)=NULL,
	@FuncationlArea INT=0,
	@JobIndustryAreaId INT = 0, 
	--@EmploymentOf INT=0,
	--@ExcludeEmployment INT=0,
	@CurrentDesignation VARCHAR(100)=NULL,
	@NoticePeriod VARCHAR(5)=NULL,
	@Skills VARCHAR(1000) = NULL,  
	@AgeFrom INT =0,
	@AgeTO INT=0,
	@Gender VARCHAR(100)=NULL,
	@CandidatesType VARCHAR(50)=NULL,
	--@ShowCandidateWith VARCHAR=NULL,
	@ShowCandidateSeeking INT=0,
	--@CandidateShortedby VARCHAR=NULL,
	--@CandidateActiveInmonth VARCHAR=NULL
	@IsSavedSearch BIT = 0
)
AS
BEGIN
EXEC usp_InsertEmployerAdvanceSearch
	@UserId,
	@HiringRequirement,
	@AnyKeyword,
	@AllKeyword,
	@ExculudeKeyword,
	@MinExp,
	@MaxExp,
	@MinSalary,
	@MaxSalary,
	@CurrentLocation,
	@PreferredLocation1,
	@PreferredLocation2,
	@PreferredLocation3,
	@FuncationlArea,
	@JobIndustryAreaId,
	@CurrentDesignation,
	@NoticePeriod,
	@Skills,  
	@AgeFrom,
	@AgeTO,
	@Gender,
	@CandidatesType,
	@ShowCandidateSeeking,
	@IsSavedSearch

--........................................


;WITH CTE_Jobseeker AS
	(  
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
		UD.TotalExperience,
		U.CreatedOn,
		U.UpdatedOn,
		UD.CreatedDate,
		UD.UpdatedDate
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
		LEFT JOIN PreferredLocation AS PFRL
		ON U.UserId = PFRL.UserId	
	WHERE (  
		  (  
		   ISNULL(@CurrentLocation,'') <> ''  
		   AND  
		   CT.CityCode IN (SELECT val FROM dbo.f_split(@CurrentLocation, ','))  
		  )  
		  OR  
		  (  
		   ISNULL(@CurrentLocation,'') = ''  
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
		 
		  OR  
		  (  
		   ISNULL(@Skills,'') = ''  
		  )
		 )  
		 AND  
		 (  
		  (  
		   @MinExp > 0  
		   AND  
		   @MaxExp = 0  
		   AND  
		   UD.TotalExperience >= @MinExp  
		  )  
		  OR  
		  (  
		   @MinExp = 0  
		   AND  
		   @MaxExp > 0  
		   AND  
		   UD.TotalExperience <= @MaxExp  
		  )  
		  OR  
		  (  
		   @MinExp > 0  
		   AND  
		   @MaxExp > 0  
		   AND  
		   UD.TotalExperience BETWEEN @MinExp AND @MaxExp  
		  )  
		  OR  
		  (  
		   @MinExp = 0  
		   AND  
		   @MaxExp = 0  
		  )  
		 ) 
		AND  
		 (
		 (
			IsNull(@MinSalary, '') <> ''
			AND  
			IsNull(@MaxSalary, '') <> ''
			AND
			UD.CurrentSalary BETWEEN @MinSalary AND @MaxSalary  
		 )
		 OR
		 (
			IsNull(@MinSalary, '') <> ''
			AND  
			IsNull(@MaxSalary, '') = ''
			AND
			UD.CurrentSalary>=@MinSalary  
		 )
		
		OR
		 (
			IsNull(@MinSalary, '') = ''
			AND  
			IsNull(@MaxSalary, '') <> ''
			AND
			UD.CurrentSalary<=@MaxSalary   
		 )
		   OR  
		  (  
		   @MinSalary = '' 
		   AND  
		   @MaxSalary = ''  
		  ) 
		  OR
		  (
			 ISNULL(@MinSalary,'')='' 
			AND  
			 ISNULL(@MaxSalary,'')  =''
		  )
		 )
		  AND
		  (
			(
			ISNULL(@PreferredLocation1,'')<>''
			AND
			PFRL.LocationId IN (@PreferredLocation1,@PreferredLocation2,@PreferredLocation3)
			)
			OR 
			(
			ISNULL(@PreferredLocation1,'')=''
			)
		  )
		   AND
		   (
		  
			(
			ISNULL(@PreferredLocation2,'')<>''
			AND
			PFRL.LocationId IN (@PreferredLocation1,@PreferredLocation2,@PreferredLocation3)
			)
			OR 
			(
			ISNULL(@PreferredLocation2,'')=''
			)
		  )
		   AND
		  (
			(
			ISNULL(@PreferredLocation3,'')<>''
			AND
			PFRL.LocationId IN (@PreferredLocation1,@PreferredLocation2,@PreferredLocation3)
			)
			OR 
			(
			ISNULL(@PreferredLocation3,'')=''
			)
			
		  )
		  AND
		  (
			  (
			  ISNULL(@FuncationlArea,'')<>''
			  AND
			  JT.JobTitleId = @FuncationlArea
			  )
			  OR
			  (
				@FuncationlArea=0
			  )
		  )
		  AND
		(
			(
				ISNULL(@CurrentDesignation,'')<>''
				AND
				UD.ExperienceDetails LIKE'%' +'"Designation":"'+@CurrentDesignation+'"'+ '%'
			)
			OR
			(
				ISNULL(@CurrentDesignation,'')=''
			)
		)

		 AND
		(
			(
				ISNULL(@NoticePeriod,'')<>''
				AND
				UD.ExperienceDetails LIKE'%' +'"NoticePeriod":"'+@NoticePeriod+'"'+ '%'
			)
			OR
			(
				ISNULL(@NoticePeriod,'')=''
			)
		)
		AND
		(
			DATEDIFF(YY,UD.DateOfBirth,GETDATE()) BETWEEN @AgeFrom AND @AgeTO
			OR
			@AgeFrom=0
			AND
			@AgeTO=0

		)
		AND
		(
			(
			ISNULL(@Gender,'')<>''
			AND 
			ISNULL(@Gender,'')<>'all'
			AND
			U.Gender = @Gender
			)
			OR
			(
				ISNULL(@Gender,'')=''
			)

			OR
			(
				ISNULL(@Gender,'')='All'
			)

		)

		AND
		(
			(
				ISNULL(@CandidatesType,'')='ALL'
				AND
				ISNULL(U.UpdatedOn,'')=''
				OR
				ISNULL(U.UpdatedOn,'')<>''
			)
			OR
			(
			ISNULL(@CandidatesType,'')='Modified'
			AND
			ISNULL(U.UpdatedOn,'')<>''
			)
			OR
			(
			ISNULL(@CandidatesType,'')='New'
			AND
			ISNULL(U.UpdatedOn,'')=''
			)
			OR
			(
			@CandidatesType=''
			)
		)
		AND  
		 (  
		  (  
		   ISNULL(@ShowCandidateSeeking,'') <> ''  
		   AND  
		   UD.EmploymentStatusId =@ShowCandidateSeeking 
		  )  
		  OR  
		  (  
		   @ShowCandidateSeeking = 0  
		  )  
		 ) 
		
	)
			SELECT DISTINCT
			UserId,  
			FirstName,  
			LastName,  
			Email,  
			ProfilePic,  		
			Skills,  
			ExperienceDetails,
			AboutMe,
			[Resume],  
			JobIndustryAreaName,  
			JobTitleName,		
			CityName,
			CurrentSalary,
			ExpectedSalary,
			ProfileSummary,
			LinkedinProfile,
			TotalExperience,
			CreatedOn,
			CreatedDate,
			UpdatedOn,
			UpdatedDate
			FROM CTE_Jobseeker cte1
		--	ORDER BY
		--CASE 
		--	WHEN CreatedOn IS NOT NULL THEN CreatedOn
		--	WHEN CreatedDate IS NOT NULL THEN CreatedDate
		--	WHEN UpdatedOn IS NOT NULL THEN UpdatedOn
		--	ELSE UpdatedDate END
		--	DESC 
END   


GO
/****** Object:  StoredProcedure [dbo].[usp_ApprovesuccessStoryReview]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_ApproveUser]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckDesignationExist]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfCandidateEducationalDetailsExist]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfCandidateIdExists]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfCandidateResumeExist]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfEmployerExists]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfJobSaved]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfSkillEmpty]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfStateCodeExist]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfTPIdExists]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfUserExistInUserProfessionalDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CheckIfUserExists]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_CloseEmployerJob]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_CloseEmployerJob]
(
@UserId INT,
@JobPostId INT
)
AS
BEGIN
	Update JobPostDetail 
	SET 
		PositionEndDate = GETDATE()
	WHERE 
	JobPostId=@JobPostId
	AND	UserId=@UserId
	AND IsDraft =0 
END


GO
/****** Object:  StoredProcedure [dbo].[usp_CreateNewPassword]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_CreateNewPassword]
(
	@Email NVARCHAR(50),
	--@Password NVARCHAR(MAX),
	--@OldPassword NVARCHAR(MAX)
	@passwordHash VARBINARY(MAX),
	@passwordSalt VARBINARY(MAX)
)
AS
BEGIN
 Update Users
	SET PasswordHash =@passwordHash,
		PasswordSalt = @passwordSalt,
		UpdatedBy = 0,
		UpdatedOn =GETDATE(),
		PasswordExpiryDate = GETDATE()+30
    WHERE Email = @Email 
	--AND [Password] = @OldPassword
END


GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteActiveUser]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_DeleteActiveUser]
(
	@sessionid varchar(max)	
)
AS
BEGIN
	DELETE FROM dbo.LoggedInUsers WHERE SessionId=@sessionid
END


GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteAdvertisements]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
--------------------------------------------------------------------------------------------------------------------------
SR		By			Date				Remarks
1		SR			14/09/2020			Created to delete ads data
--------------------------------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_DeleteAdvertisements]
(
	@id INT	
)
AS
BEGIN	
	UPDATE dbo.Advertisements
	SET IsActive=0
	WHERE Id=@id		
END


GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteAppliedJob]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteCandidateByUserid]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteCity]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteDesignation]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteFeaturedJob]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	AND IsDraft = 0
END


GO
/****** Object:  StoredProcedure [dbo].[usp_DeleteITSkill]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteJobIndustryArea]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteJobTitle]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteState]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteSuccessStory]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteSuccessStoryVid]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_DeleteUserById]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_ForgetPassword]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetAdminGraphData]    Script Date: 10/6/2020 12:07:43 PM ******/
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
      WHERE JPD.IsDraft=0 AND Year(Cast(JPD.createddate AS DATE)) = @Year 
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
                    ON AJ.jobpostid = JPD.jobpostid AND JPD.IsDraft=0
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
      WHERE JPD.IsDraft = 0 AND Year(Cast(JPD.createddate AS DATE)) = @Year 
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
      WHERE   Year(Cast(U.createdon AS DATE)) = @Year 
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
/****** Object:  StoredProcedure [dbo].[usp_getAdvanceSearchData]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_getAdvanceSearchData]
(
@UserId INT
)
AS
BEGIN
	SELECT 
	DISTINCT TOP(10)
		Id,
		HiringRequirement,
		AllKeyword,
		Skills,
		IsSavedSearch
	FROM EmployerAdvanceSearch
	WHERE UserId = @UserId
	ORDER BY Id DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetAdvanceSearchHistory]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetAdvanceSearchHistory]
(
@UserId INT,
@Id INT
)
AS
BEGIN
	SELECT
	UserId,
	HiringRequirement,
	AnyKeyword,
	AllKeyword,
	ExculudeKeyword,
	MinExperience,
	MaxExperience,
	MinSalary,
	MaxSalary,
	CurrentLocation,
	PreferredLocation1,
	PreferredLocation2,
	PreferredLocation3,
	FuncationlArea,
	JobIndustryAreaId,
	CurrentDesignation,
	NoticePeriod,
	Skills,
	AgeFrom,
	AgeTo,
	Gender,
	CandidatesType,
	ShowCandidateSeeking,
	IsSavedSearch
	FROM EmployerAdvanceSearch
	WHERE 
		UserId = @UserId
		AND
		Id = @Id
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetAdvertisements]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
--------------------------------------------------------------------------------------------------------------------------
SR		By			Date				Remarks
1		SR			14/09/2020			Created to get ads data
2		SR			16/09/2020			added jobpage
--------------------------------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetAdvertisements]
(
	@section INT = 0
)
AS
BEGIN
	IF(@section = 0)
	BEGIN
		SELECT Id,
		ImageUrl,
		Section,
		[Order],
		JobPage
		FROM dbo.Advertisements
		WHere --Section=@section AND
		IsActive=1
	END
	ELSE
	BEGIN
		SELECT Id,
		ImageUrl,
		Section,
		[Order],
		JobPage
		FROM dbo.Advertisements
		WHere Section=@section
		AND IsActive=1
	END	
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetAllCitiesWithoutState]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetAllJobIndustryArea]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetAllNasscomJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		WHERE JP.IsDraft=0 AND U.Userid = @EmployerId 
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
/****** Object:  StoredProcedure [dbo].[usp_GetAllPlacedCandidate]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetAllScucessStoryVid]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetAllUsers]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetAllUsersRegistrations]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetAppliedJobMonthWise]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		JPD.IsDraft=0
		AND
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
		JPD.IsDraft=0
		AND
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
/****** Object:  StoredProcedure [dbo].[usp_GetAppliedJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetAppliedJobsInDateRange]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		AND JPD.IsDraft= 0
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020 
	ORDER BY 
		AJ.AppliedDate DESC
END




GO
/****** Object:  StoredProcedure [dbo].[usp_GetAverageResponseTime]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCandidateDetailByUserid]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_getCategory]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCategoryJobVacancies]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		Where JPD.JobPostId !='0' AND JPD.IsDraft=0
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
/****** Object:  StoredProcedure [dbo].[usp_GetCities]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCitiesListWithFirstChar]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCitiesWithJobPostUserId]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		ON CT.CityCode = JP.CityCode AND JP.IsDraft=0
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
/****** Object:  StoredProcedure [dbo].[usp_GetCitiesWithJobSeekerInfo]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCitiesWithoutState]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCityByCityCode]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCityJobVacancies]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			20/08/2020			Created -Getting city list that have jobs
2			SR			10/09/2020			Added jpd.isdraft=0
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
	ON C.CityCode = JPD.CityCode
	AND JPD.IsDraft=0
	INNER JOIN dbo.Users AS U
	ON JPD.UserId =U.UserId	
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
/****** Object:  StoredProcedure [dbo].[usp_GetCompanyJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		AND JPD.IsDraft = 0
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
/****** Object:  StoredProcedure [dbo].[usp_GetCompanyNamehaveJobPost]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	AND JP.IsDraft=0

	GROUP BY
	U.[CompanyName],
	U.UserId
	ORDER BY
	CountValue DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetCountries]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCourseCategories]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCourseNameBycourseId]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCourses]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCoursesNamebyCourseCategory]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetCourseTypeMaster]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDataOnEmployer]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDataOnJobRole]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDataOnQuarter]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDataOnState]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDashboardDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetDemandAggregationDataToExport]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetDesignationList]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerActiveJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetEmployerActiveJobs]
(  
 @EmpId INT = 0,
 @year INT,
 @JobStatus INT
)  
AS  
BEGIN
IF(@JobStatus=1)
BEGIN  
 SELECT  
  JPD.JobPostId,   
  JPD.JobTitleByEmployer, 
  JPD.HiringCriteria,
  JPD.CTC,  
  JPD.Featured,  
  JPD.CreatedDate AS PostedOn,
  JPD.PositionEndDate
 FROM dbo.JobPostDetail JPD  
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

 WHERE JPD.FinancialYear = @year AND JPD.IsDraft=0
 AND JPD.PositionEndDate > GETDATE()
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
AND U.IsActive =1 
 GROUP BY  
  JPD.JobPostId,
   JPD.JobTitleByEmployer,   
  JPD.HiringCriteria,
  JPD.CTC,  
  JPD.CreatedDate,    
 JPD.Featured,
 JPD.PositionEndDate
Order By JPD.CreatedDate DESC
END
ELSE
	BEGIN
	SELECT  
  JPD.JobPostId, 
  JPD.JobTitleByEmployer, 
  JPD.HiringCriteria,
  JPD.CTC,  
  JPD.Featured,  
  JPD.CreatedDate AS PostedOn,
  JPD.PositionEndDate  
 FROM dbo.JobPostDetail JPD  
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

 WHERE JPD.FinancialYear = @year AND JPD.IsDraft=0
 AND JPD.PositionEndDate < GETDATE()
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
  
 AND U.IsActive =1 
 GROUP BY  
  JPD.JobPostId,
   JPD.JobTitleByEmployer,   
  JPD.HiringCriteria,
  JPD.CTC,  
  JPD.CreatedDate,    
 JPD.Featured,
 JPD.PositionEndDate
Order By JPD.CreatedDate DESC
	END
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerDashboardSummary]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerDetailFromJobId]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JPD.IsDraft=0 AND JPD.JobPostId = @jobId
		AND U.IsActive = 1
		AND R.ID = 3
END







GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
			ON U.UserId = JPD.UserId AND JPD.IsDraft=0
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
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerFollowingByJobseeker]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	  WHERE EMF.[JobSeekerID] = @UserId
	  AND EMF.IsActive=1
  END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerJobDetail]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
		CreatedDate,
		Featured,
		FeaturedJobDisplayOrder,
		JobTitleByEmployer,
		FinancialYear
	FROM CTE_JobDetails CTE1
END



GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerJobDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetEmployerJobDetails] 
(  
 @EmpId INT = 0,  
 @JobId INT = 0,  
 @isDraftJob BIT = 0,
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
  --dbo.UTC2Indian(JPD.CreatedDate) AS PostedOn,    
  JPD.JobTitleByEmployer,
  JPD.IsFromBulkUpload,
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
 AND U.IsActive =1 AND IsDraft=@isDraftJob  --- To exclude deleted user 06/12/2020 
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
  JPD.JobTitleByEmployer,  
  JPD.Featured,  
  JPD.IsFromBulkUpload,
  FeaturedJobDisplayOrder  
Order By JPD.CreatedDate DESC
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployerRecentJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR By Date Remarks
1 SR 01/10/2020 Created - Getting top 5 Recent Jobs of Employer
2 SR 01/10/2020 Added isdraft=0
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetEmployerRecentJobs]
(
@EmpId INT
)
AS
BEGIN
	SELECT TOP(5)
		JPD.JobPostId,
		JPD.JobTitleByEmployer,
		JPD.HiringCriteria,
		JPD.CTC,
		JPD.Featured,
		JPD.CreatedDate AS PostedOn,
		JPD.PositionEndDate
		FROM dbo.JobPostDetail JPD
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

	WHERE
	(
		(
		ISNULL(@EmpId,0) = 0
		AND R.ID IN (3,4)

		)
		OR
		(
		ISNULL(@EmpId,0) <> 0
		AND R.ID IN (3,4)
		AND JPD.UserId = @EmpId
		)
	)

	AND U.IsActive =1
	GROUP BY
	JPD.JobPostId,
	JPD.JobTitleByEmployer,
	JPD.HiringCriteria,
	JPD.CTC,
	JPD.CreatedDate,
	JPD.Featured,
	JPD.PositionEndDate
	Order By JPD.CreatedDate DESC
END

GO
/****** Object:  StoredProcedure [dbo].[usp_GetEmployers]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetEmploymentStatus]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetEmploymentType]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetFeaturedJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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

	WHERE JP.IsDraft = 0 AND JP.Featured = 1 AND JP.FeaturedJobDisplayOrder<=20 AND ISNULL(R.ID,0) !=1
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
/****** Object:  StoredProcedure [dbo].[usp_GetFreelancerJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROC [dbo].[usp_GetFreelancerJobs] 
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
	WHERE  JP.[Status] = 1 AND JP.IsDraft=0
		AND ISNULL(JP.SPOCEmail,'') <> ''
		AND R.Id != 1
		AND U.IsActive =1  --- To exclude deleted user 06/12/2020
		AND ES.EmploymentStatusId=3
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


GO
/****** Object:  StoredProcedure [dbo].[usp_GetGenderMaster]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		ORDER BY GenderId DESC
	END
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetIdForValue]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetIndustryArea]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJoBDetail]    Script Date: 10/6/2020 12:07:43 PM ******/
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
   ,JOB.[Skills]
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
  WHERE JOB.IsDraft=0 AND JobPostId = @jobid   
 )  
  
 SELECT  
  DISTINCT   
   JobPostId,  
   JobIndustryAreaId,  
   CountryCode,  
   StateCode,  
   CityCode,  
   CTC,     
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
   Skills,
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobIndustryAreaWithPostData]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	AND JP.IsDraft = 0
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobIndustryAreaWithStudentData]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobListByCategory]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JP.IsDraft = 0 AND JA.JobIndustryAreaId = @Id 
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobListByCity]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JP.IsDraft = 0 AND C.CityCode = @CityCode 
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobListByCompany]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JP.IsDraft = 0 AND U2.UserId = @UserId 
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobListWithFirstChar]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobPostMonthlyStateWise]    Script Date: 10/6/2020 12:07:43 PM ******/
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

		WHERE JP.IsDraft = 0 AND MONTH(JP.CreatedDate) = @Month
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

		WHERE JP.IsDraft = 0 AND MONTH(JP.CreatedDate) = @Month
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobRoles]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		JT.JobTitleId,
		JT.JobTitleName,
		JIA.JobIndustryAreaId
	FROM [dbo].[JobTitle] AS JT
	INNER JOIN [dbo].[JobIndustryArea]  AS JIA
	ON
	JIA.JobIndustryAreaId = JT.JobIndustryAreaId
	WHERE
		 JT.[Status] = 1
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobRolesById]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_GetJobRolesById]
(
	@JobIndustryAreaId INT
)
AS
BEGIN
	SELECT
		JobTitleId,
		JobTitleName
	FROM [dbo].[JobTitle] 
	WHERE
	 JobIndustryAreaId = @JobIndustryAreaId
	
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerContactedDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerDashboardStats]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerInformation]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerInformationForResumeBuilder]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobseekerProfileData]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekersBasedOnEmployerHiringCriteria]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekersFilterByCity]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekersFilterByYear]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekersForPostedJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JPD.IsDraft = 0 AND JPD.UserId = @EmpId
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobSeekerSkills]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobseekersResume]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetJobseekersResume]
(
@UserIds VARCHAR(MAX)
)
AS
BEGIN
	SELECT 
		UR.UserId,
		UPD.[Resume] 
	From Users AS UR
	INNER JOIN 
		UserProfessionalDetails AS UPD
	ON
		UR.UserId = UPD.UserId
	WHERE
		UR.UserId IN(SELECT val FROM dbo.f_split(@UserIds, ',')) 
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetJobsInDateRange]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetJobTypes]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetLabelsCount]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
--------------------------------------------------------------------------------------------------------------------------
SR		By			Date				Remarks
1		SR			16/09/2020			Added to get count of labels(jobposted,resumeposted,etc)
--------------------------------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetLabelsCount]
AS
BEGIN
	DECLARE @JobOffers INT    
	DECLARE @ResumePost INT    
	DECLARE @JobSeeker INT    
	DECLARE @Companies INT
	DECLARE @ActiveUsers INT

	SELECT 
		@JobOffers = COUNT(1)
	FROM dbo.JobPostDetail 	
	WHERE IsDraft=0	

	SELECT 
		@ActiveUsers = COUNT(1)
	FROM dbo.LoggedInUsers	

	SELECT 
		@ResumePost = COUNT(1)
	FROM dbo.UserProfessionalDetails
	WHERE ISNULL([Resume],'') <> ''

	SELECT 
		@JobSeeker= COUNT(1)
	FROM dbo.Users AS U
	INNER JOIN UserRoles UR
	ON U.UserId = UR.UserID
	INNER JOIN Roles R
	ON UR.RoleId = R.Id
	WHERE U.IsActive = 1 AND R.ID=2

	SELECT 
		@Companies = COUNT(1)
	FROM dbo.Users AS U
	INNER JOIN UserRoles UR
	ON U.UserId = UR.UserID
	INNER JOIN Roles R
	ON UR.RoleId = R.Id
	WHERE U.IsActive = 1 AND R.ID IN (3,4)

	Select 
	@JobOffers AS JobOffers ,
	@ResumePost AS ResumePost,
	@JobSeeker AS JobSeeker,
	@Companies AS Companies, 
	@ActiveUsers AS ActiveUsers
END


GO
/****** Object:  StoredProcedure [dbo].[usp_GetMaritalStatusMaster]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetMessages]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetMessagesCount]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		INNER JOIN dbo.MailType MT
		ON EQ.MailType = MT.Id
	WHERE U.IsActive = 1
		AND EQ.ToId = @ToId
		AND CAST(EQ.CreatedOn AS DATE) = CAST(@SelectedDate AS DATE)
		AND MT.Id=6
END





GO
/****** Object:  StoredProcedure [dbo].[usp_GetMonthlyAppliedJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JPD.IsDraft=0 AND YEAR(CAST(AJ.AppliedDate AS DATE)) = @Year  
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
/****** Object:  StoredProcedure [dbo].[usp_GetMonthlyJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JPD.IsDraft=0 AND YEAR(JPD.CreatedDate) = @year
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
/****** Object:  StoredProcedure [dbo].[usp_GetMonthlyRegisteredUsers]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetMonthWiseCountJobPost]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	SELECT MONTH(CreatedDate) AS MONTH, [UserId] FROM JobPostDetail WHERE IsDraft=0
	) AS t
	PIVOT (
	COUNT([UserId])
	  FOR MONTH IN([1], [2], [3], [4], [5],[6],[7],[8],[9],[10],[11],[12])
	) p
END







GO
/****** Object:  StoredProcedure [dbo].[usp_GetNotificationsCounter]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetPopulerSearchCategory]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		AND JPD.IsDraft = 0 
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
/****** Object:  StoredProcedure [dbo].[usp_GetPopulerSearchCity]    Script Date: 10/6/2020 12:07:43 PM ******/
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
		AND JPD.IsDraft = 0
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
/****** Object:  StoredProcedure [dbo].[usp_GetProfileScore]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetRecentJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			10/08/2020			Created - Getting Recent Jobs   
2			SR			10/09/2020			Added isdraft=0
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

	WHERE JP.IsDraft=0 AND  ISNULL(R.ID,0) !=1
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
/****** Object:  StoredProcedure [dbo].[usp_GetResponseTime]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetResume]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetRoles]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetSearchJobOnSkills]    Script Date: 10/6/2020 12:07:43 PM ******/
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
AND Skills <> '' AND IsDraft=0


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

	WHERE JP.IsDraft=0 AND
		ISNULL(JP.SPOCEmail,'') <> ''
		AND R.Id IN (3,4)
		AND U.IsActive =1
		AND JP.MinExperience>=@Experience
		OR JP.MinExperience<=@Experience
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
/****** Object:  StoredProcedure [dbo].[usp_GetSearchList]    Script Date: 10/6/2020 12:07:43 PM ******/
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

	WHERE JP.IsDraft=0 AND 
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
/****** Object:  StoredProcedure [dbo].[usp_GetStaffingPartnerCount]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetStates]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetStudentCount]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetSuccessStory]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetSuccessStoryReview]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetSuccessStoryVideoPosted]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	SELECT TOP(2)
			 [title], 
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
/****** Object:  StoredProcedure [dbo].[usp_GetTopEmployer]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetTopEmployer]
AS
BEGIN
;WITH CTE_MonthlyJobs AS
	(
	SELECT  
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
	AND JR.RoleId=3 AND JP.IsDraft=0
	GROUP BY U.[CompanyName],JP.UserId,U.ProfilePic,EF.JobSeekerID,EF.IsActive
	)
	SELECT DISTINCT Top(4)
		[Count],
		CompanyName,
		Logo,
		UserId,
		JobSeekerID,
		FollowIsActive
	FROM CTE_MonthlyJobs CTE1
	ORDER BY
		[UserId] DESC,
		[COUNT]
END
GO
/****** Object:  StoredProcedure [dbo].[usp_GetTotalApplicationsForAllJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JPD.IsDraft=0 AND U.UserId = @EmpId
		AND U.IsActive = 1
END







GO
/****** Object:  StoredProcedure [dbo].[usp_GetTotalProfileViewed]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetTPDetail]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GETTPDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetTrainingPartnerCandidates]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetTrainingPartnerCount]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetuserITSkills]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetUserPersonalDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetuserPreferredlocations]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetUserProfessionalDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetUserRole]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_GetUserRole]
(
	@Email NVARCHAR(50)
)
AS
BEGIN
	SELECT 
		UR.RoleId
	FROM Users AS U
	INNER JOIN UserRoles AS UR
	ON UR.UserId = U.UserId
	INNER JOIN Roles AS R
	ON
	UR.RoleId = R.ID
	WHERE Email = @Email 
END









GO
/****** Object:  StoredProcedure [dbo].[usp_GetViewedProfiel]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetViewedProfileDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_GetWalkinJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	AND JP.IsDraft= 0 
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
/****** Object:  StoredProcedure [dbo].[usp_InserDownloadProfileHistory]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InserDownloadProfileHistory]
(
@UserId INT,
@JobSeekerIds VARCHAR(MAX),
@FileUrl VARCHAR(200)
)
AS
BEGIN
INSERT INTO 
DownloadProfileHistory
	(
		UserId,
		JobSeekerIds,
		FileUrl,
		CreatedBY,
		CreatedDate
	)
VALUES
(
	@UserId,
	@JobSeekerIds,
	@FileUrl,
	@UserId,
	GETDATE()
)
END


GO
/****** Object:  StoredProcedure [dbo].[usp_InsertAppliedJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertBulkJobPostSummaryDetail]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	@FinancialYear VARCHAR(5),
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
		FinancialYear,
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
		@FinancialYear,
		@CreatedBy
	)
END


GO
/****** Object:  StoredProcedure [dbo].[usp_InsertCity]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[USP_InsertEducationalDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertEmailQueueData]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertEmpDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
				FirstName = @contactPerson,
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
				FirstName = @contactPerson,
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
/****** Object:  StoredProcedure [dbo].[usp_InsertEmployerAdvanceSearch]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertEmployerAdvanceSearch]
(
	@UserId INT,
	@HiringRequirement VARCHAR(500) =NULL,
	@AnyKeyword VARCHAR(500) =NULL,
	@AllKeyword VARCHAR(500) =NULL,
	@ExculudeKeyword VARCHAR(500)=NULL,
	@MinExp INT=-1,
	@MaxExp INT=-1,
	@MinSalary VARCHAR(20)=NULL,
	@MaxSalary VARCHAR(20)=NULL,
	@CurrentLocation VARCHAR(10)=NULL,
	@PreferredLocation1 VARCHAR(10)=NULL,
	@PreferredLocation2 VARCHAR(10)=NULL,
	@PreferredLocation3 VARCHAR(10)=NULL,
	@FuncationlArea INT=0,
	@JobIndustryAreaId INT = 0, 
	@CurrentDesignation VARCHAR(100)=NULL,
	@NoticePeriod VARCHAR(5)=NULL,
	@Skills VARCHAR(1000) = NULL,  
	@AgeFrom INT =0,
	@AgeTO INT=0,
	@Gender VARCHAR(100)=NULL,
	@CandidatesType VARCHAR(50)=NULL,
	@ShowCandidateSeeking INT=0,
	@IsSavedSearch BIT
	
)
AS
BEGIN
	INSERT INTO EmployerAdvanceSearch
	(
	UserId,
	HiringRequirement,
	AnyKeyword,
	AllKeyword,
	ExculudeKeyword,
	MinExperience,
	MaxExperience,
	MinSalary,
	MaxSalary,
	CurrentLocation,
	PreferredLocation1,
	PreferredLocation2,
	PreferredLocation3,
	FuncationlArea,
	JobIndustryAreaId,
	CurrentDesignation,
	NoticePeriod,
	Skills,
	AgeFrom,
	AgeTo,
	Gender,
	CandidatesType,
	ShowCandidateSeeking,
	CreatedBy,
	CreatedDate,
	IsSavedSearch
	)
	VALUES
	(
	@UserId,
	@HiringRequirement,
	@AnyKeyword,
	@AllKeyword,
	@ExculudeKeyword,
	@MinExp,
	@MaxExp,
	@MinSalary,
	@MaxSalary,
	@CurrentLocation,
	@PreferredLocation1,
	@PreferredLocation2,
	@PreferredLocation3,
	@FuncationlArea,
	@JobIndustryAreaId,
	@CurrentDesignation,
	@NoticePeriod,
	@Skills,
	@AgeFrom,
	@AgeTo,
	@Gender,
	@CandidatesType,
	@ShowCandidateSeeking,
	@UserId,
	GETDATE(),
	@IsSavedSearch
	)
END


GO
/****** Object:  StoredProcedure [dbo].[usp_InsertEmployerFollower]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[USP_InsertExperienceDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertIntOptDate]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertJobPost]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
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
	@IsFromBulkUpload BIT,
	@isDraftJob BIT = 0
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
				AND JPD.IsDraft = 0				
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
		IsFromBulkUpload,
		IsDraft
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
		@IsFromBulkUpload,
		@isDraftJob
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
/****** Object:  StoredProcedure [dbo].[usp_InsertJobPost0403]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertPlacedCandidate]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertProfileSummary]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertProfileViewSummary]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertSearchJobHistory]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertSearchJobHistory]
(
	@userIP varchar(100),
	@loaction varchar(max),
	@jobSeekerId int,
	@searchCriteria varchar(max),
	@createdBy int
)
AS
BEGIN
	INSERT INTO dbo.SearchJobHistory
	(
		UserIP ,
		Location ,
		JobSeekerId ,
		SearchCriteria ,
		CreatedBy,
		CreatedDate
	)
	VALUES
	(
		@userIP ,
		@loaction ,
		@jobSeekerId ,
		@searchCriteria ,
		@createdBy ,
		GETDATE()
	)
END


GO
/****** Object:  StoredProcedure [dbo].[usp_InsertSearchResumeHistory]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_InsertSearchResumeHistory]
(
	@userIP varchar(100),
	@loaction varchar(max),
	@employerId int,
	@searchCriteria varchar(max),
	@createdBy int
)
AS
BEGIN
	INSERT INTO dbo.SearchResumeHistory
	(
		UserIP ,
		Location ,
		EmployerId ,
		SearchCriteria ,
		CreatedBy,
		CreatedDate
	)
	VALUES
	(
		@userIP ,
		@loaction ,
		@employerId ,
		@searchCriteria ,
		@createdBy ,
		GETDATE()
	)
END


GO
/****** Object:  StoredProcedure [dbo].[usp_InsertSkillsDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertState]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertStateDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
DECLARE @State Varchar(10) = @stateCode;
IF EXISTS (SELECT StateCode FROM States WHERE StateCode= @stateCode)
	BEGIN
	UPDATE STATES 
	SET 
	Name = @stateName,
	IsActive=1
	WHERE 
	StateCode = @stateCode
	END
ELSE
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
END



GO
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateJobTitle]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[usp_InsertUpdateJobTitle]
	@JobTitleId int,
	@JobTitleName NVARCHAR(MAX),
	@UpdatedBy NVARCHAR(50),
	@JobIndustryAreaId INT
AS 
BEGIN
	DECLARE @JobId INT
	SELECT @JobId =  JobTitleId from JobTitle where JobTitleId=@JobTitleId AND JobIndustryAreaId = @JobIndustryAreaId
 if(@JobId IS NOT NULL)
 BEGIN
		UPDATE JobTitle
		SET 
			JobTitleName=@JobTitleName,
			[UpdatedBy] = @UpdatedBy,
			[UpdatedDate] = GETDATE()
			WHERE 
			JobTitleId=@JobTitleId
			AND 
			JobIndustryAreaId = @JobIndustryAreaId
		END
	ELSE
	BEGIN
		INSERT INTO JobTitle
		(
			JobTitleName,
			[Status],
			[CreatedBy],
			[CreatedDate],
			JobIndustryAreaId
		)
		VALUES
		(
			@JobTitleName,
			1,
			@UpdatedBy,
			GETDATE(),
			@JobIndustryAreaId
		)
	END
END








GO
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateSuccessStoryVid]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateUserEducationDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateUserExperienceDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertUpdateUserPersonalDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_InsertUserProfessionalDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_JobSeekerAppliedJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	AND JP.IsDraft=0
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
/****** Object:  StoredProcedure [dbo].[usp_JobSeekerJobsAlert]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_LogActiveUsers]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_LogActiveUsers]
(
	@sessionid varchar(max),
	@userdata varchar(max)
)
AS
BEGIN
	INSERT INTO dbo.LoggedInUsers
	(
		SessionId,
		Userdata,
		CreatedAt
	)
	VALUES
	(
		@sessionid,
		@userdata,
		GETDATE()
	)
END


GO
/****** Object:  StoredProcedure [dbo].[usp_PostSuccessStory]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_RecommendedJobsOnRole]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	WHERE JP.Isdraft= 0 AND
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
/****** Object:  StoredProcedure [dbo].[usp_RegisterEmployer]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_RegisterEmployer]
(
	@CompanyName NVARCHAR(MAX),
	@Email NVARCHAR(50),
	@Password NVARCHAR(MAX) = NULL,
	@RoleId INT,
	@profilepic VARCHAR(100),
	@isRegisterOnlyForDemandAggregationData BIT,
	@IsApproved BIT,
	@IsActive BIT,
	@Mobile VARCHAR(10),
	@passwordHash VARBINARY(MAX),
	@passwordSalt VARBINARY(MAX)
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
						--Password = @Password,
						PasswordHash = @passwordHash,
						PasswordSalt = @passwordSalt,
						PasswordExpiryDate = (GETDATE()+30),
						ProfilePic = @profilepic,
						UpdatedOn = GETDATE(),
						IsRegisterOnlyForDemandAggregationData = @isRegisterOnlyForDemandAggregationData,
						MobileNo = @Mobile
				WHERE CompanyName = @CompanyName
			END
			ELSE
			BEGIN
				INSERT INTO dbo.Users
				(
					FirstName,
					Email,
					--Password,
					PasswordHash,
					PasswordSalt,
					CompanyName,
					PasswordExpiryDate,
					ProfilePic,
					CreatedOn,
					IsRegisterOnlyForDemandAggregationData,
					IsActive,
					IsApproved,
					MobileNo
				)
				VALUES
				(
					@CompanyName,
					@Email,
					--@Password,
					@passwordHash,
					@passwordSalt,
					@CompanyName,
					GETDATE()+30,
					@profilepic,
					GETDATE(),
					@isRegisterOnlyForDemandAggregationData,
					@IsActive,
					@IsApproved,
					@Mobile
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
/****** Object:  StoredProcedure [dbo].[usp_RegisterUser]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	@Password VARCHAR(MAX) = NULL,
	@RoleId INT,
	@IsActive BIT,
	@ActivationKey VARCHAR(100),
	@OutUserId INT = 0 OUT,
	@CreatedBy INT,
	@IsApproved BIT,
	@passwordHash VARBINARY(MAX),
	@passwordSalt VARBINARY(MAX)
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
				--[Password],
				PasswordExpiryDate,				
				IsActive,
				PasswordSalt,
				PasswordHash,
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
				--@Password,
				GETDATE()+30,				
				@IsActive,
				@passwordSalt,
				@passwordHash,
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


GO
/****** Object:  StoredProcedure [dbo].[usp_SearchBulkJobList]    Script Date: 10/6/2020 12:07:43 PM ******/
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
WHERE JPD.IsDraft = 0 AND
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
/****** Object:  StoredProcedure [dbo].[usp_SearchCandidateDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_SearchResume]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UnfollowEmployerForJobseeker]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateAdvertisements]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/*
--------------------------------------------------------------------------------------------------------------------------
SR		By			Date				Remarks
1		SR			14/09/2020			Created to update ads data
2		SR			16/09/2020			added jobpage
--------------------------------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_UpdateAdvertisements]
(
	@id INT,
	@userid INT,
	@section INT,
	@order INT,
	@jobpage VARCHAR(MAX),
	@imageurl VARCHAR(MAX)
)
AS
BEGIN
	IF(@imageurl <> '' OR @imageurl <> NULL)
	BEGIN
		UPDATE dbo.Advertisements
		SET ImageUrl = @imageurl,
			Section = @section,
			[Order]=@order,
			JobPage = @jobpage,
			UpdatedBy=@userid,
			UpdatedDate=GETDATE()			
		WHERE Id=@id
	END
	ELSE
	BEGIN
		UPDATE dbo.Advertisements
		SET Section = @section,
			[Order]=@order,
			JobPage = @jobpage,
			UpdatedBy=@userid,
			UpdatedDate=GETDATE()		
		WHERE Id=@id	
	END		
END


GO
/****** Object:  StoredProcedure [dbo].[usp_updateCandidateByUserid]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateCity]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateDesignation]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateFeaturedJobDisplayOrder]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	AND IsDraft = 0
END





GO
/****** Object:  StoredProcedure [dbo].[usp_UpdateITSkills]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateJobDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
	@openings INT,
	@Spoc VARCHAR(50),
	@SpocContact VARCHAR(15),
	@SpocEmail VARCHAR(50),
	@StateCode NVARCHAR(5),
	@Feauterdjobs BIT,
	@DisplayOrder INT,
	@JobTitleByEmployer NVARCHAR(255),
	@PostingDate VARCHAR(MAX),
	@ExpiryDate VARCHAR(MAX),
	@FinancialYear VARCHAR(5),
	@isDraftJob BIT = 0
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
				NoPosition = @openings,
				Featured = @Feauterdjobs,
				JobTitleByEmployer = @JobTitleByEmployer,
				PositionStartDate = @PostingDate,
				PositionEndDate = @ExpiryDate,
				FinancialYear=@FinancialYear,
				FeaturedJobDisplayOrder = @DisplayOrder,
				IsDraft = @isDraftJob
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateJobIndustryArea]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateJobSeekerMailStatus]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdatePassword]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_UpdatePassword]
(
	@Email NVARCHAR(50),
	--@Password NVARCHAR(MAX)
	@passwordHash VARBINARY(MAX),
	@passwordSalt VARBINARY(MAX)
)
AS
BEGIN
	Update Users
	SET PasswordHash = @passwordHash,
		PasswordSalt = @passwordSalt,
		UpdatedBy = 0,
		UpdatedOn =GETDATE()
    WHERE Email = @Email
END


GO
/****** Object:  StoredProcedure [dbo].[usp_UpdatePopularSearches]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateState]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateSuccessStory]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateTPDetails]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateUserData]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UpdateUsersAsAdminViewed]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UploadProfilePicture]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UploadResume]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UserActivity]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_UserLogin]    Script Date: 10/6/2020 12:07:43 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[usp_UserLogin]    
(    
 @Email NVARCHAR(50),    
 @Password NVARCHAR(MAX) = NULL 
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
  U.PasswordHash,
  U.PasswordSalt,
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
  --AND U.[Password] = @Password COLLATE Latin1_General_CS_AS    
  AND U.IsActive = 1    
END


GO
/****** Object:  StoredProcedure [dbo].[usp_VerifyEmailUsingActivationKey]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_VerifyOTP]    Script Date: 10/6/2020 12:07:43 PM ******/
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
/****** Object:  StoredProcedure [dbo].[usp_ViewAllFeaturedJobs]    Script Date: 10/6/2020 12:07:43 PM ******/
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
  AND JP.IsDraft= 0 
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
/****** Object:  StoredProcedure [dbo].[usp_WriteToDB]    Script Date: 10/6/2020 12:07:43 PM ******/
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
ALTER DATABASE [CareerIndeedLive] SET  READ_WRITE 
GO
