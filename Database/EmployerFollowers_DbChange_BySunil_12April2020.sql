----1------------
GO

CREATE TABLE EmployerFollower
(
ID INT NOT NULL IDENTITY PRIMARY KEY,
JobSeekerID INT NOT NULL,
EmployerID INT NOT NULL,
CreatedDate DATETIME,
IsActive BIT
)

----------2------------

GO
ALTER PROC [dbo].[usp_InsertEmployerFollower] 
(
@EmployerId INT,
@JobSeekerId INT 
)
AS
BEGIN
	  IF EXISTS (SELECT ID FROM EmployerFollower WHERE JobSeekerID = @JobSeekerId AND EmployerID=@EmployerId)
		BEGIN
        Update EmployerFollower SET IsActive = 1 WHERE JobSeekerID = @JobSeekerId AND EmployerID=@EmployerId
		END
	ELSE
		BEGIN
			INSERT INTO EmployerFollower
			(
				JobSeekerID,
				EmployerID,
				CreatedDate,
				IsActive
			)
			VALUES
			(
				@JobSeekerId,
				@EmployerId,
				GETDATE(),
				1
			)
		END
END


----------3-------------------
GO



ALTER PROC [dbo].[usp_GetTopEmployer]
AS
BEGIN
	SELECT TOP(8) 
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
	AND
	ISNULL(U.ProfilePic,'') <> ''
	AND JR.RoleId=3
	GROUP BY U.[CompanyName],JP.UserId,U.ProfilePic,EF.JobSeekerID,EF.IsActive
	ORDER BY COUNT(1) DESC
END



------------4---------------------
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


	SELECT COUNT(JobSeekerID) AS TotalCompaniesFollowed 
	FROM EmployerFollower
	WHERE JobSeekerID = @UserId
	AND IsActive=1
END

-----------------5--------------------------

GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			12/08/2020			CREATED - Getting data of employer following by job seeker
-------------------------------------------------------------------------------------------------
*/

CREATE PROC [dbo].[usp_GetEmployerFollowingByJobseeker]
  (
	@UserId Int
  )
  AS
  BEGIN
	  SELECT 
	  EMF.CreatedDate,
	  U.CompanyName,
	  EMF.EmployerID
	 FROM [dbo].[EmployerFollower] AS EMF
	  INNER JOIN
	  Users AS U
	  ON EMF.[EmployerID] = U.UserId
	  WHERE EMF.[JobSeekerID] = 1586
	  AND EMF.IsActive=1
  END

  ----------------6---------------------

 GO

 CREATE PROC [dbo].[usp_UnfollowEmployerForJobseeker]
(
@UserId INT,
@EmployerId INT
)
AS
BEGIN
UPDATE [dbo].[EmployerFollower]
	SET [IsActive] = 0
	WHERE [EmployerID] = @EmployerId
	AND [JobSeekerID]= @UserId
END


--------------------7--------------------
GO

CREATE PROC [dbo].[usp_GetJobSeekerSkills]
(
@UserId INT
)
AS
BEGIN
SELECT [Skills] FROM UserProfessionalDetails WHERE UserId = @UserId
END