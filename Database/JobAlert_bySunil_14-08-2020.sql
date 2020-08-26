----------1--------
GO
ALTER TABLE UserProfessionalDetails
ADD IsJobAlert BIT DEFAULT 0;

GO
-----2----------------------

GO
CREATE PROC [dbo].[usp_JobSeekerJobsAlert]
(
@UserId INT,
@JobAlert INT
)
AS
BEGIN
Update UserProfessionalDetails
 SET 
	IsJobAlert = @JobAlert
  WHERE UserId=@UserId 
END


---------------3--------------------




