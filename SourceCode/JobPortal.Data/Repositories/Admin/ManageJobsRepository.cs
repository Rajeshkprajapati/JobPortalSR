using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System.Data;
using System.Data.SqlClient;

namespace JobPortal.Data.Repositories.Admin
{
    public class ManageJobsRepository: IManageJobsRepository
    {
        private readonly string connectionString;
        public ManageJobsRepository(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }

        public bool UpdateFeaturedJobDisplayOrder(int jobpostid, int displayorder)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                    new SqlParameter("@jobpostid",jobpostid),
                    new SqlParameter("@displayorder",displayorder)
                    };
                    var result =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_UpdateFeaturedJobDisplayOrder",
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
            throw new DataNotFound("Unable to Find job.");
        }

        public bool DeleteFeaturedJob(int jobpostid)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                    new SqlParameter("@jobpostid",jobpostid)
                    };
                    var result =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_DeleteFeaturedJob",
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
            throw new DataNotFound("Unable to Find job.");
        }
    }
}
