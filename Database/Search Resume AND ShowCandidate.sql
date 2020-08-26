--1.---------------------------------------------

ALTER PROC [dbo].[usp_SearchResume]
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
		CT.Name AS CityName
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



---2.-------------------------

GO

ALTER PROC [dbo].[usp_SearchCandidateDetails]    
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