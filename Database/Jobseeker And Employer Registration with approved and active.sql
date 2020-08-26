-------1------------------
GO

ALTER PROC [dbo].[usp_RegisterUser]
(
	@Email VARCHAR(50),
	@FName VARCHAR(20),
	@LName VARCHAR(20),
	@MobileNo VARCHAR(15),
	@Password VARCHAR(MAX),
	@RoleId INT,
	@IsActive BIT,
	@ActivationKey VARCHAR(100),
	@OutUserId INT = 0 OUT,
	@CreatedBy INT,
	@IsApproved BIT
)
AS
BEGIN
	BEGIN TRY
		BEGIN TRAN
			INSERT INTO dbo.Users
			(
			
				FirstName,
				LastName,
				MobileNo,
				Email,
				[Password],
				PasswordExpiryDate,				
				IsActive,
				ActivationKey,
				CreatedBy,
				CreatedOn,
				IsApproved
			)
			VALUES
			(
				@FName,
				@LName,
				@MobileNo,
				@Email,
				@Password,
				GETDATE()+30,				
				@IsActive,
				@ActivationKey,
				@CreatedBy,
				GETDATE(),
				@IsApproved
			)

			SET @OutUserId=@@IDENTITY

			INSERT INTO dbo.UserRoles
			(
				RoleId,
				UserId,
				Createddate,
				CreatedBy
			)
			VALUES
			(

				@RoleId,
				@OutUserId,
			
	GETDATE(),
				@OutUserId
			)			
			
		COMMIT TRAN
	END TRY
	BEGIN CATCH
		ROLLBACK TRAN
	END CATCH

END

--------2----------------
GO


ALTER PROC [dbo].[usp_RegisterEmployer]
(
	@CompanyName NVARCHAR(MAX),
	@Email NVARCHAR(50),
	@Password NVARCHAR(MAX),
	@RoleId INT,
	@profilepic VARCHAR(100),
	@isRegisterOnlyForDemandAggregationData BIT,
	@IsApproved BIT,
	@IsActive BIT
)
AS
	BEGIN
		BEGIN TRY
			IF EXISTS
			(
				SELECT
					1
				FROM dbo.Users
				WHERE CompanyName = @CompanyName
			)
			BEGIN
				UPDATE dbo.Users
					SET FirstName = @CompanyName,
						Email = @Email,
						Password = @Password,
						PasswordExpiryDate = (GETDATE()+30),
						ProfilePic = @profilepic,
						UpdatedOn = GETDATE(),
						IsRegisterOnlyForDemandAggregationData = @isRegisterOnlyForDemandAggregationData
				WHERE CompanyName = @CompanyName
			END
			ELSE
			BEGIN
				INSERT INTO dbo.Users
				(
					FirstName,
					Email,
					Password,
					CompanyName,
					PasswordExpiryDate,
					ProfilePic,
					CreatedOn,
					IsRegisterOnlyForDemandAggregationData,
					IsActive,
					IsApproved
				)
				VALUES
				(
					@CompanyName,
					@Email,
					@Password,
					@CompanyName,
					GETDATE()+30,
					@profilepic,
					GETDATE(),
					@isRegisterOnlyForDemandAggregationData,
					@IsActive,
					@IsApproved
				)
				DECLARE @UserId INT
				SET @UserId=@@IDENTITY

				INSERT INTO dbo.UserRoles
				(
					RoleId,
					UserId,
					Createddate,
					CreatedBy
				)
				VALUES
				(
					@RoleId,
					@UserId,
					GETDATE(),
					@UserId
				)
			END
			
	END TRY
	BEGIN CATCH
        SELECT  
             ERROR_NUMBER() AS ErrorNumber  
            ,ERROR_SEVERITY() AS ErrorSeverity  
            ,ERROR_STATE() AS ErrorState  
            ,ERROR_PROCEDURE() AS ErrorProcedure  
            ,ERROR_LINE() AS ErrorLine  
            ,ERROR_MESSAGE() AS ErrorMessage;  
    END CATCH
END

