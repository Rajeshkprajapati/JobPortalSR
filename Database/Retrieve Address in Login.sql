

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
  U.Password,    
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
  LEFT JOIN dbo.RESULTS RES    
   ON U.Candidateid =  RES.CandidateId    
  LEFT JOIN dbo.JobTitle JT    
   ON RES.qualificationPackId = JT.JobId    
 WHERE U.Email = @Email    
  AND U.Password = @Password COLLATE Latin1_General_CS_AS    
  AND U.IsActive = 1    
END
