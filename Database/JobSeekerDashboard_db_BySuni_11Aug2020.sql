
---------1--------------
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
END

--------------2-----------------

Go

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
		NumberOfDays
	FROM CTE_GetAppliedJobs CTE1
	Order BY
	NumberOfDays ASC
END

----------3---------------

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

  --------4------------

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