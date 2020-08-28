
ALTER PROCEDURE [dbo].[usp_GetSearchList]
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