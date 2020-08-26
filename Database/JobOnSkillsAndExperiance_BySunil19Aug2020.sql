-------1----------------
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


------------2-----------------
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			11/08/2020			CREATED -  For getting job seeker applied jobs 
-------------------------------------------------------------------------------------------------
*/

ALTER PROC [dbo].[usp_JobSeekerAppliedJobs] 
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

----------3------------------
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

---------------4--------------------
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