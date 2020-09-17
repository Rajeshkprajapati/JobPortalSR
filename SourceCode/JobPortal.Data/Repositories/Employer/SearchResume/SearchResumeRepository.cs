using JobPortal.Data.DataModel.Shared;
using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Employer.SearchResume;
using JobPortal.Model.DataViewModel.Employer.AdvanceSearch;
using JobPortal.Model.DataViewModel.Shared;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System;
using System.Data;
using System.Data.SqlClient;

namespace JobPortal.Data.Repositories.Employer.SearchResume
{
    public class SearchResumeRepository : ISearchResumeRepository
    {
        private readonly string connectionString;

        public SearchResumeRepository(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }
        public DataTable GetSearchResumeList(SearchResumeModel searches)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@Skills",searches.Skills),
                        new SqlParameter("@JobIndustryAreaId",searches.JobCategory),
                        new SqlParameter("@CityCode",searches.City),
                        new SqlParameter("@MinExp",searches.MinExp),
                        new SqlParameter("@MaxExp",searches.MaxExp)
                    };
                    var searchList =
                        SqlHelper.ExecuteReader
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_SearchResume",
                            parameters
                            );
                    if (null != searchList && searchList.HasRows)
                    {
                        var dt = new DataTable();
                        dt.Load(searchList);
                        return dt;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Data not found");
        }

        public void LogSearchResumeList(string searche,string userip,string location,int empid)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {                         
                         new SqlParameter("@userIP",userip),
                         new SqlParameter("@loaction",location),
                         new SqlParameter("@employerId",empid),
                         new SqlParameter("@searchCriteria",searche),
                         new SqlParameter("@createdBy",empid),                         
                    };
                    var resp =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_InsertSearchResumeHistory",
                            parameters
                            );                    
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }            
        }

        public DataTable ShowCandidateDetails(int employerId, int jobSeekerId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@employerId",employerId),
                         new SqlParameter("@jobSeekerId",jobSeekerId)
                    };
                    var searchList =
                        SqlHelper.ExecuteReader
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_SearchCandidateDetails",
                            parameters
                            );
                    if (null != searchList && searchList.HasRows)
                    {
                        var dt = new DataTable();
                        dt.Load(searchList);
                        return dt;
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Data not found");
        }

        public DataTable GetAdvanceSearchResumeList(AdvanceResumeSearch searches, int userId)
        {
            var dt = new DataTable();

            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                        new SqlParameter("@HiringRequirement",searches.HiringRequirement),
                        new SqlParameter("@AnyKeyword",searches.AnyKeyword),
                        new SqlParameter("@AllKeyword",searches.AllKeyword),
                        new SqlParameter("@ExculudeKeyword",searches.ExculudeKeyword),
                        new SqlParameter("@MinExp",searches.MinExperiance),
                        new SqlParameter("@MaxExp",searches.MaxExperiance),
                        new SqlParameter("@MinSalary",searches.MinSalary),
                        new SqlParameter("@MaxSalary",searches.MaxSalary),
                        new SqlParameter("@CurrentLocation",searches.CurrentLocation),
                        new SqlParameter("@PreferredLocation1",searches.PreferredLocation1),
                        new SqlParameter("@PreferredLocation2",searches.PreferredLocation2),
                        new SqlParameter("@PreferredLocation3",searches.PreferredLocation3),
                        new SqlParameter("@FuncationlArea",searches.FuncationlArea),
                        new SqlParameter("@JobIndustryAreaId",searches.JobIndustryAreaId),
                        new SqlParameter("@CurrentDesignation",searches.CurrentDesignation),
                        new SqlParameter("@NoticePeriod",searches.NoticePeriod),
                        new SqlParameter("@Skills",searches.skills),
                        new SqlParameter("@AgeFrom",searches.AgeFrom),
                        new SqlParameter("@AgeTO",searches.AgeTo),
                        new SqlParameter("@Gender",searches.Gender),
                        new SqlParameter("@CandidatesType",searches.CandidatesType),
                        //new SqlParameter("@ShowCandidateWith",searches.ShowCandidateWith),
                        new SqlParameter("@ShowCandidateSeeking",searches.ShowCandidateSeeking),
                        new SqlParameter("@UserId",userId),
                        new SqlParameter("@IsSavedSearch",searches.isSavedSearch)

                    };
                    var searchList =
                        SqlHelper.ExecuteReader
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_AdvanceSearchResume",
                            parameters
                            );
                    if (null != searchList && searchList.HasRows)
                    {
                       dt.Load(searchList);
                    }
                }
                catch (Exception ex)
                {
                    var data = ex;
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            return dt;
            throw new DataNotFound("Data not found");
        }
        public DataTable AdvanceSearchStates(int userId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                       new SqlParameter("@UserId",userId)

                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_getAdvanceSearchData",
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
            throw new DataNotFound("data not found");
        }

        public DataTable AdvanceSearchById(int Id,int userId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                       new SqlParameter("@UserId",userId),
                       new SqlParameter("@Id",Id),

                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetAdvanceSearchHistory",
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
            throw new DataNotFound("data not found");
        }
    }
}