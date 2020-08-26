using JobPortal.Data.DataModel.Shared;
using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Employer.SearchResume;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
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


    }
}