
ALTER TABLE ITSkills ADD [Status] BIT DEFAULT 1

GO

--------1----------------

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SR			06/08/2020			Created - To Get IT Skills
-------------------------------------------------------------------------------------------------
*/
CREATE PROC [dbo].[usp_GetuserITSkills]
(
	@UserId INT
)
AS
BEGIN
	SELECT 
		[Id],
		[Skill],
		[SkillVersion],
		[LastUsed],
		[ExperienceYear],
		[ExperienceMonth]
	From ITSkills WHERE CreatedBy=@UserId
	AND [Status] = 1
END

GO
-----2---------------
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			06/08/2020			Update - Inserting and updating IT Skills
-------------------------------------------------------------------------------------------------
*/
CREATE PROC[dbo].[usp_UpdateITSkills]
(
@ITSkillId INT,
@ITSkill VARCHAR(50),
@SkillVersion VARCHAR(50),
@LastUsed VARCHAR(10),
@ExperienceYear VARCHAR(10),
@ExperienceMonth VARCHAR(10),
@UserId INT
)
AS
BEGIN
	if(@ITSkillId=0)
		BEGIN
			INSERT INTO [dbo].[ITSkills]
			(
			[Skill],
			[SkillVersion],
			[LastUsed],
			[ExperienceYear],
			[ExperienceMonth],
			[CreatedBy],
			[CreatedDate],
			[Status]
			)
			VALUES
			(
			@ITSkill,
			@SkillVersion,
			@LastUsed,
			@ExperienceYear,
			@ExperienceMonth,
			@UserId,
			GETDATE(),
			1
			)
		END
	ELSE
		BEGIN
			UPDATE [dbo].[ITSkills]
			SET
			[Skill] = @ITSkill,
			[SkillVersion]=@SkillVersion,
			[LastUsed]=@LastUsed,
			[ExperienceYear]=@ExperienceYear,
			[ExperienceMonth]=@ExperienceMonth,
			[UpdateDate] = GETDATE(),
			[UpdatedBy] = @UserId
			WHERE Id = @ITSkillId
		END
END

--------3------------
GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			06/08/2020			Update - set status = 0
-------------------------------------------------------------------------------------------------
*/
CREATE PROC[dbo].[usp_DeleteITSkill]
(
@ITSkillId INT,
@UserId INT
)
AS
BEGIN
	UPDATE [dbo].[ITSkills]
		SET 
		[Status] = 0,
		[UpdatedBy] = @UserId,
		[UpdateDate] = GETDATE()
		WHERE Id = @ITSkillId
END

