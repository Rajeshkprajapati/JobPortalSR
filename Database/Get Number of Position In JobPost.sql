--sp_helptext usp_GetEmployerJobDetail

ALTER PROC [dbo].[usp_GetEmployerJobDetail]
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
				SELECT ', ' + Job
Role
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


