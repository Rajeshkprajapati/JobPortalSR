/*
-------------------------------------------------------------------------------------------------
SR			By			Date				Remarks
1			SK			11/02/2019			Created - for getting success story video
-------------------------------------------------------------------------------------------------
*/

ALTER PROC [dbo].[usp_GetSuccessStoryVideoPosted] 
AS 
  BEGIN 
	SELECT TOP(2)
			 [title], 
			[filename], 
			[type], 
			[createdby],
			[CreatedDate],
			[DisplayOrder]
	FROM   [dbo].[successstoryvideo] 
	WHERE  [status] = 1 
	ORDER BY [DisplayOrder]
  END 

