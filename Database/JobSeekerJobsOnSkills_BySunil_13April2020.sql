-------------1---------------
GO

/*
-----------------------------------------------------------------------------------------------------------
-- Rev	| Date Modified	|	Developer    | Change Summary

-- 1	| 08-12-2020	| Rajesh P	 | Created
-----------------------------------------------------------------------------------------------------------
*/

CREATE FUNCTION [dbo].[udf_Split](@String VARCHAR(8000), @Delimiter CHAR(1))     
RETURNS @temptable TABLE (items VARCHAR(8000))     
AS     
BEGIN     
	DECLARE @idx INT     
	DECLARE @slice VARCHAR(8000)     
    
	SELECT @idx = 1     
		IF len(@String)<1 or @String is null  RETURN     
    
	WHILE @idx!= 0     
	BEGIN     
		SET @idx = charindex(@Delimiter,@String)     
		IF @idx!=0     
			SET @slice = left(@String,@idx - 1)     
		ELSE     
			SET @slice = @String     
		
		if(LEN(@slice)>0)
			INSERT INTO @temptable(Items) VALUES(@slice)     

		SET @String = right(@String,len(@String) - @idx)     
		IF len(@String) = 0 BREAK     
	END 
RETURN     
END




----------2-------------------

GO

/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			13/08/2020			Created - Getting jobs on job seeker skills
   
-------------------------------------------------------------------------------------------------
*/

CREATE PROCEDURE [dbo].[usp_GetSearchJobOnSkills]
(
	@Skills VARCHAR(1000) = NULL
)
AS
BEGIN

SELECT items
INTO #TempInputSkills
 FROM udf_Split(@Skills,',')
 
 SELECT
  JobPostId,items
  INTO #TempTotalSkills
FROM dbo.JobPostDetail 
CROSS APPLY  udf_Split(Skills,',')
WHERE Skills IS NOT NULL
AND Skills <> '' 

SELECT JobPostId INTO #TempFinalSkills FROM #TempTotalSkills AS TTS
INNER JOIN #TempInputSkills AS INS
ON
TTS.items=INS.items



;WITH CTE_Jobs AS
(
	SELECT 
		JP.JobPostId,
		JP.JobTitleByEmployer,
		JT.JobTitleName AS JobTitle,
		ES.EmploymentStatusName AS EmploymentStatus,
		ISNULL(JP.Skills,'') AS Skills,
		C.Name AS City,
		JP.HiringCriteria AS HiringCriteria,
		U.[ProfilePic] AS CompanyLogo,
		U.CompanyName,
		CAST(JP.PositionStartDate AS DATETIME) AS PostingDate,
		CAST(JP.PositionEndDate AS DATETIME) AS ExpiryDate,
		CAST(JP.CreatedDate AS DATETIME) AS CreatedDate,
		JP.CTC
	FROM dbo.JobPostDetail AS JP
		LEFT JOIN dbo.JobRoleMapping JRM
		ON JP.JobPostId = JRM.JobId
		LEFT JOIN dbo.JobTitle AS JT
		ON JRM.JobRoleId = JT.JobTitleId
		LEFT JOIN dbo.EmploymentStatus AS ES 
		ON JP.EmploymentStatusId = ES.EmploymentStatusId
		LEFT JOIN dbo.Cities AS C
		ON JP.CityCode = C.CityCode
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
		INNER JOIN #TempFinalSkills AS FA
		ON
		JP.JobPostId= FA.JobPostId

	WHERE 
		ISNULL(JP.SPOCEmail,'') <> ''
		AND R.Id IN (3,4)
		AND U.IsActive =1
)

SELECT
	DISTINCT
	JobPostId,
	JobTitleByEmployer,
	STUFF(
		(
			SELECT 
				', ' + JobTitle
			FROM CTE_Jobs cte2
			WHERE cte2.JobPostId = cte1.JobPostId
			FOR XML PATH('')),1,2,''
		) AS JobTitle,
	EmploymentStatus,
	Skills,
	City,
	HiringCriteria,
	CompanyLogo,
	CompanyName,
	PostingDate,
	ExpiryDate,
	CreatedDate,
	CTC
FROM CTE_Jobs cte1
ORDER BY 
	CreatedDate DESC

	DROP TABLE #TempInputSkills
	DROP TABLE #TempTotalSkills
	DROP TABLE #TempFinalSkills

END