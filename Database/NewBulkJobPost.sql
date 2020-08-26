

ALTER proc [dbo].[usp_InsertBulkJobPostSummaryDetail]
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



ALTER PROC [dbo].[usp_GetIdForValue]
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
