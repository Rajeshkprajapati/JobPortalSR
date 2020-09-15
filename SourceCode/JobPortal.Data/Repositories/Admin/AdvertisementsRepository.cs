using JobPortal.Data.DataModel.Admin.Advertisement;
using JobPortal.Data.Helper;
using JobPortal.Data.Interfaces.Admin;
using JobPortal.Utility.Exceptions;
using Microsoft.Extensions.Configuration;
using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;

namespace JobPortal.Data.Repositories.Admin
{
    public class AdvertisementsRepository : IAdvertisementsRepository
    {
        private readonly string connectionString;

        public AdvertisementsRepository(IConfiguration configuration)
        {
            connectionString = configuration["ConnectionStrings:NassComJobPortalDB"];
        }

        public bool AddAds(AdvertisementDataModel model)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                SqlParameter[] parameter = new SqlParameter[]
                {
                    new SqlParameter("@id",model.Id),
                    new SqlParameter("@section",model.Section),
                    new SqlParameter("@order",model.Order),
                    new SqlParameter("@imageurl",model.ImagePath),
                };
                try
                {
                    var result =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_AddAdvertisements",
                            parameter
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
            return false;
        }

        public bool DeleteAds(int adId)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                SqlParameter[] parameter = new SqlParameter[]
                {
                    new SqlParameter("@id",adId),
                };
                try
                {
                    var result =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_DeleteAdvertisements",
                            parameter
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
            return false;
        }

        public DataTable GetAllData(int section = 0)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                try
                {
                    SqlParameter[] parameter = new SqlParameter[]
                    {
                        new SqlParameter("@section",section),
                    };
                    var result =
                        SqlHelper.ExecuteDataset
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_GetAdvertisements",
                            parameter
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

            throw new DataNotFound("Advertisement Data not found");
        }

        public bool UpdateAds(AdvertisementDataModel model, int userid)
        {
            using (var connection = new SqlConnection(connectionString))
            {
                SqlParameter[] parameter = new SqlParameter[]
                {
                    new SqlParameter("@id",model.Id),
                    new SqlParameter("@userid",userid),
                    new SqlParameter("@section",model.Section),
                    new SqlParameter("@order",model.Order),
                    new SqlParameter("@imageurl",model.ImagePath),
                };
                try
                {
                    var result =
                        SqlHelper.ExecuteNonQuery
                        (
                            connection,
                            CommandType.StoredProcedure,
                            "usp_UpdateAdvertisements",
                            parameter
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
            return false;
        }
    }
}
