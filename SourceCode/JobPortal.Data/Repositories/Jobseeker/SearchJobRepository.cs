using System.Data;
using System.Data.SqlClient;
using JobPortal.Data.DataModel.Shared;
using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Jobseeker;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;

namespace JobPortal.Data.Repositories.Jobseeker
{
    public class SearchJobRepository : ISearchJobRepository
    {
        private readonly string connectionString;

        public SearchJobRepository(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }

        public DataTable GetSearchJobList(JobSearchModel searches, int UserId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {

                    SqlParameter[] parameters = new SqlParameter[] {
                new SqlParameter("@jobTitle",searches.JobRole),
                new SqlParameter("@jobCategory",searches.JobCategory),
                new SqlParameter("@Experience",searches.Experiance),
                new SqlParameter("@city",searches.City),
                new SqlParameter("@User",UserId),
                new SqlParameter("@Skills",searches.Skills),                
                new SqlParameter("@CompanyUserId",searches.CompanyUserId)
            };
                    var searchList =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetSearchList",
                            parameters
                            );
                    if (null != searchList && searchList.Tables.Count > 0)
                    {
                        return searchList.Tables[0];
                    }
                }
                finally
                {
                    SqlHelper.CloseConnection(connection);
                }
            }
            throw new DataNotFound("Data Not found");
        }
    }
}
