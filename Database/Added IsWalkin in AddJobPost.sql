--sp_helptext usp_InsertJobPost


ALTER PROCEDURE [dbo].[usp_InsertJobPost]
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

