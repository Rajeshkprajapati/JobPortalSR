-----------1---------------
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

ALTER TABLE JobPostDetail ADD IsWalkIn BIT 


-------------4---------------

Go


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

ALTER PROCEDURE [dbo].[usp_GetJobseekerProfileData] 
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
  U.State,  
  U.Gender,  
 
  U.ProfilePic,  
  U.Candidateid,  
  JT.JobTitleName AS SSCJobRole,  
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
  ES.EmploymentStatusName
 FROM [dbo].[Users] AS U  
  LEFT JOIN [dbo].[UserProfessionalDetails] AS UP  
  ON U.UserId = UP.UserId  
  LEFT JOIN dbo.Results AS RS -- Rev 3  
  ON U.Candidateid=RS.CandidateId  
  LEFT JOIN [dbo].[JobTitle] AS JT  
  ON RS.qualificationPackId = JT.JobId  
  LEFT JOIN [dbo].[MaritalStatus] AS M -- Rev 2  
  ON U.MaritalStatus = M.StatusCode  
  LEFT JOIN EmploymentStatus AS ES  --Emplyoment status 10/08/2020--
  ON UP.EmploymentStatusId = ES.EmploymentStatusId
 WHERE U.UserId = @userId  
END  


