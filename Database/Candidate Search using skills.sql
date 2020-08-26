

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
		UD.[Resume],  
		JI.JobIndustryAreaName,  
		CT.Name AS CityName
		--IT.Skill AS ITSkill		
	FROM dbo.Users AS U  
		INNER JOIN dbo.UserProfessionalDetails AS UD  
		ON U.UserId = UD.UserId
		INNER JOIN UserRoles AS UR  
		ON UR.UserId = U.UserId
		AND UR.RoleId = 2
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
		 -- OR
		 -- (
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


