--select * from jobtitle

--alter table JobTitle drop column JobId

--alter table userprofessionaldetails add JobTitleId INT

--drop proc usp_GetCandidateDetail

--sp_depends results
--sp_helptext usp_UserLogin--usp_SearchCandidateDetails--usp_GetJobSeekersBasedOnEmployerHiringCriteria--usp_GetViewedProfileDetails --usp_GetJobseekerProfileData 

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
  U.[State],  
  U.Gender,   
  U.ProfilePic,  
  U.Candidateid,  
  JT.JobTitleName,
  UP.JobTitleId,  
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
  ES.EmploymentStatusName,
  ISNULL(UP.IsJobAlert,0) AS IsJobAlert
 FROM [dbo].[Users] AS U  
  LEFT JOIN [dbo].[UserProfessionalDetails] AS UP  
  ON U.UserId = UP.UserId  
  LEFT JOIN [dbo].[JobTitle] AS JT  
  ON UP.JobTitleId = JT.JobTitleId  
  LEFT JOIN [dbo].[MaritalStatus] AS M
  ON U.MaritalStatus = M.StatusCode  
  LEFT JOIN EmploymentStatus AS ES  
  ON UP.EmploymentStatusId = ES.EmploymentStatusId
 WHERE U.UserId = @userId
END  

Go 

ALTER PROC [dbo].[usp_GetViewedProfileDetails]    
(    
 @EmpId INT    
)    
AS    
BEGIN    
 SELECT    
  U.UserId,    
  U.Candidateid,    
  U.FirstName,    
  U.LastName,    
  U.MobileNo,    
  U.Email,    
  G.Gender,    
  UPD.Skills,    
  UPD.CurrentSalary,    
  UPD.ExpectedSalary,    
  UPD.Resume,    
  CT.Name,    
  JT.[JobTitleName]    
 FROM dbo.Users U  
  INNER JOIN dbo.ProfileViewSummary PVS    
  ON PVS.ViewedId = U.UserId  
  LEFT JOIN dbo.Gender G    
  ON U.Gender = G.GenderCode    
  LEFT JOIN dbo.UserProfessionalDetails UPD    
  ON U.UserId = UPD.UserId         
  LEFT JOIN [dbo].[JobTitle] AS JT    
  ON JT.JobTitleId = UPD.JobTitleId    
  LEFT JOIN [dbo].[Cities] AS CT    
  ON CT.CityCode = U.City    
 WHERE PVS.ViewerId= @EmpId    
  AND U.IsActive = 1    
END   


GO

ALTER PROC [dbo].[usp_GetJobSeekersBasedOnEmployerHiringCriteria]     
(    
 @Year VARCHAR(MAX) = NULL,    
 @JobRole VARCHAR(MAX)=NULL,    
 @City Varchar(MAX) = NULL,    
 @EmpId INT=NULL    
)    
AS    
BEGIN    
SELECT    
  U.UserId,    
  JT.JobTitleName,    
  CT.Name,    
  U.Candidateid,    
  U.FirstName,    
  U.LastName,    
  U.MobileNo,    
  U.Email,    
  G.Gender,    
  UPD.Skills,    
  UPD.CurrentSalary,    
  UPD.ExpectedSalary,    
  UPD.Resume,    
  UPD.ProfileSummary,    
  UPD.AboutMe    
  INTO #T  
 FROM dbo.Users U    
  INNER JOIN UserRoles UR    
  ON U.UserId = UR.UserId               
  LEFT JOIN dbo.UserProfessionalDetails UPD    
  ON U.UserId = UPD.UserId    
  LEFT JOIN dbo.Gender G    
  ON U.Gender = G.GenderCode    
  LEFT JOIN [dbo].[Cities] AS CT    
  ON CT.CityCode = U.City    
  LEFT JOIN [dbo].[JobTitle] AS JT    
  ON JT.JobTitleId = UPD.JobTitleId

  WHERE UR.RoleId = 2     
  AND     
  (    
   (    
    ISNULL(@City,'') <> ''    
    AND    
    U.city = @City    
   )    
    
   OR    
   (    
    ISNULL(@city,'') = ''    
   )       
  )    
  AND    
  (    
   (    
    ISNULL(@JobRole,'') <> ''    
    AND    
    JT.[JobTitleId] IN (SELECT val FROM dbo.f_split(@JobRole, ','))    
   )    
    
   OR    
   (    
    ISNULL(@JobRole,'') = ''    
   )       
  )    
    
  AND    
  (    
   (    
    ISNULL(@Year,'') <> ''    
    AND    
    Year(U.CreatedOn) = @Year    
   )    
    
   OR    
   (    
    ISNULL(@Year,'') = ''    
   )       
  )    
 ORDER BY    
  CASE     
   WHEN U.CreatedOn IS NOT NULL THEN U.CreatedOn    
   WHEN UPD.CreatedDate IS NOT NULL THEN UPD.CreatedDate    
   WHEN U.UpdatedOn IS NOT NULL THEN U.UpdatedOn    
   ELSE UPD.UpdatedDate END    
   DESC    
  
Select Distinct * from #T  
  
END 

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


GO

ALTER PROC [dbo].[usp_UserLogin]    
(    
 @Email NVARCHAR(50),    
 @Password NVARCHAR(MAX)    
)    
AS    
BEGIN    
 SELECT    
  U.UserId,    
  U.FirstName,    
  U.LastName,      
  U.MobileNo,    
  U.Email,    
  U.PasswordExpiryDate,    
  U.[Password],    
  R.RoleName,    
  U.CompanyName,    
  U.IsApproved,    
  U.ProfilePic,  
  U.Address1,
  U.Address2,
  U.Address3,
  ISNULL(JT.JobTitleId,0) AS JobTitleId,    
  JT.JobTitleName    
 FROM dbo.Users AS U    
  LEFT JOIN UserRoles AS UR    
   ON U.UserId = UR.UserId    
  INNER JOIN Roles AS R    
   ON UR.RoleId = R.ID      
   LEFT JOIN dbo.UserProfessionalDetails UD
   ON U.UserId = UD.UserId
  LEFT JOIN dbo.JobTitle JT    
   ON UD.JobTitleId = JT.JobTitleId    
 WHERE U.Email = @Email    
  AND U.[Password] = @Password COLLATE Latin1_General_CS_AS    
  AND U.IsActive = 1    
END


GO

ALTER PROCEDURE [dbo].[usp_InsertUserProfessionalDetails]
(
	@userId INT,	
	@currentSalary VARCHAR(50),
	@expectedSalary VARCHAR(50),
	@dateOfBirth VARCHAR(50),	
	@aboutMe VARCHAR(MAX),	
	@status VARCHAR(50),
	@email NVARCHAR(50),	
	@mobileNo NVARCHAR(15),
	@address VARCHAR(MAX),
	@maritalStatus VARCHAR(10),
	@gender VARCHAR(8),
	@jobCategory INT,
	@employmentStatus INT,
	@country VARCHAR(25),
	@state VARCHAR(50),
	@city VARCHAR(50),
	@jobTitleId INT = 0,
	@TotalExperience VARCHAR(5) = '0.0',
	@LinkedinProfile VARCHAR(MAX)
)
AS
BEGIN
	BEGIN TRY
       BEGIN TRANSACTION
		IF(ISNULL(@employmentStatus,'')='') -- Rev 2
		BEGIN
			SET @employmentStatus=5
		END

	   --insert or update UserProfessionalDetails table--
		  IF NOT EXISTS 
			(
				SELECT UserId
				FROM dbo.UserProfessionalDetails
				WHERE UserId = @userId 
			)
			BEGIN
				INSERT INTO dbo.UserProfessionalDetails
				(
					UserId,	
					CurrentSalary,
					ExpectedSalary,
					DateOfBirth,		
					AboutMe,		
					[Status],
					EmploymentStatusId,
					JobIndustryAreaId,
					CreatedDate,
					CreatedBy,
					TotalExperience,
					LinkedinProfile,
					JobTitleId
				)
				VALUES
				(
					@userId,
					@currentSalary,
					@expectedSalary,
					@dateOfBirth,
					@aboutMe,
					@status,
					@employmentStatus,		
					@jobCategory,
					GETDATE(),
					@userId,
					@TotalExperience,
					@LinkedinProfile,
					@jobTitleId
				)	
			END
			ELSE		
				BEGIN
					UPDATE dbo.UserProfessionalDetails
					SET			
						CurrentSalary = @currentSalary,
						ExpectedSalary = @expectedSalary,
						DateOfBirth = @dateOfBirth,			
						AboutMe =@aboutMe,		
						EmploymentStatusId = @employmentStatus,
						JobIndustryAreaId = @jobCategory,	
						[Status] = @status,
						UpdatedDate = GETDATE(),
						TotalExperience = @TotalExperience,
						UpdatedBy = @userId,
						LinkedinProfile=@LinkedinProfile,
						JobTitleId = @jobTitleId
					WHERE UserId = @userId
				 END	

			-- insert and update users table ---			
			UPDATE dbo.Users
			SET			
				Email = @email,
				Address1 = @address,
				City = @city,			
				[State] = @state,		
				Country = @country,
				MaritalStatus = @maritalStatus,
				Gender = @gender,
				MobileNo = @mobileNo,			
				UpdatedOn = GETDATE(),
				UpdatedBy = @userId
			WHERE UserId = @userId		
		COMMIT	
	END TRY
    BEGIN CATCH
      IF @@TRANCOUNT > 0
         ROLLBACK

      -- Raise an error with the details of the exception
      DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int
      SELECT @ErrMsg = ERROR_MESSAGE(),
             @ErrSeverity = ERROR_SEVERITY()

      RAISERROR(@ErrMsg, @ErrSeverity, 1)
    END CATCH
END 

GO
