--------1------------------

GO

ALTER PROC [dbo].[usp_GetTopEmployer]
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

ALTER PROC [dbo].[usp_GetJobListByCategory] 
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

ALTER PROC [dbo].[usp_GetJobListByCity] 
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

----------7---------------
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


