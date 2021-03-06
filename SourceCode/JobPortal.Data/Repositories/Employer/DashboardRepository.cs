﻿using JobPortal.Data.DataModel.Employer.JobPost;
using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Employer;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System;
using System.Data;
using System.Data.SqlClient;

namespace JobPortal.Data.Repositories.Employer
{
    public class DashboardRepository : IDashboardRepository
    {
        private readonly string connectionString;

        public DashboardRepository(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }

        public DataTable GetProfileData(int empId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@EmpId",empId)
                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetEmployerDetails",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Employer details not found, please contact your tech deck.");
        }

        public DataTable GetJobs(int empId, int year, int jobId,bool isDraftJob)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@EmpId",empId),
                        new SqlParameter("@JobId",jobId),
                        new SqlParameter("@year",year),
                        new SqlParameter("@isDraftJob",isDraftJob)
                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetEmployerJobDetails",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Jobs not found, please contact your tech deck.");
        }

        public DataTable GetJob(int jobId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                new SqlParameter("@JobId",jobId)
            };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetEmployerJobDetail",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Job not found, please contact your tech deck.");
        }

        public DataSet GetDashboard(int empId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                new SqlParameter("@EmpId",empId)
            };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetEmployerDashboardSummary",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Dashboard data not found, please contact your tech deck.");
        }

        public DataTable GetJobSeekers(int empId, int jobId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                new SqlParameter("@EmpId",empId),
                new SqlParameter("@JobId",jobId)
            };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetJobSeekersForPostedJobs",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Job seekers not found, please contact your tech deck.");
        }

        public DataTable GetMessages(DateTime msgsOnDate, int empId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@SelectedDate",msgsOnDate),
                        new SqlParameter("@ToId",empId)
                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetMessages",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Messages not found, please contact your tech deck.");
        }

        public DataTable GetViewedProfiles(int empId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@EmpId",empId)
                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetViewedProfileDetails",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Job seekers information found, please contact your tech deck.");
        }

        public DataTable GetJobSeekersBasedOnEmployerHiringCriteria(int empId, string year, string city, string role)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                    new SqlParameter("@EmpId",empId),
                    new SqlParameter("@JobRole",role),
                    new SqlParameter("@City",city),
                    new SqlParameter("@Year",year),
                };
                    var result =
                        SqlHelper.ExecuteReader
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetJobSeekersBasedOnEmployerHiringCriteria",
                            parameters
                            );
                    if (null != result && result.HasRows)
                    {
                        var dt = new DataTable();
                        dt.Load(result);
                        return dt;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Job seekers for dashboard found, please contact your tech deck.");
        }

        public bool UpdateJob(int userId, int jobId, JobPostModel job)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                    new SqlParameter("@JobId",jobId),
                    new SqlParameter("@CityCode",job.CityCode),
                    new SqlParameter("@CountryCode",job.CountryCode),
                    new SqlParameter("@CTC",job.CTC),
                    new SqlParameter("@UpdatedBy",userId),
                    new SqlParameter("@HiringCriteria",job.HiringCriteria),
                    new SqlParameter("@Jobdetails",job.JobDetails),
                    new SqlParameter("@JobTitleId",job.JobTitleId),
                    new SqlParameter("@JobType",job.JobType),
                    new SqlParameter("@MonthlySalary",job.MonthlySalary), 
                    new SqlParameter("@openings",job.NoPosition),
                    new SqlParameter("@Spoc",job.SPOC),
                    new SqlParameter("@SpocContact",job.SPOCContact),
                    new SqlParameter("@SpocEmail",job.SPOCEmail),
                    new SqlParameter("@StateCode",job.StateCode),
                    new SqlParameter("@Feauterdjobs",job.Featured==null?0:1),
                    new SqlParameter("@DisplayOrder",job.DisplayOrder),
                    new SqlParameter("@JobTitleByEmployer",job.JobTitleByEmployer),
                    new SqlParameter("@PostingDate",job.PositionStartDate),
                    new SqlParameter("@ExpiryDate",job.PositionEndDate),
                    new SqlParameter("@FinancialYear",job.FinancialYear)                    
                };
                    var result =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_UpdateJobDetails",
                            parameters
                            );
                    if (result > 0)
                    {
                        return true;
                    }
                }                
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotUpdatedException("Unable to update posted job, please contact your teck deck with your details.");
        }

        public bool UpdateJobSeekerMailStatus(int messageId, int userId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@MessageId",messageId),
                        new SqlParameter("@UserId",userId),
                    };
                    var result =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_UpdateJobSeekerMailStatus",
                            parameters
                            );
                    if (result > 0)
                    {
                        return true;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotUpdatedException("Unable to update job seeker's mail response status, please contact your teck deck with your details.");
        }

        public DataTable GetActiveCloseJobs(int empId, int year, int JobStatus)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@EmpId",empId),
                        new SqlParameter("@year",year),
                        new SqlParameter("@JobStatus",JobStatus)
                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetEmployerActiveJobs",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Job seekers information found, please contact your tech deck.");
        }

        public bool DactiveActiveJobs(string id, int JobPostId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@UserId",id),
                        new SqlParameter("@JobPostId",JobPostId),
                    };
                    var data =
                       SqlHelper.ExecuteNonQuery
                       (
                           connection,
                           CommandType.StoredProcedure,
                           "usp_CloseEmployerJob",
                           parameters
                           );
                    if (data > 0)
                    {
                        return true;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new Exception("Unable to close job");
        }

        public DataTable BulkResumeData(string UserIds)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                    new SqlParameter("@UserIds",UserIds),
                };
                    var result =
                        SqlHelper.ExecuteReader
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetJobseekersResume",
                            parameters
                            );
                    if (null != result && result.HasRows)
                    {
                        var dt = new DataTable();
                        dt.Load(result);
                        return dt;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Job seekers resume not found.");
        }

        public bool SaveProfileHistory(int UserId, string JobSeekerIds, string FileUrl)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@UserId",UserId),
                        new SqlParameter("@JobSeekerIds",JobSeekerIds),
                        new SqlParameter("@FileUrl",FileUrl),
                    };
                    var data =
                       SqlHelper.ExecuteNonQuery
                       (
                           connection,
                           CommandType.StoredProcedure,
                           "usp_InserDownloadProfileHistory",
                           parameters
                           );
                    if (data > 0)
                    {
                        return true;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new Exception("Unable to close job");
        }

        public DataTable EmployerRecentJobPost(int empId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@EmpId",empId)
                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetEmployerRecentJobs",
                            parameters
                            );
                    if (null != result && result.Tables.Count > 0)
                    {
                        return result.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Job seekers information found, please contact your tech deck.");
        }
    }
}

