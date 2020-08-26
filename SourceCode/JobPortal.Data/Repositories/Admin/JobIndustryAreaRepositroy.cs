using JobPortal.Data.DataModel.Admin.JobIndustryArea;
using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System;
using System.Data;
using System.Data.SqlClient;

namespace JobPortal.Data.Repositories.Admin
{
    public class JobIndustryAreaRepositroy : IJobIndustryAreaRepository
    {
        private readonly string connectionString;
        public JobIndustryAreaRepositroy(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }

        public DataTable GetJobIndustryArea()
        {
            using(var connection = new SqlConnection(connectionString))
            {
                try
                {
                    var Data =
                        SqlHelper.ExecuteReader
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetAllJobIndustryArea"
                            );
                    if (null != Data && Data.HasRows)
                    {
                        var dt = new DataTable();
                        dt.Load(Data);
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

        public bool UpdateJobIndustryArea(JobIndustryAreaModel jobIndustry)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                    new SqlParameter("@JobIndustryAreaId",jobIndustry.JobIndustryAreaId),
                    new SqlParameter("@JobIndustryAreaName",jobIndustry.JobIndustryAreaName),
                    };
                    var data =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_UpdateJobIndustryArea",
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
            throw new Exception("Unable to update data");
        }

        public bool DeleteJobIndustryArea(string jobIndustryAreaId, string deletedBy)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameters = new SqlParameter[] {
                    new SqlParameter("@JobIndustryAreaId",jobIndustryAreaId),
                    new SqlParameter("@UpdatedBy",deletedBy),
                    };
                    var data =
                       SqlHelper.ExecuteNonQuery
                       (
                           connection,
                           CommandType.StoredProcedure,
                           "usp_DeleteJobIndustryArea",
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

            throw new Exception("Unable to delete data");
        }
    }
}
